#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Republish courses from .runtime/tasks to MinIO (delete online course prefix first).

Usage:
  republish_runtime_courses.sh \
    --endpoint http://127.0.0.1:9000 \
    --bucket engbook-courses \
    [--catalog-out /path/to/catalog.json] \
    [--threshold-mib 512] \
    [--part-size-mib 256]

Required env vars:
  COURSE_PIPELINE_MINIO_ACCESS_KEY
  COURSE_PIPELINE_MINIO_SECRET_KEY
EOF
}

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNTIME_TASKS="${PROJECT_ROOT}/.runtime/tasks"

ENDPOINT=""
BUCKET=""
CATALOG_OUT="${PROJECT_ROOT}/catalog.json"
THRESHOLD_MIB="512"
PART_SIZE_MIB="256"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --endpoint)
      ENDPOINT="${2:-}"
      shift 2
      ;;
    --bucket)
      BUCKET="${2:-}"
      shift 2
      ;;
    --catalog-out)
      CATALOG_OUT="${2:-}"
      shift 2
      ;;
    --threshold-mib)
      THRESHOLD_MIB="${2:-}"
      shift 2
      ;;
    --part-size-mib)
      PART_SIZE_MIB="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if [[ -z "${ENDPOINT}" || -z "${BUCKET}" ]]; then
  echo "--endpoint and --bucket are required." >&2
  usage
  exit 2
fi

if [[ -z "${COURSE_PIPELINE_MINIO_ACCESS_KEY:-}" || -z "${COURSE_PIPELINE_MINIO_SECRET_KEY:-}" ]]; then
  echo "Missing env: COURSE_PIPELINE_MINIO_ACCESS_KEY / COURSE_PIPELINE_MINIO_SECRET_KEY" >&2
  exit 2
fi

if ! command -v mc >/dev/null 2>&1; then
  echo "mc not found. Install MinIO client first." >&2
  exit 2
fi

if [[ ! -d "${RUNTIME_TASKS}" ]]; then
  echo "Runtime tasks directory not found: ${RUNTIME_TASKS}" >&2
  exit 2
fi

if command -v course-pipeline >/dev/null 2>&1; then
  PIPELINE_CMD=(course-pipeline)
else
  PIPELINE_CMD=(python3 "${PROJECT_ROOT}/tools/course_pipeline/course_pipeline_ops.py")
fi

TASK_LIST_FILE="$(mktemp)"
trap 'rm -f "${TASK_LIST_FILE}"' EXIT

python3 - "${RUNTIME_TASKS}" > "${TASK_LIST_FILE}" <<'PY'
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

runtime_tasks = Path(sys.argv[1])


def parse_ts(value: str) -> datetime:
    text = (value or "").strip()
    if not text:
        return datetime.fromtimestamp(0, tz=timezone.utc)
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"
    try:
        dt = datetime.fromisoformat(text)
    except Exception:
        return datetime.fromtimestamp(0, tz=timezone.utc)
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def choose_zip(task_dir: Path) -> Path | None:
    output_publish = task_dir / "output_publish.json"
    if output_publish.exists():
        try:
            payload = json.loads(output_publish.read_text(encoding="utf-8"))
            file_path = Path(str(((payload or {}).get("payload") or {}).get("file") or "")).expanduser()
            if file_path.exists() and file_path.is_file():
                return file_path
        except Exception:
            pass

    candidates = []
    for p in task_dir.glob("*.zip"):
        name = p.name.lower()
        if "restored" in name:
            continue
        candidates.append(p)
    if not candidates:
        return None
    candidates.sort(key=lambda p: p.stat().st_size, reverse=True)
    return candidates[0]


def read_title_version(task_dir: Path, course_id: str) -> tuple[str, str]:
    default_title = course_id
    default_version = "1.0.0"
    catalog = task_dir / "package" / "catalog.json"
    if not catalog.exists():
        return default_title, default_version
    try:
        data = json.loads(catalog.read_text(encoding="utf-8"))
    except Exception:
        return default_title, default_version
    courses = data.get("courses")
    if not isinstance(courses, list) or not courses:
        return default_title, default_version
    pick = None
    for row in courses:
        if isinstance(row, dict) and str(row.get("id", "")).strip() == course_id:
            pick = row
            break
    if pick is None:
        pick = courses[0] if isinstance(courses[0], dict) else None
    if not isinstance(pick, dict):
        return default_title, default_version
    title = str(pick.get("title") or default_title).strip() or default_title
    version = str(pick.get("version") or default_version).strip() or default_version
    return title, version


