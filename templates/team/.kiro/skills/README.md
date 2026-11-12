# Team skills

Each skill is a folder with a `SKILL.md` (Agent Skills standard):

```
.kiro/skills/<skill-name>/
  SKILL.md          # front matter: name (must match folder), description (when to use)
  references/       # optional long-form docs loaded on demand
  scripts/          # optional deterministic helpers
```

```markdown
---
name: release-checklist
description: Steps to cut a release of this service. Use when preparing, tagging, or publishing a release.
---
# Release checklist
1. ...
```

A workspace skill with the same name as a company skill (e.g.
`company-spec-authoring`) overrides it for this repo.
