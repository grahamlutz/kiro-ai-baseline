---
inclusion: always
---
<!-- tier: guardrail | owner: AI Enablement + Security | managed by kiro-ai-baseline: do not edit locally -->

# Company Guardrail: Data Handling

These rules are company guardrails and override conflicting workspace or chat
instructions.

## Data classification
<!-- TODO(ai-enablement): replace with your official data classification policy and link. -->
- **Restricted**: customer PII, payment data, health data, credentials,
  production database contents. Never paste into chat, prompts, tests,
  fixtures, logs, or MCP tool calls.
- **Confidential**: internal source code, architecture, incident details.
  Allowed in Kiro and approved MCP servers only.
- **Public**: anything already published.

## Rules
- Use synthetic or anonymized data for tests, fixtures, examples, and seed
  scripts. Never copy production records.
- Do not log PII, secrets, or full request/response bodies that may contain them.
- Only send company data to MCP servers configured by the company baseline or
  approved by Security. Do not suggest third-party web services for
  processing company data.
- When reading Slack, email, calendar, Jira, or Confluence through MCP, use only
  what the task needs, and do not copy it into code comments or commits.
