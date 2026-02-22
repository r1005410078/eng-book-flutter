## ADDED Requirements
### Requirement: Token-Efficient Batch Translation
The translate step SHALL minimize token and request overhead while preserving sentence-level output correctness.

#### Scenario: Repeated sentence reuse
- **WHEN** a lesson contains repeated untranslated English sentences
- **THEN** the system MUST translate each unique sentence at most once per lesson and reuse the result for duplicates.

#### Scenario: Stable batch alignment
- **WHEN** the system sends a batch translation request
- **THEN** it MUST use a transport format that preserves sentence boundaries without relying on newline splitting.

#### Scenario: Bounded request size
- **WHEN** untranslated sentences exceed configured request limits
- **THEN** the system MUST split them into deterministic chunks constrained by sentence-count and character budgets.

#### Scenario: Partial batch failure
- **WHEN** one batch chunk fails to translate
- **THEN** the system MUST limit retry/fallback to that chunk and MUST NOT degrade unrelated chunks to per-sentence fallback.

#### Scenario: Cost telemetry in step output
- **WHEN** translate step completes
- **THEN** the step output MUST include counters for requested items, deduplicated items, translated items, and fallback count.