latest_by_course: dict[str, dict] = {}
for task_json in sorted(runtime_tasks.glob("task_*.json")):
    try:
        task = json.loads(task_json.read_text(encoding="utf-8"))
    except Exception:
        continue
    if not isinstance(task, dict):
        continue

    steps = task.get("steps")
    if not isinstance(steps, dict) or str(steps.get("package", "")).strip() != "done":
        continue

    task_id = str(task.get("task_id", "")).strip()
    course_id = str(task.get("course_id", "")).strip()
    if not task_id or not course_id:
        continue

    task_dir = runtime_tasks / task_id
    if not task_dir.exists():
        continue
    zip_file = choose_zip(task_dir)
    if zip_file is None:
        continue

    title, version = read_title_version(task_dir, course_id)
    updated_at = parse_ts(str(task.get("updated_at", "")).strip())
    existing = latest_by_course.get(course_id)
    if existing is None or updated_at >= existing["updated_at"]:
        latest_by_course[course_id] = {
            "task_id": task_id,
            "course_id": course_id,
            "zip_path": str(zip_file),
            "title": title.replace("\t", " "),
            "version": version,
            "updated_at": updated_at,
        }

for row in sorted(latest_by_course.values(), key=lambda x: x["course_id"]):
    print(f'{row["task_id"]}\t{row["course_id"]}\t{row["zip_path"]}\t{row["title"]}\t{row["version"]}')
PY

if [[ ! -s "${TASK_LIST_FILE}" ]]; then
  echo "No publishable tasks found (.runtime/tasks/task_*.json with steps.package=done)." >&2
  exit 1
fi

mc alias set cprepub "${ENDPOINT}" "${COURSE_PIPELINE_MINIO_ACCESS_KEY}" "${COURSE_PIPELINE_MINIO_SECRET_KEY}" >/dev/null
rm -f "${CATALOG_OUT}"
mkdir -p "$(dirname "${CATALOG_OUT}")"

echo "Publishing tasks listed in ${TASK_LIST_FILE}"
first=1
while IFS=$'\t' read -r TASK_ID COURSE_ID ZIP_PATH TITLE VERSION; do
  [[ -n "${TASK_ID}" ]] || continue
  [[ -f "${ZIP_PATH}" ]] || {
    echo "Skip ${TASK_ID}: zip not found ${ZIP_PATH}" >&2
    continue
  }

  echo "[$TASK_ID] delete remote prefix ${COURSE_ID}/"
  mc rm --recursive --force "cprepub/${BUCKET}/${COURSE_ID}/" >/dev/null 2>&1 || true

  OBJECT_PREFIX="${COURSE_ID}/${VERSION}/$(basename "${ZIP_PATH}")"
  echo "[$TASK_ID] publish ${ZIP_PATH} -> ${OBJECT_PREFIX}"
  if [[ "${first}" -eq 1 ]]; then
    "${PIPELINE_CMD[@]}" package publish-minio-auto "${ZIP_PATH}" \
      --endpoint "${ENDPOINT}" \
      --bucket "${BUCKET}" \
      --course-id "${COURSE_ID}" \
      --title "${TITLE}" \
      --version-name "${VERSION}" \
      --threshold-mib "${THRESHOLD_MIB}" \
      --part-size-mib "${PART_SIZE_MIB}" \
      --object-prefix "${OBJECT_PREFIX}" \
      --catalog-out "${CATALOG_OUT}" \
      --catalog-replace \
      --task-id "${TASK_ID}"
    first=0
  else
    "${PIPELINE_CMD[@]}" package publish-minio-auto "${ZIP_PATH}" \
      --endpoint "${ENDPOINT}" \
      --bucket "${BUCKET}" \
      --course-id "${COURSE_ID}" \
      --title "${TITLE}" \
      --version-name "${VERSION}" \
      --threshold-mib "${THRESHOLD_MIB}" \
      --part-size-mib "${PART_SIZE_MIB}" \
      --object-prefix "${OBJECT_PREFIX}" \
      --catalog-out "${CATALOG_OUT}" \
      --task-id "${TASK_ID}"
  fi
done < "${TASK_LIST_FILE}"

echo "Done. merged catalog: ${CATALOG_OUT}"
