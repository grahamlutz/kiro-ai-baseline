#!/usr/bin/env bash
# kiro-ai-baseline setup for macOS, Linux, and WSL.
# Compatible with bash 3.2 (macOS default). Windows: use setup.ps1.
#
#   ./setup.sh                    install / re-sync the company layer into ~/.kiro
#   ./setup.sh update             git pull this repo, then re-sync
#   ./setup.sh status             show installed version and local drift
#   ./setup.sh scaffold <dir> [--pack <name>]...   add a team .kiro/ to a repo
#   ./setup.sh packs              list available stack packs
#   ./setup.sh uninstall          remove company-managed files from ~/.kiro
set -euo pipefail

REPO_ROOT="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
KIRO_HOME="${KIRO_HOME:-$HOME/.kiro}"
STATE="$KIRO_HOME/company"
MANIFEST="$STATE/manifest.tsv"
MCP_NAMES="$STATE/mcp-servers.txt"
VERSION="$(tr -d '[:space:]' < "$REPO_ROOT/VERSION")"
CONFIG="$REPO_ROOT/config/org.json"
JSONTOOL="$REPO_ROOT/tools/kiro_json.py"
TAB="$(printf '\t')"

if [ -t 1 ]; then B=$'\033[1m'; G=$'\033[32m'; Y=$'\033[33m'; R=$'\033[31m'; N=$'\033[0m'; else B=; G=; Y=; R=; N=; fi
log()  { printf '%s\n' "$*"; }
ok()   { printf '%s✓%s %s\n' "$G" "$N" "$*"; }
warn() { printf '%s!%s %s\n' "$Y" "$N" "$*" >&2; }
die()  { printf '%s✗ %s%s\n' "$R" "$*" "$N" >&2; exit 1; }

need_python() {
  command -v python3 >/dev/null 2>&1 && return 0
  die "python3 is required for JSON merging. macOS: run 'xcode-select --install'. Linux/WSL: install python3 with your package manager. Then re-run."
}
py() { python3 "$JSONTOOL" "$@"; }

sha() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
  else shasum -a 256 "$1" | cut -d' ' -f1; fi
}
manifest_hash() { [ -f "$MANIFEST" ] && awk -F'\t' -v r="$1" '$2==r{print $1}' "$MANIFEST" || true; }

BACKUP_DIR=""
backup() { # backup <relpath>
  [ -n "$BACKUP_DIR" ] || BACKUP_DIR="$STATE/backups/$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$BACKUP_DIR/$(dirname "$1")"
  cp -p "$KIRO_HOME/$1" "$BACKUP_DIR/$1"
}

# ---------------------------------------------------------------- install ---
stage_company() { # stage_company <stage_dir>
  local s="$1"
  mkdir -p "$s/steering" "$s/skills" "$s/hooks" "$s/company/scripts" "$s/company/policy"
  cp -R "$REPO_ROOT/company/steering/." "$s/steering/"
  cp -R "$REPO_ROOT/company/skills/." "$s/skills/"
  cp -R "$REPO_ROOT/company/policy/." "$s/company/policy/"
  cp "$REPO_ROOT/company/scripts/"*.sh "$s/company/scripts/"
  py render-hooks "$REPO_ROOT/company/hooks" "$s/hooks" 'sh "{script}"' "$STATE/scripts" sh
  cat > "$s/company/README.md" <<EOF
This folder is managed by kiro-ai-baseline ($VERSION).
Do not edit files here or the company-* files in ~/.kiro/steering, ~/.kiro/skills,
and ~/.kiro/hooks: they are overwritten by './setup.sh update'.
Source: $REPO_ROOT
EOF
}

