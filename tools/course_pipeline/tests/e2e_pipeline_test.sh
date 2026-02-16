#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SCRIPT="$ROOT/tools/course_pipeline/course_pipeline_ops.py"
TMPDIR="$(mktemp -d)"
RAW="$TMPDIR/raw"
mkdir -p "$RAW"

ffmpeg -y -f lavfi -i "sine=frequency=440:duration=1" "$RAW/01_intro.mp3" >/dev/null 2>&1
cat > "$RAW/01.en.srt" <<'SRT'
1
00:00:00,000 --> 00:00:01,000
Hello and welcome.
SRT

ADD_OUT="$(python3 "$SCRIPT" course add "$RAW")"
TASK_ID="$(echo "$ADD_OUT" | python3 -c 'import json,sys; print(json.load(sys.stdin)["task"]["task_id"])')"

for STEP in ffmpeg asr align translate grammar summary package; do
  python3 "$SCRIPT" task run-step "$TASK_ID" "$STEP" >/dev/null
done

TASK_JSON="$(python3 "$SCRIPT" task get "$TASK_ID")"
STATUS="$(echo "$TASK_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["task"]["status"])')"
if [[ "$STATUS" != "ready" ]]; then
  echo "expected ready, got $STATUS"
  exit 1
fi

PKG="$ROOT/runtime/tasks/$TASK_ID/package"
[[ -f "$PKG/course_manifest.json" ]]
[[ -f "$PKG/lessons/01/lesson.json" ]]
[[ -f "$PKG/lessons/01/sub_en.srt" ]]
[[ -f "$PKG/lessons/01/sub_zh.srt" ]]

echo "e2e ok: $TASK_ID"
rm -rf "$TMPDIR"
