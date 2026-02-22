## 1. Translate idempotency
- [x] 1.1 In `execute_step_translate`, detect existing `*_translate_effective.json` and skip recomputation when no `*_translate_output.json` override exists.
- [x] 1.2 For skipped lessons, keep lesson result in step payload with source marker (`reuse_existing`) for observability.

## 2. Progress visibility
- [x] 2.1 During lesson loop, update task runtime state with translate progress fields: current lesson key, current lesson index, total lessons.
- [x] 2.2 Ensure progress fields are visible via `task get` while translate is running.

## 3. Validation
- [x] 3.1 Verify rerun of translate on a task with existing effective outputs skips those lessons.
- [x] 3.2 Verify `task get` exposes per-lesson translate progress.
