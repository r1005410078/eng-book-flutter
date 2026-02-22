# Change: Add Reading Lightweight Package Mode

## Why
Some courses already include usable subtitles and are intended primarily for reading playback. For these courses, enforcing `grammar` and `summary` as mandatory predecessors for `package` causes unnecessary processing and delays.

## What Changes
- Add an explicit "reading lightweight mode" flag at task level.
- Allow `package` step to proceed when `grammar` and/or `summary` are not done if lightweight mode is enabled.
- Keep default behavior unchanged for existing tasks (strict step dependency remains the default).

## Impact
- Affected specs: `course-package`
- Affected code: `/Users/rongts/eng-book-flutter/tools/course_pipeline/course_pipeline_ops.py`
