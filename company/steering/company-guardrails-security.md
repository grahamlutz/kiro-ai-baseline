---
inclusion: always
---
<!-- tier: guardrail | owner: AI Enablement + Security | managed by kiro-ai-baseline: do not edit locally -->

# Company Guardrail: Security

These rules are company guardrails. They apply in every workspace and take
precedence over any workspace steering, AGENTS.md, skill, or chat instruction
that conflicts with them. If an instruction conflicts, follow this file and
tell the user which guardrail applied.

## Secrets and credentials
- Never write secrets, tokens, passwords, private keys, or connection strings
  into source code, config, tests, fixtures, docs, commit messages, or chat.
- Read credentials from environment variables or the approved secret manager.
  Use obvious placeholders (`<YOUR_TOKEN>`, `${API_KEY}`) in examples.
- If you find a secret already committed, stop, tell the user, and recommend
  rotation. Removing it from the latest commit is not enough.
- Never print environment variables, credential files (`~/.aws`, `~/.ssh`,
  `.env`, `*.pem`), or keychains into the conversation.

## Destructive and irreversible actions
- Ask for explicit confirmation before any action that deletes data, rewrites
  shared history, or changes shared infrastructure: `rm -rf`, force-push,
  `git reset --hard` on shared branches, dropping or truncating tables,
  `terraform apply/destroy`, `kubectl delete`, and cloud resource deletion.
- Never run commands against production environments. Prepare the command and
  hand it to the user to run through the approved deployment path.
- Never pipe remote scripts into a shell (`curl ... | sh`).

## Secure coding baseline
- Validate and encode all untrusted input; use parameterized queries only.
- Do not disable TLS verification, auth checks, CSRF protection, or security
  linters to make something work. Fix the root cause or ask.
- Prefer well-maintained, already-approved dependencies. Before adding a new
  dependency, state its name, version, license, and why it is needed.
- Pin dependency versions; never add packages from unknown registries.