sync_stage() { # sync_stage <stage_dir>
  local s="$1" new_manifest rel dest new_hash cur_hash old_hash changed=0
  new_manifest="$(mktemp)"
  while IFS= read -r -d '' f; do
    rel="${f#"$s"/}"
    dest="$KIRO_HOME/$rel"
    new_hash="$(sha "$f")"
    if [ -f "$dest" ]; then
      cur_hash="$(sha "$dest")"
      old_hash="$(manifest_hash "$rel")"
      if [ "$cur_hash" != "$new_hash" ]; then
        if [ -z "$old_hash" ]; then
          backup "$rel"; warn "replaced existing file ~/.kiro/$rel (backup kept)"
        elif [ "$cur_hash" != "$old_hash" ]; then
          backup "$rel"; warn "local edits to managed file ~/.kiro/$rel were backed up and replaced"
        fi
        changed=$((changed + 1))
      fi
    else
      changed=$((changed + 1))
    fi
    mkdir -p "$(dirname "$dest")"
    cp "$f" "$dest"
    printf '%s\t%s\n' "$new_hash" "$rel" >> "$new_manifest"
  done < <(find "$s" -type f -print0 | sort -z)

  if [ -f "$MANIFEST" ]; then
    while IFS="$TAB" read -r old_hash rel; do
      [ -n "$rel" ] || continue
      if ! awk -F'\t' -v r="$rel" '$2==r{found=1} END{exit !found}' "$new_manifest"; then
        if [ -f "$KIRO_HOME/$rel" ]; then
          [ "$(sha "$KIRO_HOME/$rel")" = "$old_hash" ] || backup "$rel"
          rm -f "$KIRO_HOME/$rel"
          log "  removed retired file ~/.kiro/$rel"
        fi
      fi
    done < "$MANIFEST"
  fi
  mv "$new_manifest" "$MANIFEST"
  chmod +x "$STATE/scripts/"*.sh 2>/dev/null || true
  ok "company files synced ($changed changed)"
}

