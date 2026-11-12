---
inclusion: always
---
<!-- tier: default | owner: AI Enablement | teams may override with a workspace file of the same name -->

# Company Default: Engineering Practices

These are company defaults. A team can override them by adding
`.kiro/steering/company-defaults-engineering.md` to their repo. Workspace
steering takes precedence over these defaults.

## Before you change code
- Read the repo's `.kiro/steering/` files (product, tech, structure) and follow
  existing patterns over personal preference.
- For non-trivial features, use a spec (requirements, design, tasks) before
  writing code. See the `company-spec-authoring` skill.

## Code quality
- Match the repo's formatter and linter. Never reformat unrelated code.
- Small, focused functions; descriptive names; no dead code or commented-out blocks.
- Handle errors explicitly. No silent catches.
- Add or update tests with every behavior change.

## Git and pull requests
- Branch names: `<type>/<ticket>-<short-desc>`, for example `feat/ENG-123-add-export`.
- Commits use Conventional Commits: `feat:`, `fix:`, `chore:`, `docs:`,
  `refactor:`, `test:`.
- Reference the ticket key (e.g. `ENG-123`) in the PR title or body.
- PR description: what changed, why, how it was tested, risks or rollout notes.
