---
inclusion: always
---
<!-- tier: team | owner: <your team> -->

# Team Conventions

<!--
Add team-specific standards here, or create more steering files in this folder.

Inclusion modes (YAML front matter, must be the first lines of the file):
  inclusion: always                       loaded in every chat
  inclusion: fileMatch                    loaded when matching files are in context
    fileMatchPattern: ["src/api/**/*.py"]
  inclusion: auto                         loaded when the request matches the description
    name: <kebab-name>
    description: <when to use>
  inclusion: manual                       loaded only via #<file-name> in chat

Company guardrails (~/.kiro/steering/company-guardrails-*.md) cannot be
overridden here; the kiro-guardrails CI check fails if a file tries to.
Company defaults (company-defaults-*.md) CAN be overridden: create a file with
the same name in this folder.
-->

- <e.g. "All new endpoints require an OpenAPI example">
