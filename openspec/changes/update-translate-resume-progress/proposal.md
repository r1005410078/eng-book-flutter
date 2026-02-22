# Change: Skip Already-Translated Lessons and Expose Per-Lesson Progress

## Why
Re-running the `translate` step currently processes all lessons again, including lessons that already have effective translation output. This wastes time and token budget. Also, task progress only shows `current_step=translate` but not which lesson is currently being processed.

## What Changes
- Add lesson-level idempotency for `translate`: if a lesson already has effective translation output and no HITL override is present, skip recomputation.
- Add per-lesson translate progress in task payload while `translate` is running, including current lesson key and lesson index.
- Keep existing output schema compatible, while adding explicit lesson source values for skipped lessons.

## Impact
- Affected specs: `course-package`
- Affected code: `/Users/rongts/eng-book-flutter/tools/course_pipeline/course_pipeline_ops.py`
