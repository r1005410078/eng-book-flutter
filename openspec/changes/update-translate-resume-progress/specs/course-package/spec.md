## ADDED Requirements
### Requirement: Translate Step Lesson Idempotency
The translate step SHALL skip lessons that have already been translated unless a manual HITL override is provided.

#### Scenario: Skip already translated lesson
- **WHEN** `*_translate_effective.json` exists for a lesson and no `*_translate_output.json` override file exists
- **THEN** the system MUST reuse existing translation output and MUST NOT recompute translation for that lesson.

#### Scenario: Recompute when override exists
- **WHEN** `*_translate_output.json` exists for a lesson
- **THEN** the system MUST process that lesson and consume the override output.

### Requirement: Translate Lesson Progress Visibility
The task runtime state SHALL expose per-lesson progress during translate execution.

#### Scenario: Task shows current lesson during translate
- **WHEN** translate is running for a multi-lesson task
- **THEN** `task get` MUST include the current lesson key, current lesson index, and total lesson count for translate progress.
