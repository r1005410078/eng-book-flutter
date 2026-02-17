---
name: course-pipeline-ops
description: Operate the local course pipeline for eng-book-flutter using Human-in-the-loop steps. Use when users ask to add/delete courses, query task progress, pause/resume/stop/retry/delete tasks, run translate/grammar/summary steps, or watch task completion with course-pipeline command.
---

# Course Pipeline Ops

## Overview
Use this skill to run the local course ingestion and packaging flow for English learning materials.

## Command Entry
Prefer global command `course-pipeline`.

Fallback:
```bash
python3 /Users/rongts/eng-book-flutter/tools/course_pipeline/course_pipeline_ops.py <args...>
```

## Open Codex Flow
1. Add course folder:
```bash
course-pipeline course add /path/to/DailyEnglish
```
2. Query task:
```bash
course-pipeline task get <task_id>
```
3. Run steps in order:
```bash
course-pipeline task run-step <task_id> ffmpeg
course-pipeline task run-step <task_id> asr
course-pipeline task run-step <task_id> align
course-pipeline task run-step <task_id> translate
course-pipeline task run-step <task_id> grammar
course-pipeline task run-step <task_id> summary
course-pipeline task run-step <task_id> package
```
4. Watch completion:
```bash
course-pipeline task watch <task_id>
```

## Human-in-the-loop
For `translate/grammar/summary`, the pipeline creates input files under:
- `.runtime/tasks/<task_id>/hitl/*_input.json`

Optional override outputs:
- `*_translate_output.json`
- `*_grammar_output.json`
- `*_summary_output.json`

Re-run corresponding `task run-step` to consume overrides.

## Rules
- Keep business implementation only in project script:
  - `/Users/rongts/eng-book-flutter/tools/course_pipeline/course_pipeline_ops.py`
- Do not duplicate business script in skill folder.
- Keep project requirements in:
  - `/Users/rongts/eng-book-flutter/openspec`

## Reminder
If user says they forgot the flow, respond with the `Open Codex Flow` steps first, then provide exact commands for the current `task_id` if known.

## References
- Read `references/contracts.md` for statuses, steps, and task shape.
