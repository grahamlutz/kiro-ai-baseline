# Requirements: <Feature name>

- **Ticket:** <ENG-123>
- **Owner:** <name / team>
- **Status:** Draft | In review | Approved
- **Data classification touched:** Public | Confidential | Restricted

## Introduction
<One paragraph: the problem, who has it, and why now.>

## Requirements

### Requirement 1: <short name>
**User story:** As a <role>, I want <capability>, so that <benefit>.

**Acceptance criteria (EARS):**
1. WHEN <trigger> THEN the system SHALL <response>.
2. IF <precondition> THEN the system SHALL <response>.
3. WHILE <state> the system SHALL <behavior>.

### Requirement 2: <short name>
...

## Non-functional requirements
- **Security:** <authn/authz, secrets, input validation>
- **Data handling:** <what data, where it is stored, retention>
- **Performance:** <latency or throughput targets>
- **Observability:** <logs, metrics, alerts; no PII in logs>
- **Accessibility / i18n:** <if user-facing>

## Out of scope
- <explicit non-goals>

## Open questions
- OPEN QUESTION: <...>

## Checklist
- [ ] Every requirement has at least one testable acceptance criterion
- [ ] Data classification is stated
- [ ] Non-functional requirements are filled in or marked N/A with a reason
