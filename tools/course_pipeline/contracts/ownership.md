# Ownership And Placement

- Project script single source of truth:
  - `/Users/rongts/eng-book-flutter/tools/course_pipeline/course_pipeline_ops.py`
- Global command wrapper target:
  - `course-pipeline` -> project script above
- Skill orchestration location (if enabled):
  - `~/.codex/skills/course-pipeline-ops`
- Task runtime state location:
  - `/Users/rongts/eng-book-flutter/runtime/tasks`

Skill layer MUST call global command or project script directly and MUST NOT duplicate business script implementation.
