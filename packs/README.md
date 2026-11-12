# Stack packs

A pack is an opt-in bundle of **workspace-level** steering, hooks, skills, and
optional MCP servers for a single tech stack. Teams choose packs when they
scaffold a repo:

```bash
./setup.sh scaffold ../my-service --pack python
```

Pack files are copied into the team repo's `.kiro/` and become the team's to
edit. They are **defaults** (tier 2), never guardrails.

## Layout

```
packs/<name>/
  pack.json            # name, version, description, owner, requires[]
  steering/            # pack-<name>-*.md, usually inclusion: fileMatch
  hooks/               # pack-<name>-*.json (Kiro hook schema v1)
  skills/<skill>/      # optional Agent Skills (SKILL.md + references/)
  settings/mcp.json    # optional, merged into the repo's .kiro/settings/mcp.json
```

## Contributing a pack
1. Copy `_template/` to `packs/<name>/` and replace every `<placeholder>` and `STACK`.
2. Prefix every file with `pack-<name>-` so packs never collide with each other or with team files.
3. Use `inclusion: fileMatch` so the pack only loads for matching files.
4. Run `python3 tools/kiro_lint.py central` and open a PR. Add your team to `.github/CODEOWNERS` for the pack folder.

`_template/` is ignored by the scaffold command.
