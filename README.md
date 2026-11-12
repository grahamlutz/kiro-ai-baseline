# kiro-ai-baseline

The company's AI engineering setup for [Kiro](https://kiro.dev). Clone it and
run one command to get the company guardrails, defaults, MCP connections,
hooks, and spec templates. Then scaffold any repo so its team can add its own
standards on top.

```
┌───────────────────────────────────────────────────────────────────┐
│ Layer 1 · Company (this repo → ~/.kiro on every engineer's laptop) │
│   Guardrails  can't be overridden (security, data, AI use)         │
│   Defaults    teams may override (engineering, testing, specs)     │
│   MCP         GitHub · Atlassian · Slack · Microsoft 365           │
│   Hooks       shell guard · secret scan · spec-task check          │
├───────────────────────────────────────────────────────────────────┤
│ Layer 2 · Stack packs (opt-in, copied into a repo at scaffold)     │
│   python  (more welcome: see packs/README.md)                      │
├───────────────────────────────────────────────────────────────────┤
│ Layer 3 · Team repo (.kiro/ committed in each repo, team-owned)    │
│   product · tech · structure · team conventions · skills · hooks   │
└───────────────────────────────────────────────────────────────────┘
        CI (kiro-guardrails) checks every team repo against Layer 1
```

## Quick start

**macOS / Linux / WSL**
```bash
git clone git@github.com:acme/kiro-ai-baseline.git ~/kiro-ai-baseline
~/kiro-ai-baseline/setup.sh
```

**Windows**
```powershell
git clone git@github.com:acme/kiro-ai-baseline.git $HOME\kiro-ai-baseline
~\kiro-ai-baseline\setup.cmd
```

Then follow the printed next steps: set `GITHUB_PERSONAL_ACCESS_TOKEN`,
restart Kiro, approve the env var, and sign in to Atlassian.

**Add the team layer to a repo** (once per repo, by any team member):
```bash
~/kiro-ai-baseline/setup.sh scaffold ~/code/my-service --pack python
# Windows: ~\kiro-ai-baseline\setup.cmd scaffold C:\code\my-service --pack python
```
Fill in the TODOs in `.kiro/steering/{product,tech,structure}.md`, then commit.

## Commands

| Command | What it does |
|---|---|
| `setup` | Install or re-sync the company layer into `~/.kiro`. Safe to re-run. |
| `setup update` | `git pull` this repo, then re-sync. |
| `setup status` | Installed vs. latest version, plus any locally edited managed files. |
| `setup scaffold <dir> [--pack <name>]...` | Add team `.kiro/` and CI check to a repo. Never overwrites existing files. |
| `setup packs` | List stack packs. |
| `setup uninstall` | Remove company-managed files; personal files are untouched. |

`setup` means `./setup.sh` on macOS/Linux/WSL and `setup.cmd` on Windows.

## What gets installed

| Path in `~/.kiro` | Contents | Tier |
|---|---|---|
| `steering/company-guardrails-*.md` | Security, data handling, responsible AI use | Guardrail |
| `steering/company-defaults-*.md` | Engineering practices, testing | Default |
| `skills/company-spec-authoring/` | Requirements, design, and tasks templates | Default |
| `hooks/company-guard-shell.json` | Blocks destructive shell commands (PreToolUse) | Guardrail |
| `hooks/company-secret-scan.json` | Flags secrets in files the agent saves | Guardrail |
| `hooks/company-spec-task-check.json` | Self-check after each spec task | Default |
| `settings/mcp.json` | Company servers merged with your personal ones | Managed |
| `company/` | Hook scripts, policy files, manifest, backups | Managed |

The installer only touches files it owns (tracked in `~/.kiro/company/manifest.tsv`).
If you edit a managed file, the next sync backs up your edit to
`~/.kiro/company/backups/` and restores the company version. Your own steering
files, skills, hooks, and MCP servers are never touched. For company MCP
servers, your on/off choice is kept across updates.

## Repository layout

```
setup.sh / setup.ps1 / setup.cmd   one-command installers (same behavior)
config/org.json                    org name, baseline repo, connector IDs (admin-owned)
company/                           Layer 1, installed to ~/.kiro
  steering/ skills/ hooks/ settings/mcp.json
  scripts/                         hook scripts (.sh + .ps1 pairs)
  policy/                          blocked commands, secret patterns, MCP allowlist
packs/                             Layer 2 stack packs (+ _template/)
templates/team/                    Layer 3 scaffold copied into team repos
tools/kiro_lint.py                 guardrail lint (central + team modes)
tools/kiro_json.py                 JSON helper for setup.sh
.github/workflows/                 CI, release, reusable kiro-guardrails check
docs/                              architecture, admin setup, team guide, contributing
tests/                             unit/integration (Python) + Windows smoke (PowerShell)
```

## Docs
- [Architecture and design decisions](docs/architecture.md)
- [Admin setup and rollout runbook](docs/admin-setup.md): **start here before rollout**
- [Team guide: customizing your repo](docs/team-guide.md)
- [Contributing: guardrails, defaults, packs, releases](docs/contributing.md)
- [Roadmap](docs/roadmap.md)

## Requirements
- Kiro IDE 1.0+ or Kiro CLI 3.0+ (uses the `.kiro/hooks/*.json` v1 hook schema)
- git
- macOS/Linux/WSL: bash and python3 (macOS: `xcode-select --install`)
- Windows: Windows PowerShell 5.1+ or PowerShell 7+ (no Python needed)
- Node.js (`npx`) only if you enable the Microsoft 365 connector
