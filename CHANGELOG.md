# Changelog

## 0.1.0 (initial MVP)
- One-command install for macOS/Linux/WSL (`setup.sh`) and Windows (`setup.cmd` / `setup.ps1`), plus `update`, `status`, `scaffold`, `packs`, and `uninstall`.
- Company guardrails: security, data handling, responsible AI use. Company defaults: engineering practices, testing.
- Hooks: `company-guard-shell` (blocks destructive commands), `company-secret-scan`, `company-spec-task-check`.
- `company-spec-authoring` skill with requirements, design, and tasks templates.
- MCP baseline: GitHub and Atlassian enabled; Slack and Microsoft 365 gated on admin setup.
- Stack pack system with a `python` pack and a `_template`.
- Team scaffold and the reusable `kiro-guardrails` CI check.
