#!/bin/sh
# managed by kiro-ai-baseline: do not edit locally
# Kiro PreToolUse hook (shell tools). Blocks commands matching
# ../policy/blocked-commands.tsv. A non-zero exit blocks the tool call, and
# stderr is shown to the agent so it can explain and offer a safe alternative.
set -u
DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
POLICY="$DIR/../policy/blocked-commands.tsv"
[ -f "$POLICY" ] || exit 0

payload=$(cat)

# Prefer the exact command from tool_input; otherwise fall back to the raw payload.
text="$payload"
if command -v python3 >/dev/null 2>&1; then
  extracted=$(printf '%s' "$payload" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(1)
ti = d.get("tool_input", d.get("toolInput", {}))
if isinstance(ti, dict):
    v = ti.get("command") or ti.get("cmd") or ti.get("script")
    print(v if isinstance(v, str) else json.dumps(ti))
else:
    print(ti)
' 2>/dev/null) && [ -n "$extracted" ] && text="$extracted"
fi

TAB=$(printf '\t')
while IFS="$TAB" read -r name flags regex; do
  case "$name" in ''|'#'*) continue ;; esac
  [ -n "${regex:-}" ] || continue
  if [ "$flags" = "i" ]; then opts="-Eiq"; else opts="-Eq"; fi
  if printf '%s\n' "$text" | grep $opts -e "$regex"; then
    echo "BLOCKED by company guardrail '$name' (see ~/.kiro/steering/company-guardrails-security.md)." >&2
    echo "Do not retry or work around this. Explain the risk to the user and, if they still want it, give them the exact command to run themselves." >&2
    exit 2
  fi
done < "$POLICY"
exit 0
