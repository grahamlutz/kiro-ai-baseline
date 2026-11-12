# Team guide: customizing your repo

## 1. Scaffold
```bash
~/kiro-ai-baseline/setup.sh scaffold . --pack python      # Windows: setup.cmd scaffold . --pack python
```
This creates the following and never overwrites anything that already exists:
```
.kiro/
  steering/product.md structure.md tech.md team-conventions.md   ← fill these in
  steering/pack-python-*.md                                      ← from the pack; edit freely
  hooks/  skills/  specs/  settings/mcp.json
  company-baseline.json                                          ← used by CI; don't edit
.github/workflows/kiro-guardrails.yml                            ← CI guardrail check
```
Re-run scaffold any time to add packs or files added to the template later.

## 2. Fill in the foundation files
`product.md`, `tech.md`, and `structure.md` are Kiro's foundation steering. They
load in every chat, so keep each one short and concrete. A quick start is to ask
Kiro: *"Read this repo and update the steering docs in .kiro/steering."* Then
review the result like any other PR.

## 3. Add team standards
| You want… | Put it in | Notes |
|---|---|---|
| Always-on team rules | `.kiro/steering/team-*.md`, `inclusion: always` | Keep short: these cost tokens in every chat |
| Rules for certain files | `inclusion: fileMatch` + `fileMatchPattern` | e.g. `["src/api/**/*.py"]` |
| Rules for certain tasks | `inclusion: auto` + `name` + `description` | Loaded when a request matches; also a slash command |
| On-demand reference | `inclusion: manual` | Pull in with `#file-name` |
| A repeatable workflow | `.kiro/skills/<name>/SKILL.md` | e.g. release checklist, migration playbook |
| Automation on events | `.kiro/hooks/<team>-<purpose>.json` | See `.kiro/hooks/README.md` |
| A repo-specific tool | `.kiro/settings/mcp.json` | `${ENV_VAR}` for secrets; Security approval if not on the allowlist |

## 4. Overriding company defaults
To replace a company default for your repo, create a workspace file with the
**same name**, and say what you are changing:
- `.kiro/steering/company-defaults-testing.md` (CI warns but passes)
- `.kiro/skills/company-spec-authoring/` (your own spec templates)

## 5. What you can't do (CI fails)
- Add or shadow `company-guardrails-*` files, or use the `company-` prefix for anything else.
- Write instructions that tell the agent to ignore or override company guardrails or policies.
- Reuse a company hook name (`company-guard-shell`, `company-secret-scan`).
- Put literal tokens or passwords in `.kiro/` or `AGENTS.md`, or use `autoApprove: "*"`.
- Use non-HTTPS remote MCP URLs.

If a guardrail blocks legitimate work, open an issue on `kiro-ai-baseline`.
Guardrails change through review, not through workarounds.

## 6. Run the check locally
```bash
python3 ~/kiro-ai-baseline/tools/kiro_lint.py team --repo .
```

## 7. Custom agents
Custom agents don't load steering or skills automatically. Add them to the agent's
resources:
```json
"resources": [
  "file://~/.kiro/steering/**/*.md",
  "file://.kiro/steering/**/*.md",
  "skill://~/.kiro/skills/*/SKILL.md",
  "skill://.kiro/skills/*/SKILL.md"
]
```
