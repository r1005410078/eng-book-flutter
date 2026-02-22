## 1. Batch protocol hardening
- [x] 1.1 Replace newline-delimited joined batching with sentinel-framed batching so response alignment does not depend on text-internal newlines.
- [x] 1.2 Add robust parsing that preserves order and gracefully falls back when chunk parsing fails.

## 2. Cost controls
- [x] 2.1 Add in-lesson de-duplication map (`en -> zh`) before remote translation calls.
- [x] 2.2 Add chunking policy (max items + max chars per request) configurable by environment variables.
- [x] 2.3 Implement chunk-level retry/fallback to avoid full per-sentence fallback when one chunk fails.

## 3. Contract and observability
- [x] 3.1 Update batch translator function signature to `list[str | None]` and clean call-site typing.
- [ ] 3.2 Emit lightweight counters in step output (`requested`, `deduped`, `translated`, `fallback_count`) for cost verification.

## 4. Validation
- [x] 4.1 Run `course-pipeline task run-step <task_id> translate` on a lesson with repeated short sentences and verify fewer upstream requests.
- [x] 4.2 Confirm output correctness (`*_translate_effective.json`) and that status/source semantics remain unchanged.
