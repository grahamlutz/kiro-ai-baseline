# Implementation Tasks: <Feature name>

Each task should be one reviewable PR (roughly under 400 changed lines) and
must list the requirement IDs it satisfies.

- [ ] 1. <Task title>
  - <What to build, in one or two bullets>
  - Tests: <unit/integration tests to add>
  - _Requirements: 1.1, 1.2_

- [ ] 2. <Task title>
  - [ ] 2.1 <Sub-task>
    - Tests: <...>
    - _Requirements: 2.1_
  - [ ] 2.2 <Sub-task>
    - _Requirements: 2.2_

- [ ] 3. Observability and docs
  - Logs/metrics/alerts per the design; update README or runbook
  - _Requirements: NFR-Observability_

## Checklist
- [ ] Every requirement is covered by at least one task
- [ ] Every task includes its tests
- [ ] Tasks are ordered so each one leaves the build green
