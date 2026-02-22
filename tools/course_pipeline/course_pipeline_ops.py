#!/usr/bin/env python3
import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import time
import uuid
import zipfile
from datetime import datetime, timezone
from pathlib import Path
from shutil import which
from urllib.parse import quote, urlencode, urlparse
from urllib.request import Request, urlopen

STATUSES = {"uploaded", "processing", "paused", "ready", "failed", "stopped"}
STEP_ORDER = ["ffmpeg", "asr", "align", "translate", "grammar", "summary", "package"]
STEP_STATES = {"pending", "running", "done", "failed"}
HITL_STEPS = {"translate", "grammar", "summary"}
TERMINAL_STATUSES = {"ready", "failed", "stopped"}
MEDIA_PATTERN = re.compile(r"^(\d{2})_.*\.(mp4|mp3)$", re.IGNORECASE)
WORD_PATTERN = re.compile(r"[A-Za-z]+(?:'[A-Za-z]+)?")
IPA_CACHE: dict[str, str | None] = {}


def now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def out(payload: dict, code: int = 0) -> int:
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return code


def read_secret_arg_or_env(value: str | None, env_key: str) -> str | None:
    if value and value.strip():
        return value.strip()
    env_value = os.getenv(env_key, "").strip()
    return env_value or None


def sha256_and_size(path: Path) -> tuple[str, int]:
    hasher = hashlib.sha256()
    total = 0
    with path.open("rb") as f:
        while True:
            chunk = f.read(1024 * 1024)
            if not chunk:
                break
            hasher.update(chunk)
            total += len(chunk)
    return hasher.hexdigest(), total


def normalize_endpoint_host(endpoint: str) -> str:
    endpoint = endpoint.strip()
    parsed = urlparse(endpoint if "://" in endpoint else f"http://{endpoint}")
    if not parsed.hostname:
        raise ValueError("invalid endpoint")
    if parsed.port:
        return f"{parsed.hostname}:{parsed.port}"
    return parsed.hostname


def run_mc_copy(
    endpoint: str,
    access_key: str,
    secret_key: str,
    bucket: str,
    object_key: str,
    source_file: Path,
    make_bucket: bool,
) -> tuple[str, bool]:
    mc_bin = which("mc")
    if mc_bin is None:
        raise RuntimeError("MINIO_MC_NOT_FOUND")

    host = normalize_endpoint_host(endpoint)
    alias = "coursepipeline"
    host_url = (
        f"http://{quote(access_key, safe='')}:{quote(secret_key, safe='')}@{host}"
    )
    env = dict(os.environ)
    env[f"MC_HOST_{alias}"] = host_url

    if make_bucket:
        subprocess.run(
            [mc_bin, "mb", "--ignore-existing", f"{alias}/{bucket}"],
            check=True,
            capture_output=True,
            text=True,
            env=env,
        )
    subprocess.run(
        [mc_bin, "cp", str(source_file), f"{alias}/{bucket}/{object_key}"],
        check=True,
        capture_output=True,
        text=True,
        env=env,
    )
    object_url = f"{endpoint.rstrip('/')}/{bucket}/{object_key.lstrip('/')}"
    return object_url, make_bucket


def run_mc_download(
    endpoint: str,
    access_key: str,
    secret_key: str,
    bucket: str,
    object_key: str,
    target_file: Path,
) -> Path:
    mc_bin = which("mc")
    if mc_bin is None:
        raise RuntimeError("MINIO_MC_NOT_FOUND")

    host = normalize_endpoint_host(endpoint)
    alias = "coursepipeline"
    host_url = (
        f"http://{quote(access_key, safe='')}:{quote(secret_key, safe='')}@{host}"
    )
    env = dict(os.environ)
    env[f"MC_HOST_{alias}"] = host_url

    target_file.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [mc_bin, "cp", f"{alias}/{bucket}/{object_key}", str(target_file)],
        check=True,
        capture_output=True,
        text=True,
        env=env,
    )
    return target_file


def run_mc_rm_prefix(
    endpoint: str,
    access_key: str,
    secret_key: str,
    bucket: str,
    object_prefix: str,
) -> None:
    mc_bin = which("mc")
    if mc_bin is None:
        raise RuntimeError("MINIO_MC_NOT_FOUND")

    host = normalize_endpoint_host(endpoint)
    alias = "coursepipeline"
    host_url = (
        f"http://{quote(access_key, safe='')}:{quote(secret_key, safe='')}@{host}"
    )
    env = dict(os.environ)
    env[f"MC_HOST_{alias}"] = host_url
    key = object_prefix.strip().strip("/")
    if not key:
        return
    subprocess.run(
        [mc_bin, "rm", "--recursive", "--force", f"{alias}/{bucket}/{key}/"],
        check=True,
        capture_output=True,
        text=True,
        env=env,
    )


def normalize_object_prefix(prefix: str, fallback: str) -> str:
    value = (prefix or "").strip().strip("/")
    if not value:
        value = fallback
    return re.sub(r"/{2,}", "/", value)


def build_default_publish_object_prefix(course_id: str, version_name: str, file_name: str) -> str:
    return normalize_object_prefix("", f"{course_id}/{(version_name or '1.0.0').strip()}/{file_name}")


def merge_catalog_courses(existing: dict | None, incoming_item: dict, version: int) -> dict:
    incoming_id = str(incoming_item.get("id", "")).strip()
    merged_courses: list[dict] = []
    replaced = False

    if isinstance(existing, dict):
        rows = existing.get("courses")
        if isinstance(rows, list):
            for row in rows:
                if not isinstance(row, dict):
                    continue
                row_id = str(row.get("id", "")).strip()
                if not row_id:
                    continue
                if row_id == incoming_id:
                    if not replaced:
                        merged_courses.append(incoming_item)
                        replaced = True
                    continue
                merged_courses.append(row)

    if not replaced:
        merged_courses.append(incoming_item)

    return {"version": int(version), "courses": merged_courses}


def segmented_part_object_key(prefix: str, index: int, total_parts: int) -> str:
    width = max(4, len(str(total_parts)))
    return f"{prefix}.part-{index:0{width}d}"


def infer_task_id_from_path(path: Path) -> str:
    parts = list(path.parts)
    for p in parts:
        if p.startswith("task_"):
            return p
    return ""


def normalize_segment_manifest_parts(parts: list[dict]) -> list[dict]:
    ordered = sorted(parts, key=lambda p: int(p.get("index", 0)))
    for pos, part in enumerate(ordered, start=1):
        index = int(part.get("index", 0))
        if index != pos:
            raise ValueError("INVALID_MANIFEST_PART_INDEX")
        if not str(part.get("object_key", "")).strip():
            raise ValueError("INVALID_MANIFEST_PART_OBJECT_KEY")
    return ordered


def _parse_iso_or_epoch(value: str) -> datetime:
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


