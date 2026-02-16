# Contracts

## Project Ownership
- Product requirements and OpenSpec live in: `/Users/rongts/.codex/skills/course-pipeline-ops/project/openspec`
- Skill orchestration lives in: `~/.codex/skills/course-pipeline-ops`
- Runtime state lives in project: `/Users/rongts/.codex/skills/course-pipeline-ops/project/runtime/tasks`

## Task Status
- `uploaded`
- `processing`
- `paused`
- `ready`
- `failed`
- `stopped`

## Step Names
- `ffmpeg`
- `asr`
- `align`
- `translate`
- `grammar`
- `summary`
- `package`

## Human-in-the-loop Steps
These steps should be triggered manually by user command:
- `translate`
- `grammar`
- `summary`

## Task JSON Shape (minimum)
```json
{
  "task_id": "task_abc123",
  "course_id": "course_xyz",
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
