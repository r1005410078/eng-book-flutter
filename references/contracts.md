# Contracts

## Ownership
- Project requirements (OpenSpec): `/Users/rongts/eng-book-flutter/openspec`
- Skill orchestration: `~/.codex/skills/course-pipeline-ops`
- Runtime tasks: `/Users/rongts/eng-book-flutter/runtime/tasks`
- Single script source: `/Users/rongts/eng-book-flutter/tools/course_pipeline/course_pipeline_ops.py`

## Status Enum
- `uploaded`
- `processing`
- `paused`
- `ready`
- `failed`
- `stopped`

## Step Enum
- `ffmpeg`
- `asr`
- `align`
- `translate`
- `grammar`
- `summary`
- `package`

## HITL Steps
- `translate`
- `grammar`
- `summary`

## Task Shape (minimum)
```json
{
  "task_id": "task_abc12345",
  "course_id": "course_daily_english",
  "course_path": "/path/to/raw",
  "status": "processing",
  "current_step": "translate",
  "steps": {
    "ffmpeg": "done",
    "asr": "done",
    "align": "done",
    "translate": "running",
    "grammar": "pending",
    "summary": "pending",
    "package": "pending"
  },
  "error": null,
  "created_at": "2026-02-16T12:00:00Z",
  "updated_at": "2026-02-16T12:05:00Z"
}
```
