## ADDED Requirements
### Requirement: Local AI Parsing Pipeline Translation
The system SHALL provide a local pipeline step to efficiently translate course sentences into Chinese, minimizing AI token overhead.

#### Scenario: 批量翻译未缓存的句子
- **WHEN** the translation step processes a lesson with multiple untranslated English sentences
- **THEN** it MUST perform a batch AI translation request for sentences not present in the local cache, rather than processing each sentence atomicaly.
