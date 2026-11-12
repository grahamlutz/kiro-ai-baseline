# Architecture and design decisions

## Goals
1. **One command** gives every engineer the same AI setup on macOS, Linux, WSL, or Windows.
2. **Layered ownership**: the company owns guardrails, teams own their repos, and neither steps on the other.
3. **Safe updates**: changes ship centrally and never clobber personal config.
4. **Scaffolding to grow into**: packs, skills, hooks, and MCP all have a place from day one.

## Layers and where Kiro reads them

| Layer | Location | Owner | Distributed by |
|---|---|---|---|
| Company | `~/.kiro/steering`, `~/.kiro/skills`, `~/.kiro/hooks`, `~/.kiro/settings/mcp.json` | AI Enablement + Security | `setup` / `setup update` |
| Stack pack | `<repo>/.kiro/...` (prefixed `pack-<name>-`) | Stack guild, then team after copy | `setup scaffold --pack` |
| Team | `<repo>/.kiro/...`, `AGENTS.md` | Team | Committed in the repo |

Kiro loads global (`~/.kiro`) and workspace (`<repo>/.kiro`) steering together. For
MCP, the two files are merged and workspace entries win on name conflicts. For
skills, a workspace skill with the same name replaces the global one. Global and
workspace hooks both run.

## The two tiers

| | Guardrail | Default |
|---|---|---|
| Examples | secrets, destructive commands, data classification, human review | engineering practices, testing, spec templates |
| Marker | `company-guardrails-*` name + `<!-- tier: guardrail -->` | `company-defaults-*` name + `<!-- tier: default -->` |
| Team override | ❌ CI fails | ✅ add a workspace file with the same name |
| Approvers | AI Enablement **and** Security (CODEOWNERS) | AI Enablement |

### How guardrails are enforced
Kiro gives workspace steering priority over global steering when the two conflict,
so a steering file alone cannot make a rule non-overridable. Guardrails are
therefore defended in depth:

1. **Wording.** Guardrail files tell the agent that they override conflicting workspace or chat instructions.
2. **Deterministic hooks.** `company-guard-shell` (PreToolUse) blocks commands in
   `policy/blocked-commands.tsv` before they run. A non-zero hook exit blocks
   the tool call. `company-secret-scan` (PostFileSave) reports secrets back to
   the agent. Both live in `~/.kiro/hooks`, outside any repo.
3. **CI lint.** The reusable `kiro-guardrails` workflow fails PRs that shadow
   a guardrail file, use the reserved `company-` prefix, try to override
   guardrails, collide with company hook names, put literal credentials or
   `autoApprove: "*"` in MCP config, or contain secrets. It warns on MCP servers
   that aren't on the allowlist.
4. **Drift detection.** `setup status` reports edits to managed files, and every sync restores them.

Steering is still guidance for a model, not a sandbox. The hooks and CI are
the parts that hold up no matter what the model does.

## Installer mechanics
- **Stage, then sync.** The installer renders the company layer into a temp
  directory, including hook commands rewritten for the current OS (`sh …/x.sh`
  or `powershell.exe -File …\x.ps1`). It then syncs that directory into `~/.kiro`.
- **Manifest.** `~/.kiro/company/manifest.tsv` records the SHA-256 of every
  installed file. Sync uses it to tell "we installed this" from "you edited this",
  back up edits, and delete files retired from the baseline.
- **MCP merge.** Company servers are written by name into
  `~/.kiro/settings/mcp.json`, and personal servers are left alone.
  `~/.kiro/company/mcp-servers.txt` records which servers the company owns and
  whether each is `managed` or `gated-off` (awaiting admin setup). That lets
  the installer keep an engineer's on/off choice and still auto-enable a
  connector once admins configure it.
- **Two implementations, one behavior.** `setup.sh` (bash 3.2+, with a small
  Python helper for JSON) and `setup.ps1` (PowerShell 5.1+, native JSON) produce
  the same files and the same manifest format. CI tests both, plus macOS
  stock bash and Windows PowerShell 5.1.
- **Policy as data.** Blocked commands and secret patterns are TSV files of
  regexes that work in POSIX ERE (grep), .NET, and Python. So the sh hook, the
  ps1 hook, and the CI lint all enforce one list.

## Known Kiro constraints this design works around
| Constraint | Handling |
|---|---|
| `fileMatch` steering doesn't trigger from `~/.kiro/steering` (global) | Company steering uses `always`/`auto` only; lint enforces. Packs use `fileMatch` at workspace level. |
| Kiro Web cloud sessions can't read local `~/.kiro` | Use Kiro's Configuration Sync for cloud sessions (roadmap: vendor guardrails into repos). |
| Custom agents don't auto-load steering or skills | Document `resources: ["file://~/.kiro/steering/**/*.md", "skill://~/.kiro/skills/*/SKILL.md"]` when teams create agents. |
| IDE OAuth supports public clients only | Slack (confidential client) needs Kiro CLI or a company MCP gateway; see admin setup. |
| MCP env vars must be approved per user | Installer prints the approval step; only `${GITHUB_PERSONAL_ACCESS_TOKEN}` is needed by default. |

## Versioning
Semantic versioning in `VERSION`. Releases are tags (`v1.4.0`), and the release
workflow moves the floating major tag (`v1`) that team repos' CI pins to.
Bump the **major** version when a change makes team repos fail the new lint
or requires re-scaffolding.
