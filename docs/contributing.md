# Contributing

Everyone can propose changes. CODEOWNERS decides who approves them.

| Change | Where | Approvers |
|---|---|---|
| Guardrail (security, data, AI use) | `company/steering/company-guardrails-*.md`, `company/policy/`, `company/hooks/company-guard-*`, `company-secret-*` | AI Enablement **+** Security |
| Default | `company/steering/company-defaults-*.md`, `company/skills/` | AI Enablement |
| MCP server | `company/settings/mcp.json`, `company/policy/mcp-allowlist.txt` | AI Enablement **+** Security |
| Stack pack | `packs/<name>/` | Pack owner (in `pack.json` and CODEOWNERS) |
| Installer / lint | `setup.*`, `tools/` | AI Enablement |

## Rules of the road
- **Guardrails stay few and sharp.** Each one costs context in every chat. If it isn't
  about safety, data, or accountability, make it a default.
- **Prefer deterministic enforcement.** If a rule can be a hook or a lint check, make it one,
  and keep the steering text short.
- **Policy regexes** (`company/policy/*.tsv`) must work in POSIX ERE, .NET, and
  Python. That means no `\d`, `\s`, `\w`, `\b`, or lookarounds; the lint enforces this.
  Add test cases to `tests/test_baseline.py` (`BLOCK`/`ALLOW`, `SECRETS`/`NOT_SECRETS`).
- **Every hook script ships as a pair**: `name.sh` (POSIX sh) and `name.ps1` (PowerShell 5.1-compatible).
  Reference it from a hook as `{{RUN:name}}`.
- **Company file names** use `company-guardrails-*`, `company-defaults-*`, or `company-*` (hooks and skills).
  Pack files use `pack-<name>-*`.
- **Global steering** may only use `inclusion: always` or `auto`. `fileMatch` doesn't trigger from `~/.kiro`.

## Test locally
```bash
python3 tools/kiro_lint.py central
python3 -m unittest discover -s tests -v
pwsh ./tests/smoke.ps1                  # or: powershell -File tests\smoke.ps1
KIRO_HOME=/tmp/kiro-test ./setup.sh     # dry-run install into a scratch dir
```

## Release
1. Update `VERSION` and `CHANGELOG.md` in your PR.
2. After merge: `git tag v$(cat VERSION) && git push --tags`.
3. The release workflow creates the GitHub release and moves the major tag (`v1`).
4. Announce in your engineering channel: "run `setup update`".

Bump the **major** version if team repos must change to keep passing `kiro-guardrails`
(new lint errors, renamed reserved names, template changes that require re-scaffolding).
