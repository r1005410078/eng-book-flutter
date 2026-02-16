#!/usr/bin/env python3
import argparse
import json
import re
import subprocess
import sys
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path
from shutil import which

STATUSES = {"uploaded", "processing", "paused", "ready", "failed", "stopped"}
STEP_ORDER = ["ffmpeg", "asr", "align", "translate", "grammar", "summary", "package"]
STEP_STATES = {"pending", "running", "done", "failed"}
HITL_STEPS = {"translate", "grammar", "summary"}
TERMINAL_STATUSES = {"ready", "failed", "stopped"}
MEDIA_PATTERN = re.compile(r"^(\d{2})_.*\.(mp4|mp3)$", re.IGNORECASE)


def now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def out(payload: dict, code: int = 0) -> int:
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return code


def project_runtime_dir(project_root: Path) -> Path:
    d = project_root / "runtime" / "tasks"
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
        normalized_media = lesson_dir / f"media.{ext}"
        normalized_media.write_bytes(media.read_bytes())

        wav_path = lesson_dir / "audio_16k.wav"
        cmd = [
            "ffmpeg",
            "-y",
            "-i",
            str(media),
            "-ac",
            "1",
            "-ar",
            "16000",
            str(wav_path),
        ]
        subprocess.run(cmd, check=True, capture_output=True, text=True)
        duration_ms = ffprobe_duration_ms(media)
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
        if provided_en.exists():
            out_en.write_text(provided_en.read_text(encoding="utf-8"), encoding="utf-8")
            source = "provided"
        else:
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
            source = "placeholder"
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

    for key in task.get("lesson_keys", []):
        lesson_dir = output_root / key
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

        override_file = work_dir / f"{key}_translate_output.json"
        if override_file.exists():
            result = json.loads(override_file.read_text(encoding="utf-8"))
            out_items = result.get("sentences", input_items)
            source = "hitl_override"
        else:
            out_items = []
            for item in input_items:
                out_items.append(
                    {
                        **item,
                        "zh": item["zh"] if item["zh"] else f"[ZH pending] {item['en']}",
                    }
                )
            source = "fallback"

        output_file = work_dir / f"{key}_translate_effective.json"
        output_file.write_text(
            json.dumps({"lesson_id": key, "sentences": out_items, "source": source}, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        lessons.append({"lesson_id": key, "input_file": str(input_file), "output_file": str(output_file), "source": source})

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
                out_sentences.append(
                    {
                        "sentence_id": s["sentence_id"],
                        "grammar": {"pattern": "[pending]", "points": ["[pending]"]},
                        "usage": {"scene": "[pending]", "tone": "neutral", "formality": "informal"},
                    }
                )
            source = "fallback"

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
            summary_data = {
                "lesson_id": key,
                "summary": "[pending] human summary",
                "grammar_highlights": ["[pending]"],
            }
            source = "fallback"

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
                        "translation_ready": True,
                        "ipa_ready": bool(s.get("ipa")),
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
        "title": task["course_id"],
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
        "course_path": str(raw_folder),
        "status": "uploaded",
        "current_step": "ffmpeg",
        "steps": {s: "pending" for s in STEP_ORDER},
        "lesson_keys": lesson_keys,
        "error": None,
        "created_at": now_iso(),
        "updated_at": now_iso(),
    }
    save_task(runtime_dir, task)
    append_event(runtime_dir, task_id, "course.add", {"course_path": str(raw_folder), "lessons": lesson_keys})
    return out({"ok": True, "task": task})


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


def cmd_task_run_step(args: argparse.Namespace) -> int:
    runtime_dir = project_runtime_dir(Path(args.project_root).expanduser().resolve())
    step = args.step
    if step not in STEP_ORDER:
        return out({"ok": False, "error": {"code": "INVALID_STEP", "message": step}}, 2)

    try:
        task = load_task(runtime_dir, args.task_id)
    except FileNotFoundError:
        return out({"ok": False, "error": {"code": "TASK_NOT_FOUND", "message": args.task_id}}, 2)

    running_steps = [s for s, state in task["steps"].items() if state == "running"]
    if running_steps:
        return out(
            {
                "ok": False,
                "error": {
                    "code": "STEP_FAILED",
                    "message": f"another step is running: {running_steps[0]}",
                    "step": running_steps[0],
                },
            },
            3,
        )

    step_index = STEP_ORDER.index(step)
    for prev in STEP_ORDER[:step_index]:
        if task["steps"][prev] != "done":
            return out(
                {
                    "ok": False,
                    "error": {
                        "code": "STEP_FAILED",
                        "message": f"step '{step}' requires '{prev}' done first",
                        "step": step,
                    },
                },
                3,
            )

    task["status"] = "processing"
    task["current_step"] = step
    task["steps"][step] = "running"
    save_task(runtime_dir, task)
    append_event(runtime_dir, args.task_id, "task.run_step.start", {"step": step, "hitl": step in HITL_STEPS})

    out_dir = runtime_dir / args.task_id
    out_dir.mkdir(parents=True, exist_ok=True)

    try:
        step_payload = execute_step(step, task, runtime_dir)
        output = {
            "task_id": args.task_id,
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
        append_event(runtime_dir, args.task_id, "task.run_step.failed", {"step": step, "error": task["error"]})
        return out({"ok": False, "task": task, "error": task["error"]}, 3)

    next_step = None
    for s in STEP_ORDER:
        if task["steps"][s] != "done":
            next_step = s
            break
    if next_step:
        task["current_step"] = next_step
    else:
        task["current_step"] = "package"
        task["status"] = "ready"

    save_task(runtime_dir, task)
    append_event(runtime_dir, args.task_id, "task.run_step.done", {"step": step, "output_file": str(out_file)})
    return out({"ok": True, "task": task, "output_file": str(out_file)})


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


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Local course pipeline operations")
    parser.add_argument("--project-root", default=str(Path(__file__).resolve().parents[2]))

    root = parser.add_subparsers(dest="entity", required=True)

    course = root.add_parser("course")
    course_actions = course.add_subparsers(dest="action", required=True)

    course_add = course_actions.add_parser("add")
    course_add.add_argument("folder_path")
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
    task_run_step.set_defaults(func=cmd_task_run_step)

    task_watch = task_actions.add_parser("watch")
    task_watch.add_argument("task_id")
    task_watch.add_argument("--interval", type=int, default=2)
    task_watch.add_argument("--timeout", type=int, default=0)
    task_watch.set_defaults(func=cmd_task_watch)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
