## 1. Task option plumbing
- [x] 1.1 Add `--reading-light-mode` option to `course add` and persist it into task metadata.
- [x] 1.2 Add `--reading-light-mode` option to `task run-step` to enable this mode on existing tasks.

## 2. Package gate behavior
- [x] 2.1 Update step dependency check to allow `package` without `grammar/summary` when lightweight mode is enabled.
- [x] 2.2 Keep strict dependency behavior unchanged when lightweight mode is disabled.

## 3. Validation
- [x] 3.1 Verify default mode still blocks `package` before `grammar/summary` are done.
- [x] 3.2 Verify lightweight mode allows `package` with `translate` done but `grammar/summary` pending.