def build_zip_from_package_dir(task_dir: Path, course_id: str) -> Path | None:
    package_dir = task_dir / "package"
    manifest_file = package_dir / "course_manifest.json"
    if not package_dir.exists() or not package_dir.is_dir() or not manifest_file.exists():
        return None

    out_file = task_dir / f"{course_id}.zip"
    with zipfile.ZipFile(out_file, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for p in sorted(package_dir.rglob("*")):
            if not p.is_file():
                continue
            arcname = p.relative_to(package_dir).as_posix()
            zf.write(p, arcname)
    return out_file


def choose_task_zip_file(task_dir: Path, course_id: str, pack_if_missing: bool) -> Path | None:
    output_publish = task_dir / "output_publish.json"
    if output_publish.exists():
        try:
            payload = json.loads(output_publish.read_text(encoding="utf-8"))
            path_value = str(((payload or {}).get("payload") or {}).get("file") or "").strip()
            if path_value:
                p = Path(path_value).expanduser().resolve()
                if p.exists() and p.is_file():
                    return p
        except Exception:
            pass

    candidates = []
    for p in task_dir.glob("*.zip"):
        lower = p.name.lower()
        if "restored" in lower:
            continue
        candidates.append(p)
    if not candidates:
        if pack_if_missing:
            return build_zip_from_package_dir(task_dir, course_id)
        return None
    candidates.sort(key=lambda item: item.stat().st_size, reverse=True)
    return candidates[0]


def choose_title_version_from_task(task_dir: Path, course_id: str) -> tuple[str, str]:
    default_title = course_id
    default_version = "1.0.0"
    catalog_file = task_dir / "package" / "catalog.json"
    if not catalog_file.exists():
        return default_title, default_version
    try:
        payload = json.loads(catalog_file.read_text(encoding="utf-8"))
    except Exception:
        return default_title, default_version
    if not isinstance(payload, dict):
        return default_title, default_version
    rows = payload.get("courses")
    if not isinstance(rows, list) or not rows:
        return default_title, default_version
    selected = None
    for row in rows:
        if isinstance(row, dict) and str(row.get("id", "")).strip() == course_id:
            selected = row
            break
    if selected is None and isinstance(rows[0], dict):
        selected = rows[0]
    if not isinstance(selected, dict):
        return default_title, default_version
    title = str(selected.get("title") or default_title).strip() or default_title
    version = str(selected.get("version") or default_version).strip() or default_version
    return title, version


def resolve_course_manifest_title(task: dict, package_dir: Path) -> str:
    course_id = str(task.get("course_id") or "").strip() or "local_course"
    def _usable(value: str) -> bool:
        text = value.strip()
        return bool(text) and text != course_id

    task_title = str(task.get("course_title") or "").strip()
    if _usable(task_title):
        return task_title

    manifest_file = package_dir / "course_manifest.json"
    if manifest_file.exists():
        try:
            manifest = json.loads(manifest_file.read_text(encoding="utf-8"))
            if isinstance(manifest, dict):
                value = str(manifest.get("title") or "").strip()
                if _usable(value):
                    return value
        except Exception:
            pass

    catalog_file = package_dir / "catalog.json"
    if catalog_file.exists():
        try:
            payload = json.loads(catalog_file.read_text(encoding="utf-8"))
            if isinstance(payload, dict):
                rows = payload.get("courses")
                if isinstance(rows, list):
                    selected = None
                    for row in rows:
                        if isinstance(row, dict) and str(row.get("id") or "").strip() == course_id:
                            selected = row
                            break
                    if selected is None:
                        for row in rows:
                            if isinstance(row, dict):
                                selected = row
                                break
                    if isinstance(selected, dict):
                        value = str(selected.get("title") or "").strip()
                        if _usable(value):
                            return value
        except Exception:
            pass

    course_path = str(task.get("course_path") or "").strip()
    if course_path:
        path_name = Path(course_path).name.strip()
        if path_name:
            return path_name.replace("_", " ")

    return course_id


def project_runtime_dir(project_root: Path) -> Path:
    d = project_root / ".runtime" / "tasks"
    d.mkdir(parents=True, exist_ok=True)
    return d


def task_file(runtime_dir: Path, task_id: str) -> Path:
    return runtime_dir / f"{task_id}.json"


def events_file(runtime_dir: Path) -> Path:
    return runtime_dir / "events.log"


def append_event(runtime_dir: Path, task_id: str, event: str, payload: dict) -> None:
    record = {
        "ts": now_iso(),
        "task_id": task_id,
        "event": event,
        "payload": payload,
    }
    with events_file(runtime_dir).open("a", encoding="utf-8") as f:
        f.write(json.dumps(record, ensure_ascii=False) + "\n")


def load_task(runtime_dir: Path, task_id: str) -> dict:
    p = task_file(runtime_dir, task_id)
    if not p.exists():
        raise FileNotFoundError("TASK_NOT_FOUND")
    return json.loads(p.read_text(encoding="utf-8"))


def save_task(runtime_dir: Path, task: dict) -> None:
    task["updated_at"] = now_iso()
    task_file(runtime_dir, task["task_id"]).write_text(
        json.dumps(task, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


def normalize_course_id(raw_folder: Path) -> str:
    stem = raw_folder.name.lower().strip().replace(" ", "_")
    stem = "".join(c for c in stem if c.isalnum() or c in {"_", "-"})
    return f"course_{stem or 'untitled'}"


def find_media_for_key(raw_folder: Path, key: str) -> Path | None:
    for p in sorted(raw_folder.iterdir()):
        if not p.is_file():
            continue
        m = MEDIA_PATTERN.match(p.name)
        if not m:
            continue
        if m.group(1) == key:
            return p
    return None


def ffprobe_duration_ms(media_file: Path) -> int:
    cmd = [
        "ffprobe",
        "-v",
        "error",
        "-show_entries",
        "format=duration",
        "-of",
        "default=noprint_wrappers=1:nokey=1",
        str(media_file),
    ]
    result = subprocess.run(cmd, check=True, capture_output=True, text=True)
    seconds = float(result.stdout.strip() or "0")
    return int(seconds * 1000)


def extract_embedded_subtitle_to_srt(media_file: Path, out_srt: Path) -> tuple[bool, str]:
    """Try extracting embedded subtitle stream from media into SRT.

    Returns (ok, source_tag).
    """
    probe_cmd = [
        "ffprobe",
        "-v",
        "error",
        "-select_streams",
        "s",
        "-show_entries",
        "stream=index:stream_tags=language",
        "-of",
        "json",
        str(media_file),
    ]
    probe = subprocess.run(probe_cmd, check=False, capture_output=True, text=True)
    if probe.returncode != 0:
        return False, "embedded_probe_failed"

    try:
        payload = json.loads(probe.stdout or "{}")
        streams = payload.get("streams", [])
    except Exception:
        return False, "embedded_probe_parse_failed"

    if not streams:
        return False, "embedded_not_found"

    selected = None
    for s in streams:
        lang = str(((s.get("tags") or {}).get("language") or "")).lower()
        if lang.startswith("en"):
            selected = s
            break
    if selected is None:
        selected = streams[0]

    idx = selected.get("index")
    if idx is None:
        return False, "embedded_index_missing"

    extract_cmd = [
        "ffmpeg",
        "-y",
        "-i",
        str(media_file),
        "-map",
        f"0:{idx}",
        str(out_srt),
    ]
    extract = subprocess.run(extract_cmd, check=False, capture_output=True, text=True)
    if extract.returncode != 0 or not out_srt.exists() or not out_srt.read_text(encoding="utf-8", errors="ignore").strip():
        return False, "embedded_extract_failed"
    return True, "embedded"


def transcribe_with_whisper_to_srt(audio_file: Path, out_srt: Path) -> tuple[bool, str]:
    whisper_bin = which("whisper")
    if whisper_bin is None:
        return False, "whisper_not_found"

    model = os.getenv("COURSE_PIPELINE_WHISPER_MODEL", "base")
    device = os.getenv("COURSE_PIPELINE_WHISPER_DEVICE", "").strip()
    output_dir = out_srt.parent / ".whisper"
    output_dir.mkdir(parents=True, exist_ok=True)

    cmd = [
        whisper_bin,
        str(audio_file),
        "--task",
        "transcribe",
        "--language",
        "en",
        "--output_format",
        "srt",
        "--output_dir",
        str(output_dir),
        "--model",
        model,
        "--verbose",
        "False",
    ]
    if device:
        cmd.extend(["--device", device])

    run = subprocess.run(cmd, check=False, capture_output=True, text=True)
    if run.returncode != 0:
        return False, "whisper_failed"

    generated_srt = output_dir / f"{audio_file.stem}.srt"
    if not generated_srt.exists():
        return False, "whisper_output_missing"

    text = generated_srt.read_text(encoding="utf-8", errors="ignore").strip()
    if not text:
        return False, "whisper_output_empty"

    out_srt.write_text(text + "\n", encoding="utf-8")
    return True, "whisper_local"


def write_srt(path: Path, entries: list[dict]) -> None:
    def format_ms(ms: int) -> str:
        h = ms // 3600000
        m = (ms % 3600000) // 60000
        s = (ms % 60000) // 1000
        ms_part = ms % 1000
        return f"{h:02}:{m:02}:{s:02},{ms_part:03}"

    lines: list[str] = []
    for idx, e in enumerate(entries, start=1):
        lines.append(str(idx))
        lines.append(f"{format_ms(e['start_ms'])} --> {format_ms(e['end_ms'])}")
        lines.append(e["text"])
        lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8")


def parse_srt(path: Path) -> list[dict]:
    if not path.exists():
        return []
    content = path.read_text(encoding="utf-8").strip()
    if not content:
        return []
    blocks = re.split(r"\n\s*\n", content)
    items: list[dict] = []
    ts_pattern = re.compile(
        r"(?P<s_h>\d{2}):(?P<s_m>\d{2}):(?P<s_s>\d{2}),(?P<s_ms>\d{3})\s+-->\s+"
        r"(?P<e_h>\d{2}):(?P<e_m>\d{2}):(?P<e_s>\d{2}),(?P<e_ms>\d{3})"
    )
    for b in blocks:
        lines = [l for l in b.splitlines() if l.strip()]
        if len(lines) < 2:
            continue
        ts_line = lines[1] if lines[0].isdigit() else lines[0]
        m = ts_pattern.search(ts_line)
        if not m:
            continue
        text_lines = lines[2:] if lines[0].isdigit() else lines[1:]
        text = " ".join(text_lines).strip()
        start_ms = (
            int(m.group("s_h")) * 3600000
            + int(m.group("s_m")) * 60000
            + int(m.group("s_s")) * 1000
            + int(m.group("s_ms"))
        )
        end_ms = (
            int(m.group("e_h")) * 3600000
            + int(m.group("e_m")) * 60000
            + int(m.group("e_s")) * 1000
            + int(m.group("e_ms"))
        )
        items.append({"start_ms": start_ms, "end_ms": end_ms, "text": text})
    return items


def is_pending_text(text: str) -> bool:
    value = (text or "").strip().lower()
    if not value:
        return True
    markers = [
        "[asr pending]",
        "[zh pending]",
        "[pending]",
        "[待补充]",
        "【待翻译】",
    ]
    return any(marker in value for marker in markers)


def translate_en_to_zh_ai(text: str) -> str | None:
    value = (text or "").strip()
    if not value or is_pending_text(value):
        return None
    timeout = float(os.getenv("COURSE_PIPELINE_TRANSLATE_TIMEOUT", "10"))
    endpoint = (
        "https://translate.googleapis.com/translate_a/single"
        f"?client=gtx&sl=en&tl=zh-CN&dt=t&q={quote(value)}"
    )
    req = Request(endpoint, headers={"User-Agent": "Mozilla/5.0"})
    try:
        with urlopen(req, timeout=timeout) as resp:
            payload = json.loads(resp.read().decode("utf-8", errors="ignore"))
        rows = payload[0] if isinstance(payload, list) and payload else []
        translated = "".join(str(row[0]) for row in rows if isinstance(row, list) and row and row[0])
        translated = translated.strip()
        return translated or None
    except Exception:
        return None


def _translate_google_chunk(texts: list[str], timeout: float) -> list[str | None] | None:
    if not texts:
        return []

    # Use a sentinel separator that is very unlikely to be translated/altered.
    sep = "|||__CPSEP__|||"
    while any(sep in t for t in texts):
        sep = f"{sep}_"

    endpoint = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=zh-CN&dt=t"
    joined_input = sep.join(texts)
    data = urlencode({"q": joined_input}).encode("utf-8")
    req = Request(endpoint, data=data, headers={"User-Agent": "Mozilla/5.0"})

    with urlopen(req, timeout=timeout) as resp:
        payload = json.loads(resp.read().decode("utf-8", errors="ignore"))

    rows = payload[0] if isinstance(payload, list) and payload else []
    translated_full = "".join(str(row[0]) for row in rows if isinstance(row, list) and row and row[0])
    translated_lines = [line.strip() for line in translated_full.split(sep)]
    if len(translated_lines) != len(texts):
        return None
    return [line or None for line in translated_lines]


def _chunk_indices_by_budget(items: list[tuple[int, str]], max_items: int, max_chars: int) -> list[list[tuple[int, str]]]:
    chunks: list[list[tuple[int, str]]] = []
    current: list[tuple[int, str]] = []
    current_chars = 0
    for item in items:
        item_chars = len(item[1])
        if current and (len(current) >= max_items or current_chars + item_chars > max_chars):
            chunks.append(current)
            current = []
            current_chars = 0
        current.append(item)
        current_chars += item_chars
    if current:
        chunks.append(current)
    return chunks


def batch_translate_en_to_zh_ai(texts: list[str | None]) -> list[str | None]:
    if not texts:
        return []

    to_translate: list[tuple[int, str]] = []
    for i, t in enumerate(texts):
        value = (t or "").strip()
        if value and not is_pending_text(value):
            to_translate.append((i, value))

    result: list[str | None] = [None] * len(texts)
    if not to_translate:
        return result

    # Deduplicate repeated sentences within one lesson to reduce request volume.
    index_map: dict[str, list[int]] = {}
    for idx, val in to_translate:
        index_map.setdefault(val, []).append(idx)
    unique_items = list(enumerate(index_map.keys()))

    timeout = float(os.getenv("COURSE_PIPELINE_TRANSLATE_TIMEOUT", "20"))
    max_items = max(1, int(os.getenv("COURSE_PIPELINE_TRANSLATE_BATCH_MAX_ITEMS", "40")))
    max_chars = max(200, int(os.getenv("COURSE_PIPELINE_TRANSLATE_BATCH_MAX_CHARS", "3500")))
    chunks = _chunk_indices_by_budget(unique_items, max_items=max_items, max_chars=max_chars)

    for chunk in chunks:
        chunk_texts = [val for _, val in chunk]
        translated_chunk: list[str | None] | None = None
        try:
            translated_chunk = _translate_google_chunk(chunk_texts, timeout=timeout)
        except Exception:
            translated_chunk = None

        if translated_chunk is None:
            # Fallback only for failed chunk to avoid whole-lesson request amplification.
            translated_chunk = [translate_en_to_zh_ai(val) for val in chunk_texts]

        for (_, source_text), translated in zip(chunk, translated_chunk):
            for orig_idx in index_map.get(source_text, []):
                result[orig_idx] = translated

    return result


def is_pending_ipa(value: str) -> bool:
    text = (value or "").strip().lower()
    if not text:
        return True
    return "[pending]" in text or "[ipa pending]" in text


def fetch_word_ipa(word: str) -> str | None:
    key = (word or "").strip().lower()
    if not key:
        return None
    if key in IPA_CACHE:
        return IPA_CACHE[key]

    timeout = float(os.getenv("COURSE_PIPELINE_IPA_TIMEOUT", "8"))
    endpoint = f"https://api.dictionaryapi.dev/api/v2/entries/en/{quote(key)}"
    req = Request(endpoint, headers={"User-Agent": "Mozilla/5.0"})
    ipa: str | None = None
    try:
        with urlopen(req, timeout=timeout) as resp:
            payload = json.loads(resp.read().decode("utf-8", errors="ignore"))
        if isinstance(payload, list) and payload:
            first = payload[0] if isinstance(payload[0], dict) else {}
            phonetic = first.get("phonetic")
            if isinstance(phonetic, str) and phonetic.strip():
                ipa = phonetic.strip()
            if not ipa:
                for row in first.get("phonetics", []):
                    if not isinstance(row, dict):
                        continue
                    text = row.get("text")
                    if isinstance(text, str) and text.strip():
                        ipa = text.strip()
                        break
    except Exception:
        ipa = None

    IPA_CACHE[key] = ipa
    return ipa


def generate_sentence_ipa(en: str) -> str:
    text = (en or "").strip()
    if not text:
        return "[pending]"

    has_ipa = False
    parts: list[str] = []
    for token in text.split():
        matched = WORD_PATTERN.fullmatch(token.strip(".,!?;:\"()[]{}"))
        if not matched:
            parts.append(token)
            continue
        ipa = fetch_word_ipa(matched.group(0))
        if ipa:
            parts.append(ipa)
            has_ipa = True
        else:
            parts.append(token)

    if not has_ipa:
        return "[pending]"
    return " ".join(parts)


def infer_grammar(en: str) -> dict:
    text = (en or "").strip()
    low = text.lower()
    points: list[str] = []

    if "?" in text:
        pattern = "疑问句结构"
        points.append("使用直接提问句式。")
    elif "!" in text:
        pattern = "感叹句结构"
        points.append("表达强调或强烈情绪。")
    elif any(k in low for k in ["have ", "has ", "had "]):
        pattern = "完成时表达"
        points.append("用完成时连接过去与现在。")
    elif any(k in low for k in [" was ", " were ", " did ", " went ", "got "]):
        pattern = "一般过去时"
        points.append("描述已经完成的过去事件。")
    elif any(k in low for k in [" will ", "going to "]):
        pattern = "将来表达"
        points.append("描述将来的计划或预测。")
    else:
        pattern = "陈述句结构"
        points.append("使用常见主谓结构表达信息。")

    if any(k in low for k in ["because", "when", "if", "that", "which"]):
        points.append("包含从句连接词，补充细节信息。")
    if any(k in low for k in ["very", "really", "quite", "so "]):
        points.append("包含程度副词用于加强语气。")

    difficulty = "A2" if len(text.split()) > 10 else "A1"
    return {"pattern": pattern, "points": points[:3], "difficulty": difficulty}


def infer_usage(en: str, zh: str) -> dict:
    low = (en or "").lower()
    if any(k in low for k in ["hello", "welcome", "hi"]):
        scene = "greeting"
        tone = "friendly"
    elif any(k in low for k in ["train", "station", "walk", "woods", "town"]):
        scene = "daily_life_narration"
        tone = "neutral"
    elif "?" in (en or ""):
        scene = "questioning"
        tone = "curious"
    else:
        scene = "daily_conversation"
        tone = "neutral"
    return {
        "scene": scene,
        "tone": tone,
        "formality": "informal",
        "alternatives": [zh] if zh else [],
        "caution": "",
    }


def generate_summary_and_highlights(sentences: list[dict]) -> tuple[str, list[str]]:
    zh_texts = [str(s.get("zh", "")).strip() for s in sentences if str(s.get("zh", "")).strip()]
    en_texts = [str(s.get("en", "")).strip() for s in sentences if str(s.get("en", "")).strip()]

    preview = "；".join(zh_texts[:3]) if zh_texts else "；".join(en_texts[:2])
    if not preview:
        preview = "本课涵盖基础日常表达。"
    summary = f"本课重点围绕日常表达与叙事句型，核心内容包括：{preview}。"

    highlights: list[str] = []
    all_en = " ".join(en_texts).lower()
    if any(k in all_en for k in [" was ", " were ", " did ", "went ", "got "]):
        highlights.append("一般过去时叙事表达")
    if any(k in all_en for k in ["because", "which", "that", "when", "if"]):
        highlights.append("从句连接词与句子扩展")
    if any(k in all_en for k in ["?", "!"]):
        highlights.append("疑问/感叹语气表达")
    if not highlights:
        highlights.append("基础陈述句与高频词汇表达")
    return summary, highlights[:3]


def execute_step_ffmpeg(task: dict, runtime_dir: Path) -> dict:
    if which("ffmpeg") is None or which("ffprobe") is None:
        raise RuntimeError("FFMPEG_NOT_FOUND")

    raw_folder = Path(task["course_path"])
    output_root = runtime_dir / task["task_id"] / "artifacts"
    output_root.mkdir(parents=True, exist_ok=True)
    lessons = []

    for key in task.get("lesson_keys", []):
        media = find_media_for_key(raw_folder, key)
        if media is None:
            raise RuntimeError(f"STEP_FAILED:missing_media:{key}")
        lesson_dir = output_root / key
        lesson_dir.mkdir(parents=True, exist_ok=True)

        ext = media.suffix.lower().lstrip(".")
        # Normalize video to iOS-friendly H.264/AAC to avoid green frames/artifacts.
        if ext == "mp4":
            normalized_media = lesson_dir / "media.mp4"
            normalize_cmd = [
                "ffmpeg",
                "-y",
                "-i",
                str(media),
                "-c:v",
                "libx264",
                "-pix_fmt",
                "yuv420p",
                "-profile:v",
                "high",
                "-level:v",
                "4.1",
                "-preset",
                "veryfast",
                "-crf",
                "22",
                "-movflags",
                "+faststart",
                "-c:a",
                "aac",
                "-b:a",
                "128k",
                str(normalized_media),
            ]
            subprocess.run(normalize_cmd, check=True, capture_output=True, text=True)
        else:
            normalized_media = lesson_dir / f"media.{ext}"
            normalized_media.write_bytes(media.read_bytes())

        wav_path = lesson_dir / "audio_16k.wav"
        cmd = [
            "ffmpeg",
            "-y",
            "-i",
            str(normalized_media),
            "-ac",
            "1",
            "-ar",
            "16000",
            str(wav_path),
        ]
        subprocess.run(cmd, check=True, capture_output=True, text=True)
        duration_ms = ffprobe_duration_ms(normalized_media)
        lessons.append(
            {
                "lesson_id": key,
                "media": str(normalized_media),
                "audio_16k": str(wav_path),
                "duration_ms": duration_ms,
            }
        )

    return {"lessons": lessons}


def execute_step_asr(task: dict, runtime_dir: Path) -> dict:
    raw_folder = Path(task["course_path"])
    output_root = runtime_dir / task["task_id"] / "artifacts"
    lessons = []

    for key in task.get("lesson_keys", []):
        lesson_dir = output_root / key
        lesson_dir.mkdir(parents=True, exist_ok=True)
        provided_en = raw_folder / f"{key}.en.srt"
        out_en = lesson_dir / "sub_en.srt"
        media_mp4 = lesson_dir / "media.mp4"
        if provided_en.exists():
            out_en.write_text(provided_en.read_text(encoding="utf-8"), encoding="utf-8")
            source = "provided"
        else:
            source = "placeholder"
            extracted = False
            if media_mp4.exists():
                extracted, source = extract_embedded_subtitle_to_srt(media_mp4, out_en)
            if not extracted:
                audio_16k = lesson_dir / "audio_16k.wav"
                if audio_16k.exists():
                    extracted, source = transcribe_with_whisper_to_srt(audio_16k, out_en)
                if not extracted:
                    # Placeholder ASR output for MVP skeleton.
                    write_srt(
                        out_en,
                        [
                            {
                                "start_ms": 0,
                                "end_ms": 3000,
                                "text": "[ASR pending] Please replace with real transcript.",
                            }
                        ],
                    )
        lessons.append({"lesson_id": key, "sub_en": str(out_en), "source": source})

    return {"lessons": lessons}


def execute_step_align(task: dict, runtime_dir: Path) -> dict:
    raw_folder = Path(task["course_path"])
    output_root = runtime_dir / task["task_id"] / "artifacts"
    lessons = []

    for key in task.get("lesson_keys", []):
        lesson_dir = output_root / key
        lesson_dir.mkdir(parents=True, exist_ok=True)
        provided_zh = raw_folder / f"{key}.zh.srt"
        out_zh = lesson_dir / "sub_zh.srt"
        if provided_zh.exists():
            out_zh.write_text(provided_zh.read_text(encoding="utf-8"), encoding="utf-8")
            source = "provided"
        else:
            # Placeholder alignment/translation output for MVP skeleton.
            write_srt(
                out_zh,
                [
                    {
                        "start_ms": 0,
                        "end_ms": 3000,
                        "text": "[ZH pending] 请在 translate 阶段补全中文字幕。",
                    }
                ],
            )
            source = "placeholder"
        lessons.append({"lesson_id": key, "sub_zh": str(out_zh), "source": source})

    return {"lessons": lessons}


def execute_step_translate(task: dict, runtime_dir: Path) -> dict:
    output_root = runtime_dir / task["task_id"] / "artifacts"
    work_dir = runtime_dir / task["task_id"] / "hitl"
    work_dir.mkdir(parents=True, exist_ok=True)
    lessons = []
    lesson_keys = task.get("lesson_keys", [])
    total_lessons = len(lesson_keys)

    for idx, key in enumerate(lesson_keys, start=1):
        task["translate_progress"] = {
            "current_lesson_key": key,
            "current_lesson_index": idx,
            "total_lessons": total_lessons,
        }
        save_task(runtime_dir, task)
        lesson_dir = output_root / key
        effective_file = work_dir / f"{key}_translate_effective.json"
        override_file = work_dir / f"{key}_translate_output.json"

        # Idempotent skip only when lesson translation is complete:
        # existing effective output + no override + no pending zh marker.
        if effective_file.exists() and not override_file.exists():
            reusable = False
            try:
                existing = json.loads(effective_file.read_text(encoding="utf-8"))
                sentences = existing.get("sentences", [])
                reusable = bool(sentences) and all(not is_pending_text(str(item.get("zh", ""))) for item in sentences)
            except Exception:
                reusable = False

        if effective_file.exists() and not override_file.exists() and reusable:
            input_file = work_dir / f"{key}_translate_input.json"
            if not input_file.exists():
                input_items = [
                    {
                        "sentence_id": item.get("sentence_id", ""),
                        "start_ms": int(item.get("start_ms", 0)),
                        "end_ms": int(item.get("end_ms", 0)),
                        "en": item.get("en", ""),
                        "zh": item.get("zh", ""),
                    }
                    for item in existing.get("sentences", [])
                ]
                input_file.write_text(
                    json.dumps({"lesson_id": key, "sentences": input_items}, ensure_ascii=False, indent=2),
                    encoding="utf-8",
                )
            lessons.append(
                {
                    "lesson_id": key,
                    "input_file": str(input_file),
                    "output_file": str(effective_file),
                    "source": "reuse_existing",
                }
            )
            continue

        en_entries = parse_srt(lesson_dir / "sub_en.srt")
        zh_entries = parse_srt(lesson_dir / "sub_zh.srt")

        input_items = []
        for idx, en in enumerate(en_entries):
            zh_text = zh_entries[idx]["text"] if idx < len(zh_entries) else ""
            input_items.append(
                {
                    "sentence_id": f"{key}-{idx + 1:04d}",
                    "start_ms": en["start_ms"],
                    "end_ms": en["end_ms"],
                    "en": en["text"],
                    "zh": zh_text,
                }
            )

        input_file = work_dir / f"{key}_translate_input.json"
        input_file.write_text(
            json.dumps({"lesson_id": key, "sentences": input_items}, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )

        if override_file.exists():
            result = json.loads(override_file.read_text(encoding="utf-8"))
            out_items = result.get("sentences", input_items)
            source = "hitl_override"
        else:
            has_real_transcript = any(not is_pending_text(item.get("en", "")) for item in input_items)
            if not has_real_transcript:
                raise RuntimeError(f"ASR_NOT_READY:{key}")
                
            en_to_translate = []
            for item in input_items:
                existing_zh = item.get("zh", "")
                if is_pending_text(existing_zh):
                    en_to_translate.append(item.get("en", ""))
                else:
                    en_to_translate.append(None)
                    
            batch_translated = batch_translate_en_to_zh_ai(en_to_translate)
            
            out_items = []
            ai_translated = 0
            for i, item in enumerate(input_items):
                existing_zh = item.get("zh", "")
                ai_zh = None
                if is_pending_text(existing_zh):
                    ai_zh = batch_translated[i]
                    if ai_zh:
                        ai_translated += 1
                out_items.append(
                    {
                        **item,
                        "zh": ai_zh or (f"【待翻译】{item['en']}" if is_pending_text(existing_zh) else existing_zh),
                        "ipa": generate_sentence_ipa(item.get("en", "")),
                    }
                )
            source = "ai_online" if ai_translated > 0 else "fallback"

        for item in out_items:
            if is_pending_ipa(item.get("ipa", "")):
                item["ipa"] = generate_sentence_ipa(item.get("en", ""))

        output_file = effective_file
        output_file.write_text(
            json.dumps({"lesson_id": key, "sentences": out_items, "source": source}, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        # Keep packaged subtitle file consistent with effective translation output.
        write_srt(
            lesson_dir / "sub_zh.srt",
            [
                {
                    "start_ms": int(item.get("start_ms", 0)),
                    "end_ms": int(item.get("end_ms", 0)),
                    "text": item.get("zh", ""),
                }
                for item in out_items
            ],
        )
        lessons.append({"lesson_id": key, "input_file": str(input_file), "output_file": str(output_file), "source": source})

    task["translate_progress"] = {
        "current_lesson_key": None,
        "current_lesson_index": total_lessons,
        "total_lessons": total_lessons,
    }
    save_task(runtime_dir, task)
    return {"lessons": lessons}


def execute_step_grammar(task: dict, runtime_dir: Path) -> dict:
    work_dir = runtime_dir / task["task_id"] / "hitl"
    work_dir.mkdir(parents=True, exist_ok=True)
    lessons = []

    for key in task.get("lesson_keys", []):
        translate_file = work_dir / f"{key}_translate_effective.json"
        if not translate_file.exists():
            raise RuntimeError(f"STEP_FAILED:missing_translate_effective:{key}")
        translated = json.loads(translate_file.read_text(encoding="utf-8"))
        in_sentences = translated.get("sentences", [])

        grammar_input = []
        for s in in_sentences:
            grammar_input.append(
                {
                    "sentence_id": s["sentence_id"],
                    "en": s["en"],
                    "zh": s.get("zh", ""),
                }
            )
        input_file = work_dir / f"{key}_grammar_input.json"
        input_file.write_text(
            json.dumps({"lesson_id": key, "sentences": grammar_input}, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )

        override_file = work_dir / f"{key}_grammar_output.json"
        if override_file.exists():
            result = json.loads(override_file.read_text(encoding="utf-8"))
            out_sentences = result.get("sentences", [])
            source = "hitl_override"
        else:
            out_sentences = []
            for s in grammar_input:
                grammar_obj = infer_grammar(s.get("en", ""))
                usage_obj = infer_usage(s.get("en", ""), s.get("zh", ""))
                out_sentences.append(
                    {
                        "sentence_id": s["sentence_id"],
                        "grammar": grammar_obj,
                        "usage": usage_obj,
                    }
                )
            source = "auto_generated"

        output_file = work_dir / f"{key}_grammar_effective.json"
        output_file.write_text(
            json.dumps({"lesson_id": key, "sentences": out_sentences, "source": source}, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        lessons.append({"lesson_id": key, "input_file": str(input_file), "output_file": str(output_file), "source": source})

    return {"lessons": lessons}


def execute_step_summary(task: dict, runtime_dir: Path) -> dict:
    work_dir = runtime_dir / task["task_id"] / "hitl"
    work_dir.mkdir(parents=True, exist_ok=True)
    lessons = []

    for key in task.get("lesson_keys", []):
        translate_file = work_dir / f"{key}_translate_effective.json"
        if not translate_file.exists():
            raise RuntimeError(f"STEP_FAILED:missing_translate_effective:{key}")
        translated = json.loads(translate_file.read_text(encoding="utf-8"))
        in_sentences = translated.get("sentences", [])
        input_file = work_dir / f"{key}_summary_input.json"
        input_file.write_text(
            json.dumps({"lesson_id": key, "sentences": in_sentences}, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )

        override_file = work_dir / f"{key}_summary_output.json"
        if override_file.exists():
            summary_data = json.loads(override_file.read_text(encoding="utf-8"))
            source = "hitl_override"
        else:
            summary, highlights = generate_summary_and_highlights(in_sentences)
            summary_data = {
                "lesson_id": key,
                "summary": summary,
                "grammar_highlights": highlights,
            }
            source = "auto_generated"

        output_file = work_dir / f"{key}_summary_effective.json"
        output_file.write_text(
            json.dumps({**summary_data, "source": source}, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        lessons.append({"lesson_id": key, "input_file": str(input_file), "output_file": str(output_file), "source": source})

    return {"lessons": lessons}


def execute_step_package(task: dict, runtime_dir: Path) -> dict:
    output_root = runtime_dir / task["task_id"] / "artifacts"
    work_dir = runtime_dir / task["task_id"] / "hitl"
    package_dir = runtime_dir / task["task_id"] / "package"
    lessons_dir = package_dir / "lessons"
    lessons_dir.mkdir(parents=True, exist_ok=True)

    lesson_entries = []
    for key in task.get("lesson_keys", []):
        src_lesson = output_root / key
        dst_lesson = lessons_dir / key
        dst_lesson.mkdir(parents=True, exist_ok=True)
        for name in ["media.mp4", "media.mp3", "sub_en.srt", "sub_zh.srt"]:
            src = src_lesson / name
            if src.exists():
                (dst_lesson / name).write_bytes(src.read_bytes())
        if not (dst_lesson / "sub_en.srt").exists() and (src_lesson / "sub_en.srt").exists():
            (dst_lesson / "sub_en.srt").write_bytes((src_lesson / "sub_en.srt").read_bytes())
        if not (dst_lesson / "sub_zh.srt").exists() and (src_lesson / "sub_zh.srt").exists():
            (dst_lesson / "sub_zh.srt").write_bytes((src_lesson / "sub_zh.srt").read_bytes())

        translate_effective = work_dir / f"{key}_translate_effective.json"
        grammar_effective = work_dir / f"{key}_grammar_effective.json"
        summary_effective = work_dir / f"{key}_summary_effective.json"
        translated_sentences = []
        grammar_sentences = {}
        summary_data = {"summary": "[pending]", "grammar_highlights": ["[pending]"]}
        if translate_effective.exists():
            translated_sentences = json.loads(translate_effective.read_text(encoding="utf-8")).get("sentences", [])
        if grammar_effective.exists():
            grammar_rows = json.loads(grammar_effective.read_text(encoding="utf-8")).get("sentences", [])
            grammar_sentences = {r["sentence_id"]: r for r in grammar_rows if "sentence_id" in r}
        if summary_effective.exists():
            summary_data = json.loads(summary_effective.read_text(encoding="utf-8"))

        lesson_sentences = []
        for idx, s in enumerate(translated_sentences):
            sid = s.get("sentence_id", f"{key}-{idx+1:04d}")
            g = grammar_sentences.get(sid, {})
            grammar_obj = g.get("grammar", {"pattern": "[pending]", "points": ["[pending]"]})
            usage_obj = g.get("usage", {"scene": "[pending]", "tone": "neutral", "formality": "informal"})
            lesson_sentences.append(
                {
                    "sentence_id": sid,
                    "start_ms": s.get("start_ms", 0),
                    "end_ms": s.get("end_ms", 3000),
                    "en": s.get("en", "[pending]"),
                    "zh": s.get("zh", "[待补充]"),
                    "ipa": s.get("ipa", "[pending]"),
                    "grammar": {
                        "pattern": grammar_obj.get("pattern", "[pending]"),
                        "points": grammar_obj.get("points", ["[pending]"]),
                        "difficulty": grammar_obj.get("difficulty", "A1"),
                    },
                    "usage": {
                        "scene": usage_obj.get("scene", "[pending]"),
                        "tone": usage_obj.get("tone", "neutral"),
                        "formality": usage_obj.get("formality", "informal"),
                        "alternatives": usage_obj.get("alternatives", []),
                        "caution": usage_obj.get("caution", ""),
                    },
                    "status": {
                        "translation_ready": not is_pending_text(s.get("zh", "")),
                        "ipa_ready": not is_pending_ipa(s.get("ipa", "")),
                        "grammar_ready": grammar_obj.get("pattern", "") != "[pending]",
                        "usage_ready": usage_obj.get("scene", "") != "[pending]",
                    },
                }
            )
        if not lesson_sentences:
            lesson_sentences = [
                {
                    "sentence_id": f"{key}-0001",
                    "start_ms": 0,
                    "end_ms": 3000,
                    "en": "[Pending]",
                    "zh": "[待补充]",
                    "ipa": "[pending]",
                    "grammar": {"pattern": "[pending]", "points": ["[pending]"], "difficulty": "A1"},
                    "usage": {"scene": "[pending]", "tone": "neutral", "formality": "informal", "alternatives": [], "caution": ""},
                    "status": {
                        "translation_ready": False,
                        "ipa_ready": False,
                        "grammar_ready": False,
                        "usage_ready": False,
                    },
                }
            ]

        lesson_json = {
            "lesson_id": key,
            "order": int(key),
            "title": f"Lesson {key}",
            "media": {
                "type": "video" if (dst_lesson / "media.mp4").exists() else "audio",
                "path": "media.mp4" if (dst_lesson / "media.mp4").exists() else "media.mp3",
            },
            "subtitles": {
                "en": "sub_en.srt" if (dst_lesson / "sub_en.srt").exists() else "",
                "zh": "sub_zh.srt" if (dst_lesson / "sub_zh.srt").exists() else "",
            },
            "summary": summary_data.get("summary", "[pending]"),
            "grammar_highlights": summary_data.get("grammar_highlights", ["[pending]"]),
            "sentences": lesson_sentences,
        }
        (dst_lesson / "lesson.json").write_text(json.dumps(lesson_json, ensure_ascii=False, indent=2), encoding="utf-8")
        lesson_entries.append(
            {"lesson_id": key, "path": f"lessons/{key}/lesson.json", "status": "ready" if task["status"] == "ready" else "processing"}
        )

    manifest = {
        "schema_version": "1.0.0",
        "course_id": task["course_id"],
        "title": resolve_course_manifest_title(task, package_dir),
        "lesson_count": len(lesson_entries),
        "lessons": lesson_entries,
    }
    (package_dir / "course_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    return {"package_dir": str(package_dir), "manifest": str(package_dir / "course_manifest.json")}


def execute_step(step: str, task: dict, runtime_dir: Path) -> dict:
    if step == "ffmpeg":
        return execute_step_ffmpeg(task, runtime_dir)
    if step == "asr":
        return execute_step_asr(task, runtime_dir)
    if step == "align":
        return execute_step_align(task, runtime_dir)
    if step == "translate":
        return execute_step_translate(task, runtime_dir)
    if step == "grammar":
        return execute_step_grammar(task, runtime_dir)
    if step == "summary":
        return execute_step_summary(task, runtime_dir)
    if step == "package":
        return execute_step_package(task, runtime_dir)
    return {
        "step": step,
        "hitl": step in HITL_STEPS,
        "note": "placeholder output; integrate real processor in step executors",
    }


def scan_raw_lessons(raw_folder: Path) -> tuple[list[str], str | None]:
    keys: list[str] = []
    seen: set[str] = set()
    for p in sorted(raw_folder.iterdir()):
        if not p.is_file():
            continue
        m = MEDIA_PATTERN.match(p.name)
        if not m:
            continue
        key = m.group(1)
        if key in seen:
            return [], "RAW_FOLDER_DUPLICATE_LESSON"
        seen.add(key)
        keys.append(key)
    if not keys:
        return [], "RAW_FOLDER_INVALID_NAME"
    return keys, None


def cmd_course_add(args: argparse.Namespace) -> int:
    project_root = Path(args.project_root).expanduser().resolve()
    runtime_dir = project_runtime_dir(project_root)
    raw_folder = Path(args.folder_path).expanduser().resolve()

    if not raw_folder.exists() or not raw_folder.is_dir():
        return out({"ok": False, "error": {"code": "RAW_FOLDER_NOT_FOUND", "message": str(raw_folder)}}, 2)

    lesson_keys, err = scan_raw_lessons(raw_folder)
    if err:
        return out({"ok": False, "error": {"code": err, "message": "invalid raw folder media naming"}}, 2)

    task_id = f"task_{uuid.uuid4().hex[:8]}"
    task = {
        "task_id": task_id,
        "course_id": normalize_course_id(raw_folder),
        "course_title": raw_folder.name,
        "course_path": str(raw_folder),
        "status": "uploaded",
        "current_step": "ffmpeg",
        "steps": {s: "pending" for s in STEP_ORDER},
        "lesson_keys": lesson_keys,
        "error": None,
        "options": {
            "reading_light_mode": bool(getattr(args, "reading_light_mode", False)),
        },
        "created_at": now_iso(),
        "updated_at": now_iso(),
    }
    save_task(runtime_dir, task)
    append_event(runtime_dir, task_id, "course.add", {"course_path": str(raw_folder), "lessons": lesson_keys})
    if getattr(args, "auto_start", True):
        code, payload = _run_auto_until_hitl_or_terminal(runtime_dir, task_id)
        if code != 0:
            return out(
                {
                    "ok": False,
                    "task": task,
                    "auto_start": payload,
                },
                code,
            )
        return out(
            {
                "ok": True,
                "task": payload.get("task", task),
                "auto_started": True,
                "auto_executed_steps": payload.get("executed_steps", []),
            }
        )
    return out({"ok": True, "task": task, "auto_started": False, "auto_executed_steps": []})


def cmd_course_delete(args: argparse.Namespace) -> int:
    project_root = Path(args.project_root).expanduser().resolve()
    runtime_dir = project_runtime_dir(project_root)

    removed = []
    for p in runtime_dir.glob("task_*.json"):
        t = json.loads(p.read_text(encoding="utf-8"))
        if t.get("course_id") == args.course_id:
            removed.append(t["task_id"])
            p.unlink(missing_ok=True)

    append_event(runtime_dir, "-", "course.delete", {"course_id": args.course_id, "removed_tasks": removed})
    return out({"ok": True, "course_id": args.course_id, "removed_tasks": removed})


def cmd_task_get(args: argparse.Namespace) -> int:
    runtime_dir = project_runtime_dir(Path(args.project_root).expanduser().resolve())
    try:
        task = load_task(runtime_dir, args.task_id)
    except FileNotFoundError:
        return out({"ok": False, "error": {"code": "TASK_NOT_FOUND", "message": args.task_id}}, 2)
    return out({"ok": True, "task": task})


def cmd_task_list(args: argparse.Namespace) -> int:
    runtime_dir = project_runtime_dir(Path(args.project_root).expanduser().resolve())
    tasks = []
    for p in sorted(runtime_dir.glob("task_*.json")):
        t = json.loads(p.read_text(encoding="utf-8"))
        if args.status and t.get("status") != args.status:
            continue
        publish = t.get("publish", {})
        published_mode = ""
        published_at = ""
        if isinstance(publish, dict):
            published_mode = str(publish.get("mode") or "")
            published_at = str(publish.get("published_at") or "")

        if args.brief:
            tasks.append(
                {
                    "task_id": t.get("task_id"),
                    "course_id": t.get("course_id"),
                    "status": t.get("status"),
                    "current_step": t.get("current_step"),
                    "updated_at": t.get("updated_at"),
                    "published_mode": published_mode,
                    "published_at": published_at,
                }
            )
        else:
            t["published_mode"] = published_mode
            t["published_at"] = published_at
            tasks.append(t)
    return out({"ok": True, "tasks": tasks})


def set_task_status(runtime_dir: Path, task_id: str, status: str, event: str) -> int:
    if status not in STATUSES:
        return out({"ok": False, "error": {"code": "INVALID_STATUS", "message": status}}, 2)
    try:
        task = load_task(runtime_dir, task_id)
    except FileNotFoundError:
        return out({"ok": False, "error": {"code": "TASK_NOT_FOUND", "message": task_id}}, 2)

    task["status"] = status
    save_task(runtime_dir, task)
    append_event(runtime_dir, task_id, event, {"status": status})
    return out({"ok": True, "task": task})


def cmd_task_pause(args: argparse.Namespace) -> int:
    return set_task_status(project_runtime_dir(Path(args.project_root).expanduser().resolve()), args.task_id, "paused", "task.pause")


def cmd_task_resume(args: argparse.Namespace) -> int:
    return set_task_status(project_runtime_dir(Path(args.project_root).expanduser().resolve()), args.task_id, "processing", "task.resume")


def cmd_task_stop(args: argparse.Namespace) -> int:
    return set_task_status(project_runtime_dir(Path(args.project_root).expanduser().resolve()), args.task_id, "stopped", "task.stop")


def cmd_task_delete(args: argparse.Namespace) -> int:
    runtime_dir = project_runtime_dir(Path(args.project_root).expanduser().resolve())
    p = task_file(runtime_dir, args.task_id)
    if not p.exists():
        return out({"ok": False, "error": {"code": "TASK_NOT_FOUND", "message": args.task_id}}, 2)
    p.unlink(missing_ok=True)
    append_event(runtime_dir, args.task_id, "task.delete", {})
    return out({"ok": True, "task_id": args.task_id})


def cmd_task_retry(args: argparse.Namespace) -> int:
    runtime_dir = project_runtime_dir(Path(args.project_root).expanduser().resolve())
    try:
        task = load_task(runtime_dir, args.task_id)
    except FileNotFoundError:
        return out({"ok": False, "error": {"code": "TASK_NOT_FOUND", "message": args.task_id}}, 2)

    step = args.from_step
    if step and step not in STEP_ORDER:
        return out({"ok": False, "error": {"code": "INVALID_STEP", "message": step}}, 2)

    if step:
        trigger = False
        for s in STEP_ORDER:
            if s == step:
                trigger = True
            if trigger:
                task["steps"][s] = "pending"
        task["current_step"] = step
    else:
        task["steps"] = {s: "pending" for s in STEP_ORDER}
        task["current_step"] = "ffmpeg"

    task["status"] = "processing"
    task["error"] = None
    save_task(runtime_dir, task)
    append_event(runtime_dir, args.task_id, "task.retry", {"from_step": step})
    return out({"ok": True, "task": task})


def _next_incomplete_step(task: dict) -> str | None:
    for s in STEP_ORDER:
        if task["steps"].get(s) != "done":
            return s
    return None


def is_reading_light_mode(task: dict) -> bool:
    options = task.get("options", {})
    if not isinstance(options, dict):
        return False
    return bool(options.get("reading_light_mode", False))


def _run_single_step(runtime_dir: Path, task_id: str, step: str) -> tuple[int, dict]:
    if step not in STEP_ORDER:
        return 2, {"ok": False, "error": {"code": "INVALID_STEP", "message": step}}

    try:
        task = load_task(runtime_dir, task_id)
    except FileNotFoundError:
        return 2, {"ok": False, "error": {"code": "TASK_NOT_FOUND", "message": task_id}}

    running_steps = [s for s, state in task["steps"].items() if state == "running"]
    if running_steps:
        return 3, {
            "ok": False,
            "error": {
                "code": "STEP_FAILED",
                "message": f"another step is running: {running_steps[0]}",
                "step": running_steps[0],
            },
        }

    step_index = STEP_ORDER.index(step)
    for prev in STEP_ORDER[:step_index]:
        if task["steps"][prev] != "done":
            if step == "package" and is_reading_light_mode(task) and prev in {"grammar", "summary"}:
                continue
            return 3, {
                "ok": False,
                "error": {
                    "code": "STEP_FAILED",
                    "message": f"step '{step}' requires '{prev}' done first",
                    "step": step,
                },
            }

    task["status"] = "processing"
    task["current_step"] = step
    task["steps"][step] = "running"
    save_task(runtime_dir, task)
    append_event(runtime_dir, task_id, "task.run_step.start", {"step": step, "hitl": step in HITL_STEPS})

    out_dir = runtime_dir / task_id
    out_dir.mkdir(parents=True, exist_ok=True)

    try:
        step_payload = execute_step(step, task, runtime_dir)
        output = {
            "task_id": task_id,
            "step": step,
            "hitl": step in HITL_STEPS,
            "generated_at": now_iso(),
            "payload": step_payload,
        }
        out_file = out_dir / f"output_{step}.json"
        out_file.write_text(json.dumps(output, ensure_ascii=False, indent=2), encoding="utf-8")
        task["steps"][step] = "done"
        task["error"] = None
    except Exception as exc:
        task["steps"][step] = "failed"
        task["status"] = "failed"
        task["error"] = {"code": "STEP_FAILED", "message": str(exc), "step": step}
        save_task(runtime_dir, task)
        append_event(runtime_dir, task_id, "task.run_step.failed", {"step": step, "error": task["error"]})
        return 3, {"ok": False, "task": task, "error": task["error"]}

    next_step = _next_incomplete_step(task)
    if next_step:
        task["current_step"] = next_step
    else:
        task["current_step"] = "package"
        task["status"] = "ready"

    save_task(runtime_dir, task)
    append_event(runtime_dir, task_id, "task.run_step.done", {"step": step, "output_file": str(out_file)})
    return 0, {"ok": True, "task": task, "output_file": str(out_file)}


def _run_auto_until_hitl_or_terminal(runtime_dir: Path, task_id: str) -> tuple[int, dict]:
    try:
        task = load_task(runtime_dir, task_id)
    except FileNotFoundError:
        return 2, {"ok": False, "error": {"code": "TASK_NOT_FOUND", "message": task_id}}

    executed: list[str] = []
    while True:
        if task.get("status") in TERMINAL_STATUSES:
            break
        step = _next_incomplete_step(task)
        if step is None or step in HITL_STEPS:
            break

        code, payload = _run_single_step(runtime_dir, task_id, step)
        if code != 0:
            return code, {
                "ok": False,
                "executed_steps": executed,
                "error": payload.get("error"),
                "task": payload.get("task"),
            }
        executed.append(step)
        task = payload.get("task", task)

    return 0, {"ok": True, "executed_steps": executed, "task": task}


def cmd_task_run_step(args: argparse.Namespace) -> int:
    runtime_dir = project_runtime_dir(Path(args.project_root).expanduser().resolve())
    if getattr(args, "reading_light_mode", False):
        try:
            task = load_task(runtime_dir, args.task_id)
        except FileNotFoundError:
            return out({"ok": False, "error": {"code": "TASK_NOT_FOUND", "message": args.task_id}}, 2)
        options = task.get("options", {})
        if not isinstance(options, dict):
            options = {}
        if not options.get("reading_light_mode", False):
            options["reading_light_mode"] = True
            task["options"] = options
            save_task(runtime_dir, task)
            append_event(runtime_dir, args.task_id, "task.option.update", {"reading_light_mode": True})

    code, payload = _run_single_step(runtime_dir, args.task_id, args.step)
    if code != 0:
        return out(payload, code)

    executed = [args.step]
    last_payload = payload

    if getattr(args, "auto_chain", True):
        while True:
            task = last_payload.get("task", {})
            if task.get("status") in TERMINAL_STATUSES:
                break
            next_step = _next_incomplete_step(task)
            if not next_step or next_step in HITL_STEPS:
                break
            code, last_payload = _run_single_step(runtime_dir, args.task_id, next_step)
            if code != 0:
                return out(
                    {
                        "ok": False,
                        "executed_steps": executed,
                        "error": last_payload.get("error", {"code": "STEP_FAILED", "message": "auto-chain failed"}),
                        "task": last_payload.get("task"),
                    },
                    code,
                )
            executed.append(next_step)

    result = {
        "ok": True,
        "executed_steps": executed,
        "task": last_payload.get("task"),
        "output_file": last_payload.get("output_file"),
    }
    return out(result)


def cmd_task_run_auto(args: argparse.Namespace) -> int:
    runtime_dir = project_runtime_dir(Path(args.project_root).expanduser().resolve())
    code, payload = _run_auto_until_hitl_or_terminal(runtime_dir, args.task_id)
    return out(payload, code)


def notify(title: str, message: str) -> None:
    if sys.platform != "darwin":
        return
    script = f'display notification "{message}" with title "{title}"'
    try:
        subprocess.run(["osascript", "-e", script], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass


def cmd_task_watch(args: argparse.Namespace) -> int:
    runtime_dir = project_runtime_dir(Path(args.project_root).expanduser().resolve())
    timeout_deadline = time.time() + args.timeout if args.timeout and args.timeout > 0 else None
    last_status = None

    while True:
        try:
            task = load_task(runtime_dir, args.task_id)
        except FileNotFoundError:
            return out({"ok": False, "error": {"code": "TASK_NOT_FOUND", "message": args.task_id}}, 2)

        status = task["status"]
        if status != last_status:
            out({"ok": True, "watch": {"task_id": args.task_id, "status": status, "current_step": task.get("current_step")}})
            last_status = status

        if status in TERMINAL_STATUSES:
            notify("Course Task", f"{args.task_id} is {status}")
            return out({"ok": True, "final": task})

        if timeout_deadline and time.time() >= timeout_deadline:
            return out({"ok": False, "error": {"code": "WATCH_TIMEOUT", "message": args.task_id}}, 3)

        time.sleep(max(args.interval, 1))


def cmd_package_inspect(args: argparse.Namespace) -> int:
    file_path = Path(args.file_path).expanduser().resolve()
    if not file_path.exists() or not file_path.is_file():
        return out({"ok": False, "error": {"code": "FILE_NOT_FOUND", "message": str(file_path)}}, 2)
    digest, size_bytes = sha256_and_size(file_path)
    return out(
        {
            "ok": True,
            "file": str(file_path),
            "sha256": digest,
            "size_bytes": size_bytes,
        }
    )


def cmd_package_build_catalog(args: argparse.Namespace) -> int:
    package_file = Path(args.file_path).expanduser().resolve()
    if not package_file.exists() or not package_file.is_file():
        return out({"ok": False, "error": {"code": "FILE_NOT_FOUND", "message": str(package_file)}}, 2)

    digest, size_bytes = sha256_and_size(package_file)
    output_file = Path(args.out).expanduser().resolve()
    output_file.parent.mkdir(parents=True, exist_ok=True)

    mode = (args.mode or "auto").strip().lower()
    if mode not in {"auto", "zip", "segmented_zip"}:
        return out({"ok": False, "error": {"code": "INVALID_MODE", "message": "--mode must be auto|zip|segmented_zip"}}, 2)

    if mode == "auto":
        threshold_mib = max(1, int(args.threshold_mib))
        threshold_bytes = threshold_mib * 1024 * 1024
        mode = "zip" if size_bytes <= threshold_bytes else "segmented_zip"

    asset: dict
    if mode == "zip":
        if not (args.zip_url or "").strip():
            return out({"ok": False, "error": {"code": "ZIP_URL_REQUIRED", "message": "--zip-url is required for zip mode"}}, 2)
        asset = {
            "mode": "zip",
            "url": args.zip_url.strip(),
            "size_bytes": size_bytes,
            "sha256": digest,
        }
    else:
        if not (args.manifest_url or "").strip():
            return out({"ok": False, "error": {"code": "MANIFEST_URL_REQUIRED", "message": "--manifest-url is required for segmented_zip mode"}}, 2)
        asset = {
            "mode": "segmented_zip",
            "manifest_url": args.manifest_url.strip(),
            "size_bytes": size_bytes,
            "sha256": digest,
        }

    item = {
        "id": args.course_id,
        "title": args.title or args.course_id,
        "tags": [tag.strip() for tag in (args.tags or "").split(",") if tag.strip()],
        "version": args.version_name,
        "cover": args.cover_url,
        "asset": asset,
    }
    existing_payload = None
    if output_file.exists() and not args.catalog_replace:
        try:
            loaded = json.loads(output_file.read_text(encoding="utf-8"))
            if isinstance(loaded, dict):
                existing_payload = loaded
        except Exception:
            existing_payload = None
    payload = (
        {"version": int(args.catalog_version), "courses": [item]}
        if args.catalog_replace
        else merge_catalog_courses(existing_payload, item, int(args.catalog_version))
    )
    output_file.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    return out(
        {
            "ok": True,
            "catalog": str(output_file),
            "mode": mode,
            "course": item,
        }
    )


def cmd_package_upload_minio(args: argparse.Namespace) -> int:
    file_path = Path(args.file_path).expanduser().resolve()
    if not file_path.exists() or not file_path.is_file():
        return out({"ok": False, "error": {"code": "FILE_NOT_FOUND", "message": str(file_path)}}, 2)

    access_key = read_secret_arg_or_env(args.access_key, "COURSE_PIPELINE_MINIO_ACCESS_KEY")
    secret_key = read_secret_arg_or_env(args.secret_key, "COURSE_PIPELINE_MINIO_SECRET_KEY")
    if not access_key or not secret_key:
        return out(
            {
                "ok": False,
                "error": {
                    "code": "MINIO_CREDENTIALS_REQUIRED",
                    "message": "provide --access-key/--secret-key or env COURSE_PIPELINE_MINIO_ACCESS_KEY/COURSE_PIPELINE_MINIO_SECRET_KEY",
                },
            },
            2,
        )
    object_key = args.object_key or file_path.name
    try:
        object_url, _ = run_mc_copy(
            endpoint=args.endpoint,
            access_key=access_key,
            secret_key=secret_key,
            bucket=args.bucket,
            object_key=object_key,
            source_file=file_path,
            make_bucket=args.make_bucket,
        )
    except RuntimeError as exc:
        return out({"ok": False, "error": {"code": str(exc), "message": "install minio client: brew install minio/stable/mc"}}, 2)
    except subprocess.CalledProcessError as exc:
        detail = (exc.stderr or exc.stdout or "").strip()
        return out({"ok": False, "error": {"code": "MINIO_UPLOAD_FAILED", "message": detail or "mc cp failed"}}, 3)
    except Exception as exc:
        return out({"ok": False, "error": {"code": "MINIO_UPLOAD_FAILED", "message": str(exc)}}, 3)

    return out(
        {
            "ok": True,
            "file": str(file_path),
            "bucket": args.bucket,
            "object_key": object_key,
            "url": object_url,
        }
    )


def cmd_package_upload_minio_segmented(args: argparse.Namespace) -> int:
    file_path = Path(args.file_path).expanduser().resolve()
    if not file_path.exists() or not file_path.is_file():
        return out({"ok": False, "error": {"code": "FILE_NOT_FOUND", "message": str(file_path)}}, 2)

    access_key = read_secret_arg_or_env(args.access_key, "COURSE_PIPELINE_MINIO_ACCESS_KEY")
    secret_key = read_secret_arg_or_env(args.secret_key, "COURSE_PIPELINE_MINIO_SECRET_KEY")
    if not access_key or not secret_key:
        return out(
            {
                "ok": False,
                "error": {
                    "code": "MINIO_CREDENTIALS_REQUIRED",
                    "message": "provide --access-key/--secret-key or env COURSE_PIPELINE_MINIO_ACCESS_KEY/COURSE_PIPELINE_MINIO_SECRET_KEY",
                },
            },
            2,
        )

    part_size_mib = int(args.part_size_mib)
    if part_size_mib < 1:
        return out(
            {
                "ok": False,
                "error": {
                    "code": "INVALID_PART_SIZE",
                    "message": "--part-size-mib must be >= 1",
                },
            },
            2,
        )

    part_size_bytes = part_size_mib * 1024 * 1024
    source_size = file_path.stat().st_size
    total_parts = (source_size + part_size_bytes - 1) // part_size_bytes if source_size else 0
    if total_parts <= 0:
        return out(
            {
                "ok": False,
                "error": {
                    "code": "EMPTY_FILE",
                    "message": "source file is empty",
                },
            },
            2,
        )

    prefix = normalize_object_prefix(args.object_prefix, file_path.name)
    manifest_local_path = Path(args.manifest_out).expanduser().resolve() if args.manifest_out else file_path.with_suffix(file_path.suffix + ".parts.json")
    manifest_local_path.parent.mkdir(parents=True, exist_ok=True)

    source_digest = hashlib.sha256()
    parts: list[dict] = []
    uploaded_count = 0
    uploaded_bytes = 0

    try:
        with file_path.open("rb") as src:
            for index in range(1, total_parts + 1):
                chunk = src.read(part_size_bytes)
                if not chunk:
                    break
                source_digest.update(chunk)
                part_digest = hashlib.sha256(chunk).hexdigest()
                object_key = segmented_part_object_key(prefix, index, total_parts)

                temp_part = tempfile.NamedTemporaryFile(prefix="cp-seg-", suffix=".part", delete=False)
                temp_part_path = Path(temp_part.name)
                try:
                    with temp_part:
                        temp_part.write(chunk)
                    object_url, _ = run_mc_copy(
                        endpoint=args.endpoint,
                        access_key=access_key,
                        secret_key=secret_key,
                        bucket=args.bucket,
                        object_key=object_key,
                        source_file=temp_part_path,
                        make_bucket=args.make_bucket and index == 1,
                    )
                finally:
                    temp_part_path.unlink(missing_ok=True)

                part_size = len(chunk)
                uploaded_count += 1
                uploaded_bytes += part_size
                parts.append(
                    {
                        "index": index,
                        "object_key": object_key,
                        "size_bytes": part_size,
                        "sha256": part_digest,
                        "url": object_url,
                    }
                )
    except RuntimeError as exc:
        return out({"ok": False, "error": {"code": str(exc), "message": "install minio client: brew install minio/stable/mc"}}, 2)
    except subprocess.CalledProcessError as exc:
        detail = (exc.stderr or exc.stdout or "").strip()
        return out(
            {
                "ok": False,
                "error": {
                    "code": "MINIO_SEGMENT_UPLOAD_FAILED",
                    "message": detail or "mc cp failed",
                    "uploaded_parts": uploaded_count,
                    "uploaded_bytes": uploaded_bytes,
                },
            },
            3,
        )
    except Exception as exc:
        return out(
            {
                "ok": False,
                "error": {
                    "code": "MINIO_SEGMENT_UPLOAD_FAILED",
                    "message": str(exc),
                    "uploaded_parts": uploaded_count,
                    "uploaded_bytes": uploaded_bytes,
                },
            },
            3,
        )

    manifest_payload = {
        "schema_version": 1,
        "created_at": now_iso(),
        "bucket": args.bucket,
        "endpoint": args.endpoint.rstrip("/"),
        "source_file": str(file_path),
        "source_name": file_path.name,
        "source_size_bytes": source_size,
        "source_sha256": source_digest.hexdigest(),
        "part_size_bytes": part_size_bytes,
        "part_count": len(parts),
        "object_prefix": prefix,
        "parts": parts,
    }
    manifest_local_path.write_text(json.dumps(manifest_payload, ensure_ascii=False, indent=2), encoding="utf-8")

    manifest_object_key = ""
    manifest_url = ""
    if not args.skip_upload_manifest:
        manifest_object_key = args.manifest_object_key or f"{prefix}.manifest.json"
        try:
            manifest_url, _ = run_mc_copy(
                endpoint=args.endpoint,
                access_key=access_key,
                secret_key=secret_key,
                bucket=args.bucket,
                object_key=manifest_object_key,
                source_file=manifest_local_path,
                make_bucket=False,
            )
        except RuntimeError as exc:
            return out({"ok": False, "error": {"code": str(exc), "message": "install minio client: brew install minio/stable/mc"}}, 2)
        except subprocess.CalledProcessError as exc:
            detail = (exc.stderr or exc.stdout or "").strip()
            return out(
                {
                    "ok": False,
                    "error": {
                        "code": "MINIO_SEGMENT_MANIFEST_UPLOAD_FAILED",
                        "message": detail or "mc cp failed",
                        "manifest_local": str(manifest_local_path),
                    },
                },
                3,
            )
        except Exception as exc:
            return out(
                {
                    "ok": False,
                    "error": {
                        "code": "MINIO_SEGMENT_MANIFEST_UPLOAD_FAILED",
                        "message": str(exc),
                        "manifest_local": str(manifest_local_path),
                    },
                },
                3,
            )

    return out(
        {
            "ok": True,
            "file": str(file_path),
            "bucket": args.bucket,
            "part_size_mib": part_size_mib,
            "part_count": len(parts),
            "uploaded_bytes": uploaded_bytes,
            "object_prefix": prefix,
            "manifest_local": str(manifest_local_path),
            "manifest_object_key": manifest_object_key,
            "manifest_url": manifest_url,
        }
    )


def cmd_package_download_minio_segmented(args: argparse.Namespace) -> int:
    access_key = read_secret_arg_or_env(args.access_key, "COURSE_PIPELINE_MINIO_ACCESS_KEY")
    secret_key = read_secret_arg_or_env(args.secret_key, "COURSE_PIPELINE_MINIO_SECRET_KEY")
    if not access_key or not secret_key:
        return out(
            {
                "ok": False,
                "error": {
                    "code": "MINIO_CREDENTIALS_REQUIRED",
                    "message": "provide --access-key/--secret-key or env COURSE_PIPELINE_MINIO_ACCESS_KEY/COURSE_PIPELINE_MINIO_SECRET_KEY",
                },
            },
            2,
        )

    manifest_local_path: Path
    if args.manifest_file:
        manifest_local_path = Path(args.manifest_file).expanduser().resolve()
        if not manifest_local_path.exists() or not manifest_local_path.is_file():
            return out({"ok": False, "error": {"code": "FILE_NOT_FOUND", "message": str(manifest_local_path)}}, 2)
    else:
        if not args.manifest_object_key:
            return out(
                {
                    "ok": False,
                    "error": {
                        "code": "MANIFEST_REQUIRED",
                        "message": "provide --manifest-file or --manifest-object-key",
                    },
                },
                2,
            )
        if not args.endpoint or not args.bucket:
            return out(
                {
                    "ok": False,
                    "error": {
                        "code": "ENDPOINT_BUCKET_REQUIRED",
                        "message": "--endpoint and --bucket are required when using --manifest-object-key",
                    },
                },
                2,
            )
        temp_manifest = tempfile.NamedTemporaryFile(prefix="cp-manifest-", suffix=".json", delete=False)
        manifest_local_path = Path(temp_manifest.name)
        temp_manifest.close()
        try:
            run_mc_download(
                endpoint=args.endpoint,
                access_key=access_key,
                secret_key=secret_key,
                bucket=args.bucket,
                object_key=args.manifest_object_key,
                target_file=manifest_local_path,
            )
        except RuntimeError as exc:
            manifest_local_path.unlink(missing_ok=True)
            return out({"ok": False, "error": {"code": str(exc), "message": "install minio client: brew install minio/stable/mc"}}, 2)
        except subprocess.CalledProcessError as exc:
            manifest_local_path.unlink(missing_ok=True)
            detail = (exc.stderr or exc.stdout or "").strip()
            return out(
                {
                    "ok": False,
                    "error": {
                        "code": "MINIO_SEGMENT_MANIFEST_DOWNLOAD_FAILED",
                        "message": detail or "mc cp failed",
                    },
                },
                3,
            )
        except Exception as exc:
            manifest_local_path.unlink(missing_ok=True)
            return out(
                {
                    "ok": False,
                    "error": {
                        "code": "MINIO_SEGMENT_MANIFEST_DOWNLOAD_FAILED",
                        "message": str(exc),
                    },
                },
                3,
            )

    try:
        manifest = json.loads(manifest_local_path.read_text(encoding="utf-8"))
    except Exception as exc:
        return out({"ok": False, "error": {"code": "INVALID_MANIFEST_JSON", "message": str(exc)}}, 2)

    endpoint = str(manifest.get("endpoint") or args.endpoint or "").rstrip("/")
    bucket = str(manifest.get("bucket") or args.bucket or "").strip()
    if not endpoint or not bucket:
        return out(
            {
                "ok": False,
                "error": {
                    "code": "INVALID_MANIFEST_ENDPOINT_BUCKET",
                    "message": "manifest missing endpoint/bucket and no fallback args provided",
                },
            },
            2,
        )

    parts_raw = manifest.get("parts")
    if not isinstance(parts_raw, list) or not parts_raw:
        return out({"ok": False, "error": {"code": "INVALID_MANIFEST_PARTS", "message": "manifest.parts is required"}}, 2)
    try:
        parts = normalize_segment_manifest_parts(parts_raw)
    except ValueError as exc:
        return out({"ok": False, "error": {"code": str(exc), "message": "invalid parts index/object_key"}}, 2)

    out_path = Path(args.out).expanduser().resolve() if args.out else (Path.cwd() / str(manifest.get("source_name") or "restored.package"))
    out_path.parent.mkdir(parents=True, exist_ok=True)

    digest = hashlib.sha256()
    bytes_written = 0
    downloaded_parts = 0
    try:
        with out_path.open("wb") as merged:
            for part in parts:
                object_key = str(part["object_key"])
                temp_part = tempfile.NamedTemporaryFile(prefix="cp-seg-dl-", suffix=".part", delete=False)
                temp_part_path = Path(temp_part.name)
                temp_part.close()
                try:
                    run_mc_download(
                        endpoint=endpoint,
                        access_key=access_key,
                        secret_key=secret_key,
                        bucket=bucket,
                        object_key=object_key,
                        target_file=temp_part_path,
                    )
                    data = temp_part_path.read_bytes()
                finally:
                    temp_part_path.unlink(missing_ok=True)
                merged.write(data)
                digest.update(data)
                bytes_written += len(data)
                downloaded_parts += 1
    except RuntimeError as exc:
        out_path.unlink(missing_ok=True)
        return out({"ok": False, "error": {"code": str(exc), "message": "install minio client: brew install minio/stable/mc"}}, 2)
    except subprocess.CalledProcessError as exc:
        out_path.unlink(missing_ok=True)
        detail = (exc.stderr or exc.stdout or "").strip()
        return out(
            {
                "ok": False,
                "error": {
                    "code": "MINIO_SEGMENT_DOWNLOAD_FAILED",
                    "message": detail or "mc cp failed",
                    "downloaded_parts": downloaded_parts,
                    "downloaded_bytes": bytes_written,
                },
            },
            3,
        )
    except Exception as exc:
        out_path.unlink(missing_ok=True)
        return out(
            {
                "ok": False,
                "error": {
                    "code": "MINIO_SEGMENT_DOWNLOAD_FAILED",
                    "message": str(exc),
                    "downloaded_parts": downloaded_parts,
                    "downloaded_bytes": bytes_written,
                },
            },
            3,
        )

    expected_size = int(manifest.get("source_size_bytes") or 0)
    expected_sha = str(manifest.get("source_sha256") or "").strip().lower()
    actual_sha = digest.hexdigest().lower()
    if expected_size and expected_size != bytes_written:
        out_path.unlink(missing_ok=True)
        return out(
            {
                "ok": False,
                "error": {
                    "code": "RESTORE_SIZE_MISMATCH",
                    "message": f"expected {expected_size}, got {bytes_written}",
                },
            },
            4,
        )
    if expected_sha and expected_sha != actual_sha:
        out_path.unlink(missing_ok=True)
        return out(
            {
                "ok": False,
                "error": {
                    "code": "RESTORE_SHA256_MISMATCH",
                    "message": f"expected {expected_sha}, got {actual_sha}",
                },
            },
            4,
        )

    return out(
        {
            "ok": True,
            "manifest_file": str(manifest_local_path),
            "restored_file": str(out_path),
            "size_bytes": bytes_written,
            "sha256": actual_sha,
            "part_count": len(parts),
        }
    )


def cmd_package_publish_minio_auto(args: argparse.Namespace) -> int:
    file_path = Path(args.file_path).expanduser().resolve()
    if not file_path.exists() or not file_path.is_file():
        return out({"ok": False, "error": {"code": "FILE_NOT_FOUND", "message": str(file_path)}}, 2)

    access_key = read_secret_arg_or_env(args.access_key, "COURSE_PIPELINE_MINIO_ACCESS_KEY")
    secret_key = read_secret_arg_or_env(args.secret_key, "COURSE_PIPELINE_MINIO_SECRET_KEY")
    if not access_key or not secret_key:
        return out(
            {
                "ok": False,
                "error": {
                    "code": "MINIO_CREDENTIALS_REQUIRED",
                    "message": "provide --access-key/--secret-key or env COURSE_PIPELINE_MINIO_ACCESS_KEY/COURSE_PIPELINE_MINIO_SECRET_KEY",
                },
            },
            2,
        )

    digest, size_bytes = sha256_and_size(file_path)
    threshold_mib = max(1, int(args.threshold_mib))
    threshold_bytes = threshold_mib * 1024 * 1024
    mode = "zip" if size_bytes <= threshold_bytes else "segmented_zip"

    endpoint = args.endpoint.rstrip("/")
    bucket = args.bucket.strip()
    course_id = args.course_id.strip()
    if not bucket or not course_id:
        return out({"ok": False, "error": {"code": "INVALID_ARGUMENT", "message": "--bucket and --course-id are required"}}, 2)

    version_name = args.version_name
    object_prefix = normalize_object_prefix(
        args.object_prefix,
        build_default_publish_object_prefix(course_id, version_name, file_path.name),
    )
    zip_url = ""
    manifest_url = ""
    upload_meta: dict = {}

    try:
        if mode == "zip":
            object_key = args.object_key.strip() or f"{object_prefix}"
            zip_url, _ = run_mc_copy(
                endpoint=endpoint,
                access_key=access_key,
                secret_key=secret_key,
                bucket=bucket,
                object_key=object_key,
                source_file=file_path,
                make_bucket=args.make_bucket,
            )
            upload_meta = {
                "mode": mode,
                "object_key": object_key,
                "url": zip_url,
            }
        else:
            part_size_mib = max(1, int(args.part_size_mib))
            part_size_bytes = part_size_mib * 1024 * 1024
            total_parts = (size_bytes + part_size_bytes - 1) // part_size_bytes
            parts: list[dict] = []

            with file_path.open("rb") as src:
                for index in range(1, total_parts + 1):
                    chunk = src.read(part_size_bytes)
                    if not chunk:
                        break
                    part_key = segmented_part_object_key(object_prefix, index, total_parts)
                    tmp = tempfile.NamedTemporaryFile(prefix="cp-seg-", suffix=".part", delete=False)
                    tmp_path = Path(tmp.name)
                    try:
                        with tmp:
                            tmp.write(chunk)
                        part_url, _ = run_mc_copy(
                            endpoint=endpoint,
                            access_key=access_key,
                            secret_key=secret_key,
                            bucket=bucket,
                            object_key=part_key,
                            source_file=tmp_path,
                            make_bucket=args.make_bucket and index == 1,
                        )
                    finally:
                        tmp_path.unlink(missing_ok=True)

                    parts.append(
                        {
                            "index": index,
                            "object_key": part_key,
                            "size_bytes": len(chunk),
                            "sha256": hashlib.sha256(chunk).hexdigest(),
                            "url": part_url,
                        }
                    )

            manifest_payload = {
                "schema_version": 1,
                "created_at": now_iso(),
                "bucket": bucket,
                "endpoint": endpoint,
                "source_file": str(file_path),
                "source_name": file_path.name,
                "source_size_bytes": size_bytes,
                "source_sha256": digest,
                "part_size_bytes": part_size_bytes,
                "part_count": len(parts),
                "object_prefix": object_prefix,
                "parts": parts,
            }
            manifest_local = Path(args.manifest_out).expanduser().resolve() if args.manifest_out else file_path.with_suffix(file_path.suffix + ".parts.json")
            manifest_local.parent.mkdir(parents=True, exist_ok=True)
            manifest_local.write_text(json.dumps(manifest_payload, ensure_ascii=False, indent=2), encoding="utf-8")

            manifest_key = args.manifest_object_key.strip() or f"{object_prefix}.manifest.json"
            manifest_url, _ = run_mc_copy(
                endpoint=endpoint,
                access_key=access_key,
                secret_key=secret_key,
                bucket=bucket,
                object_key=manifest_key,
                source_file=manifest_local,
                make_bucket=False,
            )
            upload_meta = {
                "mode": mode,
                "part_count": len(parts),
                "manifest_local": str(manifest_local),
                "manifest_object_key": manifest_key,
                "manifest_url": manifest_url,
            }
    except RuntimeError as exc:
        return out({"ok": False, "error": {"code": str(exc), "message": "install minio client: brew install minio/stable/mc"}}, 2)
    except subprocess.CalledProcessError as exc:
        detail = (exc.stderr or exc.stdout or "").strip()
        return out({"ok": False, "error": {"code": "MINIO_PUBLISH_FAILED", "message": detail or "mc cp failed"}}, 3)
    except Exception as exc:
        return out({"ok": False, "error": {"code": "MINIO_PUBLISH_FAILED", "message": str(exc)}}, 3)

    asset = (
        {
            "mode": "zip",
            "url": zip_url,
            "size_bytes": size_bytes,
            "sha256": digest,
        }
        if mode == "zip"
        else {
            "mode": "segmented_zip",
            "manifest_url": manifest_url,
            "size_bytes": size_bytes,
            "sha256": digest,
        }
    )
    catalog_item = {
        "id": course_id,
        "title": args.title or course_id,
        "tags": [tag.strip() for tag in (args.tags or "").split(",") if tag.strip()],
        "version": version_name,
        "cover": args.cover_url,
        "asset": asset,
    }
    catalog_out = Path(args.catalog_out).expanduser().resolve()
    catalog_out.parent.mkdir(parents=True, exist_ok=True)
    existing_catalog = None
    if catalog_out.exists() and not args.catalog_replace:
        try:
            loaded = json.loads(catalog_out.read_text(encoding="utf-8"))
            if isinstance(loaded, dict):
                existing_catalog = loaded
        except Exception:
            existing_catalog = None
    catalog_payload = (
        {"version": int(args.catalog_version), "courses": [catalog_item]}
        if args.catalog_replace
        else merge_catalog_courses(existing_catalog, catalog_item, int(args.catalog_version))
    )
    catalog_out.write_text(json.dumps(catalog_payload, ensure_ascii=False, indent=2), encoding="utf-8")

    task_id = (args.task_id or "").strip() or infer_task_id_from_path(file_path)
    task_output_file = ""
    if task_id:
        runtime_tasks = project_runtime_dir(Path(args.project_root).expanduser().resolve())
        task_dir = runtime_tasks / task_id
        if task_dir.exists():
            task_output_file = str(task_dir / "output_publish.json")
            payload = {
                "task_id": task_id,
                "step": "publish",
                "generated_at": now_iso(),
                "payload": {
                    "file": str(file_path),
                    "sha256": digest,
                    "size_bytes": size_bytes,
                    "threshold_mib": threshold_mib,
                    "selected_mode": mode,
                    "upload": upload_meta,
                    "catalog": str(catalog_out),
                    "course": catalog_item,
                },
            }
            (task_dir / "output_publish.json").write_text(
                json.dumps(payload, ensure_ascii=False, indent=2),
                encoding="utf-8",
            )
            task_json_file = runtime_tasks / f"{task_id}.json"
            if task_json_file.exists():
                try:
                    task_payload = json.loads(task_json_file.read_text(encoding="utf-8"))
                    if isinstance(task_payload, dict):
                        task_payload["publish"] = {
                            "published_at": now_iso(),
                            "mode": mode,
                            "catalog": str(catalog_out),
                            "asset": catalog_item.get("asset", {}),
                        }
                        task_payload["updated_at"] = now_iso()
                        task_json_file.write_text(
                            json.dumps(task_payload, ensure_ascii=False, indent=2),
                            encoding="utf-8",
                        )
                except Exception:
                    pass

    return out(
        {
            "ok": True,
            "file": str(file_path),
            "sha256": digest,
            "size_bytes": size_bytes,
            "threshold_mib": threshold_mib,
            "selected_mode": mode,
            "upload": upload_meta,
            "catalog": str(catalog_out),
            "course": catalog_item,
            "task_id": task_id,
            "task_output_file": task_output_file,
        }
    )


def cmd_package_republish_runtime(args: argparse.Namespace) -> int:
    project_root = Path(args.project_root).expanduser().resolve()
    runtime_dir = project_runtime_dir(project_root)

    access_key = read_secret_arg_or_env(args.access_key, "COURSE_PIPELINE_MINIO_ACCESS_KEY")
    secret_key = read_secret_arg_or_env(args.secret_key, "COURSE_PIPELINE_MINIO_SECRET_KEY")
    if not access_key or not secret_key:
        return out(
            {
                "ok": False,
                "error": {
                    "code": "MINIO_CREDENTIALS_REQUIRED",
                    "message": "provide --access-key/--secret-key or env COURSE_PIPELINE_MINIO_ACCESS_KEY/COURSE_PIPELINE_MINIO_SECRET_KEY",
                },
            },
            2,
        )

    endpoint = args.endpoint.rstrip("/")
    bucket = args.bucket.strip()
    if not endpoint or not bucket:
        return out({"ok": False, "error": {"code": "INVALID_ARGUMENT", "message": "--endpoint and --bucket are required"}}, 2)

    latest_by_course: dict[str, dict] = {}
    for task_file_path in sorted(runtime_dir.glob("task_*.json")):
        try:
            task = json.loads(task_file_path.read_text(encoding="utf-8"))
        except Exception:
            continue
        if not isinstance(task, dict):
            continue

        task_id = str(task.get("task_id", "")).strip()
        course_id = str(task.get("course_id", "")).strip()
        if not task_id or not course_id:
            continue
        if args.only_course_id and course_id != args.only_course_id:
            continue

        steps = task.get("steps")
        if not isinstance(steps, dict) or str(steps.get("package", "")).strip() != "done":
            continue

        task_dir = runtime_dir / task_id
        if not task_dir.exists():
            continue
        zip_file = choose_task_zip_file(task_dir, course_id, pack_if_missing=(not args.no_pack_if_missing))
        if zip_file is None:
            continue

        title, version_name = choose_title_version_from_task(task_dir, course_id)
        updated_at = _parse_iso_or_epoch(str(task.get("updated_at") or ""))
        existing = latest_by_course.get(course_id)
        if existing is None or updated_at >= existing["updated_at"]:
            latest_by_course[course_id] = {
                "task_id": task_id,
                "course_id": course_id,
                "file_path": zip_file,
                "title": title,
                "version_name": version_name,
                "updated_at": updated_at,
            }

    candidates = sorted(latest_by_course.values(), key=lambda item: item["course_id"])
    if not candidates:
        return out(
            {
                "ok": False,
                "error": {
                    "code": "NO_PUBLISHABLE_TASKS",
                    "message": "no .runtime tasks with steps.package=done and usable zip file",
                },
            },
            1,
        )

    catalog_out = Path(args.catalog_out).expanduser().resolve()
    if catalog_out.exists():
        catalog_out.unlink(missing_ok=True)
    catalog_out.parent.mkdir(parents=True, exist_ok=True)

    results = []
    failures = []
    for idx, row in enumerate(candidates):
        task_id = row["task_id"]
        course_id = row["course_id"]
        file_path = row["file_path"]
        title = row["title"]
        version_name = row["version_name"]

        if not args.skip_delete:
            try:
                run_mc_rm_prefix(
                    endpoint=endpoint,
                    access_key=access_key,
                    secret_key=secret_key,
                    bucket=bucket,
                    object_prefix=course_id,
                )
            except RuntimeError as exc:
                failures.append({"task_id": task_id, "course_id": course_id, "code": str(exc), "message": "minio client is required"})
                continue
            except subprocess.CalledProcessError as exc:
                detail = (exc.stderr or exc.stdout or "").strip()
                failures.append({"task_id": task_id, "course_id": course_id, "code": "MINIO_DELETE_FAILED", "message": detail or "mc rm failed"})
                continue

        publish_args = argparse.Namespace(
            project_root=str(project_root),
            file_path=str(file_path),
            endpoint=endpoint,
            bucket=bucket,
            course_id=course_id,
            title=title,
            tags=args.tags,
            cover_url=args.cover_url,
            version_name=version_name,
            catalog_version=args.catalog_version,
            catalog_replace=(idx == 0),
            catalog_out=str(catalog_out),
            task_id=task_id,
            threshold_mib=args.threshold_mib,
            part_size_mib=args.part_size_mib,
            object_prefix=f"{course_id}/{version_name}/{file_path.name}",
            object_key="",
            manifest_object_key="",
            manifest_out="",
            access_key=access_key,
            secret_key=secret_key,
            make_bucket=args.make_bucket,
        )
        code = cmd_package_publish_minio_auto(publish_args)
        if code != 0:
            failures.append(
                {
                    "task_id": task_id,
                    "course_id": course_id,
                    "code": "PUBLISH_FAILED",
                    "message": f"publish command exited {code}",
                }
            )
            continue
        results.append(
            {
                "task_id": task_id,
                "course_id": course_id,
                "file": str(file_path),
                "version": version_name,
            }
        )

    status_code = 0 if not failures else 3
    return out(
        {
            "ok": len(results) > 0 and not failures,
            "republish_count": len(results),
            "failure_count": len(failures),
            "catalog": str(catalog_out),
            "results": results,
            "failures": failures,
        },
        status_code,
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Local course pipeline operations")
    parser.add_argument("--project-root", default=str(Path(__file__).resolve().parents[2]))

    root = parser.add_subparsers(dest="entity", required=True)

    course = root.add_parser("course")
    course_actions = course.add_subparsers(dest="action", required=True)

    course_add = course_actions.add_parser("add")
    course_add.add_argument("folder_path")
    course_add.add_argument(
        "--no-auto-start",
        action="store_false",
        dest="auto_start",
        help="Create task only; do not auto-run non-HITL steps.",
    )
    course_add.add_argument(
        "--reading-light-mode",
        action="store_true",
        help="Enable lightweight reading mode for this task (package can skip grammar/summary gate).",
    )
    course_add.set_defaults(auto_start=True)
    course_add.set_defaults(func=cmd_course_add)

    course_delete = course_actions.add_parser("delete")
    course_delete.add_argument("course_id")
    course_delete.set_defaults(func=cmd_course_delete)

    task = root.add_parser("task")
    task_actions = task.add_subparsers(dest="action", required=True)

    task_get = task_actions.add_parser("get")
    task_get.add_argument("task_id")
    task_get.set_defaults(func=cmd_task_get)

    task_list = task_actions.add_parser("list")
    task_list.add_argument("--status", choices=sorted(STATUSES))
    task_list.add_argument("--brief", action="store_true")
    task_list.set_defaults(func=cmd_task_list)

    for action_name, func in [
        ("pause", cmd_task_pause),
        ("resume", cmd_task_resume),
        ("stop", cmd_task_stop),
        ("delete", cmd_task_delete),
    ]:
        action = task_actions.add_parser(action_name)
        action.add_argument("task_id")
        action.set_defaults(func=func)

    task_retry = task_actions.add_parser("retry")
    task_retry.add_argument("task_id")
    task_retry.add_argument("--from-step", choices=STEP_ORDER)
    task_retry.set_defaults(func=cmd_task_retry)

    task_run_step = task_actions.add_parser("run-step")
    task_run_step.add_argument("task_id")
    task_run_step.add_argument("step", choices=STEP_ORDER)
    task_run_step.add_argument(
        "--no-auto-chain",
        action="store_false",
        dest="auto_chain",
        help="Run only the specified step; do not auto-run following non-HITL steps.",
    )
    task_run_step.add_argument(
        "--reading-light-mode",
        action="store_true",
        help="Enable lightweight reading mode on the task before running this step.",
    )
    task_run_step.set_defaults(auto_chain=True)
    task_run_step.set_defaults(func=cmd_task_run_step)

    task_run_auto = task_actions.add_parser("run-auto")
    task_run_auto.add_argument("task_id")
    task_run_auto.set_defaults(func=cmd_task_run_auto)

    task_watch = task_actions.add_parser("watch")
    task_watch.add_argument("task_id")
    task_watch.add_argument("--interval", type=int, default=2)
    task_watch.add_argument("--timeout", type=int, default=0)
    task_watch.set_defaults(func=cmd_task_watch)

    package = root.add_parser("package")
    package_actions = package.add_subparsers(dest="action", required=True)

    package_inspect = package_actions.add_parser("inspect")
    package_inspect.add_argument("file_path")
    package_inspect.set_defaults(func=cmd_package_inspect)

    package_catalog = package_actions.add_parser("build-catalog")
    package_catalog.add_argument("file_path")
    package_catalog.add_argument("--mode", default="auto", choices=["auto", "zip", "segmented_zip"])
    package_catalog.add_argument("--threshold-mib", type=int, default=512)
    package_catalog.add_argument("--zip-url", default="")
    package_catalog.add_argument("--manifest-url", default="")
    package_catalog.add_argument("--course-id", required=True)
    package_catalog.add_argument("--title")
    package_catalog.add_argument("--tags", default="全部,视频,入门")
    package_catalog.add_argument("--cover-url", default="")
    package_catalog.add_argument("--version-name", default="1.0.0")
    package_catalog.add_argument("--catalog-version", default=1)
    package_catalog.add_argument("--catalog-replace", action="store_true", help="Replace output catalog instead of merging by course id.")
    package_catalog.add_argument("--out", default="catalog.json")
    package_catalog.set_defaults(func=cmd_package_build_catalog)

    package_upload = package_actions.add_parser("upload-minio")
    package_upload.add_argument("file_path")
    package_upload.add_argument("--endpoint", required=True, help="e.g. http://home.rongts.tech")
    package_upload.add_argument("--bucket", required=True)
    package_upload.add_argument("--object-key", default="")
    package_upload.add_argument("--access-key", default="")
    package_upload.add_argument("--secret-key", default="")
    package_upload.add_argument("--make-bucket", action="store_true")
    package_upload.set_defaults(func=cmd_package_upload_minio)

    package_upload_segmented = package_actions.add_parser("upload-minio-segmented")
    package_upload_segmented.add_argument("file_path")
    package_upload_segmented.add_argument("--endpoint", required=True, help="e.g. http://home.rongts.tech")
    package_upload_segmented.add_argument("--bucket", required=True)
    package_upload_segmented.add_argument("--object-prefix", default="")
    package_upload_segmented.add_argument("--part-size-mib", type=int, default=256)
    package_upload_segmented.add_argument("--manifest-out", default="")
    package_upload_segmented.add_argument("--manifest-object-key", default="")
    package_upload_segmented.add_argument("--skip-upload-manifest", action="store_true")
    package_upload_segmented.add_argument("--access-key", default="")
    package_upload_segmented.add_argument("--secret-key", default="")
    package_upload_segmented.add_argument("--make-bucket", action="store_true")
    package_upload_segmented.set_defaults(func=cmd_package_upload_minio_segmented)

    package_download_segmented = package_actions.add_parser("download-minio-segmented")
    package_download_segmented.add_argument("--manifest-file", default="")
    package_download_segmented.add_argument("--manifest-object-key", default="")
    package_download_segmented.add_argument("--endpoint", default="", help="required with --manifest-object-key unless included in manifest")
    package_download_segmented.add_argument("--bucket", default="", help="required with --manifest-object-key unless included in manifest")
    package_download_segmented.add_argument("--out", default="")
    package_download_segmented.add_argument("--access-key", default="")
    package_download_segmented.add_argument("--secret-key", default="")
    package_download_segmented.set_defaults(func=cmd_package_download_minio_segmented)

    package_publish_auto = package_actions.add_parser("publish-minio-auto")
    package_publish_auto.add_argument("file_path")
    package_publish_auto.add_argument("--endpoint", required=True, help="e.g. http://home.rongts.tech")
    package_publish_auto.add_argument("--bucket", required=True)
    package_publish_auto.add_argument("--course-id", required=True)
    package_publish_auto.add_argument("--title")
    package_publish_auto.add_argument("--tags", default="全部,视频,入门")
    package_publish_auto.add_argument("--cover-url", default="")
    package_publish_auto.add_argument("--version-name", default="1.0.0")
    package_publish_auto.add_argument("--catalog-version", default=1)
    package_publish_auto.add_argument("--catalog-replace", action="store_true", help="Replace catalog-out content instead of merging by course id.")
    package_publish_auto.add_argument("--catalog-out", default="catalog.json")
    package_publish_auto.add_argument("--task-id", default="")
    package_publish_auto.add_argument("--threshold-mib", type=int, default=512)
    package_publish_auto.add_argument("--part-size-mib", type=int, default=256)
    package_publish_auto.add_argument("--object-prefix", default="")
    package_publish_auto.add_argument("--object-key", default="")
    package_publish_auto.add_argument("--manifest-object-key", default="")
    package_publish_auto.add_argument("--manifest-out", default="")
    package_publish_auto.add_argument("--access-key", default="")
    package_publish_auto.add_argument("--secret-key", default="")
    package_publish_auto.add_argument("--make-bucket", action="store_true")
    package_publish_auto.set_defaults(func=cmd_package_publish_minio_auto)

    package_republish_runtime = package_actions.add_parser("republish-runtime")
    package_republish_runtime.add_argument("--endpoint", required=True, help="e.g. http://home.rongts.tech")
    package_republish_runtime.add_argument("--bucket", required=True)
    package_republish_runtime.add_argument("--catalog-out", default="catalog.json")
    package_republish_runtime.add_argument("--catalog-version", default=1)
    package_republish_runtime.add_argument("--threshold-mib", type=int, default=512)
    package_republish_runtime.add_argument("--part-size-mib", type=int, default=256)
    package_republish_runtime.add_argument("--tags", default="全部,视频,入门")
    package_republish_runtime.add_argument("--cover-url", default="")
    package_republish_runtime.add_argument("--only-course-id", default="")
    package_republish_runtime.add_argument("--no-pack-if-missing", action="store_true", help="Do not auto-create zip from task package/ when zip is missing.")
    package_republish_runtime.add_argument("--skip-delete", action="store_true", help="Skip deleting remote <course_id>/ prefix before upload.")
    package_republish_runtime.add_argument("--access-key", default="")
    package_republish_runtime.add_argument("--secret-key", default="")
    package_republish_runtime.add_argument("--make-bucket", action="store_true")
    package_republish_runtime.set_defaults(func=cmd_package_republish_runtime)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
