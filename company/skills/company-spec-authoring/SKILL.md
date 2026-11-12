---
name: company-spec-authoring
description: Company templates and quality bar for Kiro specs (requirements.md, design.md, tasks.md). Use when creating, updating, or reviewing a spec under .kiro/specs/, planning a feature, or writing requirements, a technical design, or an implementation task list.
---
<!-- tier: default | owner: AI Enablement | teams may override with a workspace skill of the same name -->

# Company Spec Authoring

Use this skill whenever you create or edit a spec in `.kiro/specs/<feature>/`.

## Steps
1. **Requirements**: follow `references/requirements-template.md`. Every
   requirement has a user story and EARS-style acceptance criteria. Include a
   non-functional section covering security, data classification, performance,
   and observability.
2. **Design**: follow `references/design-template.md`. Call out alternatives
   considered, data flows that touch Restricted or Confidential data, and the
   rollout and rollback plan.
3. **Tasks**: follow `references/tasks-template.md`. Each task is small enough
   for one reviewable PR, links back to the requirement IDs it satisfies, and
   includes its tests.
4. Before marking the spec ready, run the checklist at the end of each template.

## Quality bar
- Use the team's ticket key (e.g. `ENG-123`) in the spec folder's README or the
  requirements header.
- No requirement without an acceptance criterion; no task without a requirement.
- If information is missing, write `OPEN QUESTION:` rather than guessing.
