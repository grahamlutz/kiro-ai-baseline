# Team hooks

Add Kiro hooks as JSON files here (`<team>-<purpose>.json`). Schema:

```json
{
  "version": "v1",
  "hooks": [
    {
      "name": "team-run-unit-tests",
      "description": "What it does and why",
      "trigger": "PostFileSave",
      "matcher": "\\.py$",
      "timeout": 60,
      "action": { "type": "command", "command": "make test-fast" }
    }
  ]
}
```

- Triggers: `PromptSubmit`, `AgentStop`, `SessionStart`, `PreToolUse`, `PostToolUse`,
  `PostFileSave`, `FileCreate`, `FileDelete`, `PreTaskExecution`, `PostTaskExecution`.
- Actions: `{ "type": "command", "command": "..." }` or `{ "type": "agent", "prompt": "..." }`.
- Company hooks in `~/.kiro/hooks/` (secret scan, shell guard) run alongside yours.
  Do not try to disable or duplicate them.
- Command hooks run on every engineer's OS. Use tools that exist on all of
  them (e.g. `make`, `npm`, `uv`) or ship both `.sh` and `.ps1` variants.
