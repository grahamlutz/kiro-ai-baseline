#!/bin/sh
# managed by kiro-ai-baseline: do not edit locally
# Kiro PostFileSave hook. Scans the saved file for secret patterns from
# ../policy/secret-patterns.tsv. Reports line numbers only (never the secret).
# Exit 1 sends the findings to the agent so it removes the secret.
set -u
DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
POLICY="$DIR/../policy/secret-patterns.tsv"
[ -f "$POLICY" ] || exit 0

file="${1:-}"
# Fallback: if Kiro did not substitute {{filePath}}, read the path from stdin JSON.
case "$file" in ''|*'{{'*)
  file=""
  if command -v python3 >/dev/null 2>&1; then
    file=$(python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for k in ("file_path", "filePath", "path"):
    v = d.get(k) or (d.get("tool_input") or {}).get(k)
    if isinstance(v, str):
        print(v); break
' 2>/dev/null)
  fi ;;
esac
[ -n "$file" ] && [ -f "$file" ] || exit 0

# Skip large files and the policy files themselves.
size=$(wc -c < "$file" | tr -d ' ')
[ "$size" -le 1048576 ] || exit 0
case "$file" in *secret-patterns.tsv|*blocked-commands.tsv) exit 0 ;; esac

found=0
TAB=$(printf '\t')
while IFS="$TAB" read -r name flags regex; do
  case "$name" in ''|'#'*) continue ;; esac
  [ -n "${regex:-}" ] || continue
  if [ "$flags" = "i" ]; then opts="-EnIi"; else opts="-EnI"; fi
  lines=$(grep $opts -e "$regex" "$file" 2>/dev/null | grep -v 'kiro-secret-scan: allow' | cut -d: -f1 | tr '\n' ',' | sed 's/,$//')
  if [ -n "$lines" ]; then
    echo "Possible secret ($name) in $file at line(s): $lines" >&2
    found=1
  fi
done < "$POLICY"

if [ "$found" -eq 1 ]; then
  echo "Company guardrail: remove the secret, read it from an environment variable or the secret manager, and tell the user it may need rotation." >&2
  exit 1
fi
exit 0
