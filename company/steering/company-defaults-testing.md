---
inclusion: auto
name: company-defaults-testing
description: Company testing standards. Use when writing, changing, or reviewing tests, test fixtures, or test strategy.
---
<!-- tier: default | owner: AI Enablement | teams may override with a workspace file of the same name -->

# Company Default: Testing

- Every bug fix includes a test that fails before the fix and passes after.
- Prefer fast, deterministic unit tests. Mock network, clock, and randomness.
- Integration tests use synthetic data and isolated resources, never shared or
  production environments.
- Test names describe behavior: `returns_404_when_order_missing`, not `test1`.
- Do not lower coverage thresholds or mark tests skipped without saying why in
  the PR description.
