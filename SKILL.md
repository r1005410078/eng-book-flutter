---
name: course-pipeline-ops
description: Manage local English course processing tasks for the eng-book-flutter project using Human-in-the-loop operations. Use when creating/deleting course ingestion tasks, checking task progress, pausing/resuming/stopping/retrying tasks, running AI steps manually (translate/grammar/summary), watching for completion, or writing task status/event logs in runtime/tasks.
---

# Course Pipeline Ops

## Overview
Use this skill to operate the local course pipeline task lifecycle for MVP: ingest raw media folders, drive Human-in-the-loop AI steps, and keep stable JSON task state for Flutter/package integration.

## Workflow
1. Set project root (default: `/Users/rongts/.codex/skills/course-pipeline-ops/project`).
2. Create a task from a raw course folder.
3. Run task steps manually for AI stages.
4. Watch task status until `ready` or `failed`.
5. Inspect or update task lifecycle states.

## Commands
Use the script in `scripts/course_pipeline_ops.py`.

```bash
# Course
python3 scripts/course_pipeline_ops.py --project-root /Users/rongts/.codex/skills/course-pipeline-ops/project course add /path/to/raw_folder
python3 scripts/course_pipeline_ops.py --project-root /Users/rongts/.codex/skills/course-pipeline-ops/project course delete <course_id>

# Task query
python3 scripts/course_pipeline_ops.py --project-root /Users/rongts/.codex/skills/course-pipeline-ops/project task get <task_id>
python3 scripts/course_pipeline_ops.py --project-root /Users/rongts/.codex/skills/course-pipeline-ops/project task list --status processing

# Task control
python3 scripts/course_pipeline_ops.py --project-root /Users/rongts/.codex/skills/course-pipeline-ops/project task pause <task_id>
python3 scripts/course_pipeline_ops.py --project-root /Users/rongts/.codex/skills/course-pipeline-ops/project task resume <task_id>
python3 scripts/course_pipeline_ops.py --project-root /Users/rongts/.codex/skills/course-pipeline-ops/project task stop <task_id>
python3 scripts/course_pipeline_ops.py --project-root /Users/rongts/.codex/skills/course-pipeline-ops/project task retry <task_id> --from-step translate
python3 scripts/course_pipeline_ops.py --project-root /Users/rongts/.codex/skills/course-pipeline-ops/project task delete <task_id>

# Human-in-the-loop AI steps
python3 scripts/course_pipeline_ops.py --project-root /Users/rongts/.codex/skills/course-pipeline-ops/project task run-step <task_id> translate
python3 scripts/course_pipeline_ops.py --project-root /Users/rongts/.codex/skills/course-pipeline-ops/project task run-step <task_id> grammar
python3 scripts/course_pipeline_ops.py --project-root /Users/rongts/.codex/skills/course-pipeline-ops/project task run-step <task_id> summary

# Watch and notify
python3 scripts/course_pipeline_ops.py --project-root /Users/rongts/.codex/skills/course-pipeline-ops/project task watch <task_id> --interval 2
```

## Rules
- Keep project requirements in `project/openspec`.
- Treat this skill as orchestration and operational tooling only.
- Write task state to `runtime/tasks/<task_id>.json` and append lifecycle events to `runtime/tasks/events.log`.
- For MVP, AI steps are Human-in-the-loop and must be explicitly triggered by user command.

## References
- Read `references/contracts.md` for task schema, statuses, and step names.
