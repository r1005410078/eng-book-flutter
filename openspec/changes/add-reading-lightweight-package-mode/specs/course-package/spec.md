## ADDED Requirements
### Requirement: Reading Lightweight Package Mode
The system SHALL support an explicit lightweight mode that relaxes package prerequisites for reading-focused courses.

#### Scenario: Default strict dependency remains
- **WHEN** lightweight mode is not enabled
- **THEN** `package` MUST require all prior steps in order, including `grammar` and `summary`.

#### Scenario: Lightweight mode relaxes package gate
- **WHEN** lightweight mode is enabled for a task
- **THEN** `package` MUST be allowed when `translate` is done even if `grammar` and `summary` are still pending.

#### Scenario: Lightweight mode is explicit
- **WHEN** a task is created or a step is run with the lightweight option
- **THEN** the task metadata MUST persist that option so subsequent runs use consistent behavior.