cmd_install() {
  need_python
  [ -f "$CONFIG" ] || die "missing $CONFIG"
  log "${B}Installing kiro-ai-baseline $VERSION into $KIRO_HOME${N}"
  mkdir -p "$STATE" "$KIRO_HOME/settings"
  local prev_version=""; [ -f "$STATE/version" ] && prev_version="$(cat "$STATE/version")"

  local stage; stage="$(mktemp -d)"
  stage_company "$stage"
  sync_stage "$stage"
  rm -rf "$stage"

  local user_mcp="$KIRO_HOME/settings/mcp.json"
  if [ -f "$user_mcp" ]; then backup "settings/mcp.json"; fi
  log "MCP servers (merged into ~/.kiro/settings/mcp.json; your personal servers are kept):"
  local names_tmp; names_tmp="$(mktemp)"
  py merge-mcp "$REPO_ROOT/company/settings/mcp.json" "$CONFIG" "$user_mcp" "$MCP_NAMES" "$names_tmp" \
    || die "MCP merge failed; nothing in mcp.json was changed."
  mv "$names_tmp" "$MCP_NAMES"

  printf '%s\n' "$VERSION" > "$STATE/version"
  printf '%s\n' "$REPO_ROOT" > "$STATE/source"
  [ -n "$BACKUP_DIR" ] && log "  backups: $BACKUP_DIR"
  if [ -n "$prev_version" ] && [ "$prev_version" != "$VERSION" ]; then ok "upgraded $prev_version → $VERSION"; else ok "installed $VERSION"; fi

  log ""
  log "${B}Next steps${N}"
  if [ -z "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]; then
    log "  1. Create a fine-grained GitHub PAT and export it in your shell profile:"
    log "       export GITHUB_PERSONAL_ACCESS_TOKEN=<token>"
  else
    log "  1. GITHUB_PERSONAL_ACCESS_TOKEN is set ✓"
  fi
  log "  2. Restart Kiro. When it asks, approve the env var GITHUB_PERSONAL_ACCESS_TOKEN"
  log "     (Settings → 'Mcp Approved Env Vars')."
  log "  3. In the Kiro panel → MCP servers, sign in to Atlassian (browser OAuth)."
  log "  4. In any repo: ./setup.sh scaffold <path-to-repo> --pack python"
  log "  Keep current with: ./setup.sh update"
}

# ----------------------------------------------------------------- update ---
cmd_update() {
  if git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if [ -n "$(git -C "$REPO_ROOT" status --porcelain)" ]; then
      die "this clone has local changes. Commit, stash, or discard them (git -C \"$REPO_ROOT\" status), then re-run update."
    fi
    log "Pulling latest kiro-ai-baseline…"
    git -C "$REPO_ROOT" pull --ff-only --quiet || die "git pull failed. Resolve it in $REPO_ROOT and re-run."
  else
    warn "$REPO_ROOT is not a git clone; re-syncing local files only."
  fi
  exec "$REPO_ROOT/setup.sh" install   # re-exec so the freshly pulled script runs
}

# ----------------------------------------------------------------- status ---
cmd_status() {
  local installed="not installed"; [ -f "$STATE/version" ] && installed="$(cat "$STATE/version")"
  log "${B}kiro-ai-baseline${N}"
  log "  installed: $installed   (repo: $VERSION)   KIRO_HOME: $KIRO_HOME"
  if git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
     && git -C "$REPO_ROOT" fetch --quiet 2>/dev/null \
     && [ -n "$(git -C "$REPO_ROOT" rev-list "HEAD..@{u}" 2>/dev/null | head -1)" ]; then
    warn "a newer baseline is available: run ./setup.sh update"
  fi
  [ -f "$MANIFEST" ] || return 0
  local drift=0 h rel
  while IFS="$TAB" read -r h rel; do
    if [ ! -f "$KIRO_HOME/$rel" ]; then warn "missing: ~/.kiro/$rel"; drift=1
    elif [ "$(sha "$KIRO_HOME/$rel")" != "$h" ]; then warn "locally modified: ~/.kiro/$rel"; drift=1; fi
  done < "$MANIFEST"
  [ "$drift" -eq 0 ] && ok "all $(wc -l < "$MANIFEST" | tr -d ' ') managed files match"
  [ "$drift" -eq 0 ] || log "  run ./setup.sh to restore managed files"
}

# ------------------------------------------------------------------ packs ---
cmd_packs() {
  need_python
  log "${B}Available stack packs${N}"
  local d n
  for d in "$REPO_ROOT"/packs/*/; do
    n="$(basename "$d")"; [ "$n" = "_template" ] && continue
    [ -f "$d/pack.json" ] || continue
    printf '  %-14s %s\n' "$n" "$(py config-get "$d/pack.json" description)"
  done
}

# --------------------------------------------------------------- scaffold ---
copy_if_absent() { # copy_if_absent <src> <dest> <label>
  if [ -e "$2" ]; then log "  kept     $3 (already exists)"
  else mkdir -p "$(dirname "$2")"; cp "$1" "$2"; log "  created  $3"; fi
}

cmd_scaffold() {
  need_python
  local target="" packs="" p
  while [ $# -gt 0 ]; do
    case "$1" in
      --pack|-p) [ $# -ge 2 ] || die "--pack needs a name"; packs="$packs,$2"; shift 2 ;;
      --pack=*) packs="$packs,${1#--pack=}"; shift ;;
      -*) die "unknown option $1" ;;
      *) [ -z "$target" ] || die "only one target directory"; target="$1"; shift ;;
    esac
  done
  [ -n "$target" ] || die "usage: ./setup.sh scaffold <repo-dir> [--pack <name>]..."
  [ -d "$target" ] || die "$target is not a directory"
  target="$(CDPATH='' cd -- "$target" && pwd)"
  [ "$target" = "$REPO_ROOT" ] && die "scaffold a team repo, not the baseline repo itself"
  git -C "$target" rev-parse --is-inside-work-tree >/dev/null 2>&1 || warn "$target is not a git repo"
  packs="${packs#,}"

  local IFS_OLD="$IFS"; IFS=','
  for p in $packs; do
    [ "$p" != "_template" ] && [ -f "$REPO_ROOT/packs/$p/pack.json" ] || { IFS="$IFS_OLD"; die "unknown pack '$p' (see ./setup.sh packs)"; }
  done
  IFS="$IFS_OLD"

  log "${B}Scaffolding $target${N}"
  local tpl="$REPO_ROOT/templates/team" rel repo ref major
  repo="$(py config-get "$CONFIG" baselineRepo)"
  major="${VERSION%%.*}"; ref="v$major"
  while IFS= read -r -d '' f; do
    rel="${f#"$tpl"/}"
    if [ "$rel" = ".github/workflows/kiro-guardrails.yml" ] && [ ! -e "$target/$rel" ]; then
      mkdir -p "$(dirname "$target/$rel")"
      sed -e "s#{{BASELINE_REPO}}#$repo#g" -e "s#{{BASELINE_REF}}#$ref#g" "$f" > "$target/$rel"
      log "  created  $rel"
    else
      copy_if_absent "$f" "$target/$rel" "$rel"
    fi
  done < <(find "$tpl" -type f -print0 | sort -z)

  IFS=','
  for p in $packs; do
    IFS="$IFS_OLD"
    local pdir="$REPO_ROOT/packs/$p" sub
    log "  pack: $p"
    for sub in steering hooks skills; do
      [ -d "$pdir/$sub" ] || continue
      while IFS= read -r -d '' f; do
        rel=".kiro/$sub/${f#"$pdir/$sub"/}"
        [ "$(basename "$f")" = ".gitkeep" ] && continue
        copy_if_absent "$f" "$target/$rel" "$rel"
      done < <(find "$pdir/$sub" -type f -print0 | sort -z)
    done
    if [ -f "$pdir/settings/mcp.json" ]; then
      py merge-pack-mcp "$pdir/settings/mcp.json" "$target/.kiro/settings/mcp.json"
      log "  merged   .kiro/settings/mcp.json (pack servers)"
    fi
    local req
    for req in $(python3 -c 'import json,sys; print(" ".join(json.load(open(sys.argv[1])).get("requires", [])))' "$pdir/pack.json"); do
      command -v "$req" >/dev/null 2>&1 || warn "pack '$p' hooks need '$req' on PATH (install it, or set \"enabled\": false in the hook)"
    done
    IFS=','
  done
  IFS="$IFS_OLD"

  py write-baseline "$target/.kiro/company-baseline.json" "$VERSION" "$packs"
  log "  wrote    .kiro/company-baseline.json"
  ok "scaffold complete"
  log ""
  log "${B}Next steps${N}"
  log "  1. Fill in the TODOs in .kiro/steering/{product,tech,structure}.md"
  log "     (or ask Kiro: 'Update the steering docs for this repo')."
  log "  2. Commit .kiro/ and .github/workflows/kiro-guardrails.yml and open a PR."
  log "  3. Never commit secrets in .kiro/settings/mcp.json; use \${ENV_VAR} references."
}

# -------------------------------------------------------------- uninstall ---
cmd_uninstall() {
  [ -f "$MANIFEST" ] || die "nothing to uninstall (no manifest at $MANIFEST)"
  local h rel
  while IFS="$TAB" read -r h rel; do
    [ -f "$KIRO_HOME/$rel" ] || continue
    [ "$(sha "$KIRO_HOME/$rel")" = "$h" ] || backup "$rel"
    rm -f "$KIRO_HOME/$rel"
  done < "$MANIFEST"
  if [ -f "$KIRO_HOME/settings/mcp.json" ] && command -v python3 >/dev/null 2>&1; then
    backup "settings/mcp.json"
    py remove-mcp "$KIRO_HOME/settings/mcp.json" "$MCP_NAMES"
  fi
  rm -rf "$STATE/scripts" "$STATE/policy" "$MANIFEST" "$MCP_NAMES" "$STATE/version" "$STATE/source" "$STATE/README.md"
  ok "company layer removed. Personal files untouched.${BACKUP_DIR:+ Backups: $BACKUP_DIR}"
}

usage() { sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; }

case "${1:-install}" in
  install)   cmd_install ;;
  update)    cmd_update ;;
  status)    cmd_status ;;
  packs)     cmd_packs ;;
  scaffold)  shift; cmd_scaffold "$@" ;;
  uninstall) cmd_uninstall ;;
  -h|--help|help) usage ;;
  *) usage; exit 1 ;;
esac
