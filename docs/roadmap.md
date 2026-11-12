# Roadmap

These are things the scaffolding already has room for, roughly in priority order.

| Next | What it takes |
|---|---|
| **More stack packs** (TypeScript, Java/Kotlin, Terraform, Go) | Stack guilds copy `packs/_template/`, add tests, and own the folder in CODEOWNERS. |
| **Required CI check org-wide** | An org ruleset that requires `kiro-guardrails` once pilot repos pass. |
| **Company MCP gateway** | One gateway holding Slack and other confidential OAuth secrets, plus audit logs and per-tool allowlists. Repoint `url`s in `company/settings/mcp.json`. |
| **Guardrails in Kiro Web / cloud sessions** | Cloud sessions can't read `~/.kiro`. Either upload through Kiro Configuration Sync, or add a scaffold option that vendors `company-guardrails-*` into repos with a hash check in lint. |
| **MDM distribution** | Have Jamf, Intune, or another MDM run `setup` (or `setup update`) on a schedule, so laptops stay current without engineers pulling. |
| **Company custom agents** | e.g. a `reviewer` agent with read-only tools, with company steering and skills in `resources`. Add `company/agents/` and install it to `~/.kiro/agents/`. |
| **More company skills** | PR description writer, incident write-up, ADR author, dependency upgrade playbook. |
| **Kiro Powers** | Package pack + MCP + steering bundles as Powers once the format suits your distribution. |
| **Signed PowerShell scripts** | Needed if Group Policy enforces `AllSigned`. Sign `company/scripts/*.ps1` in the release workflow. |
| **Adoption metrics** | Count scaffolded repos (`.kiro/company-baseline.json`) and installed versions to target enablement. |
