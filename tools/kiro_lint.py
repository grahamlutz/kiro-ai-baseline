#!/usr/bin/env python3
"""kiro-ai-baseline lint: enforces the two-tier model in CI.

  python3 tools/kiro_lint.py central [--root .]
      Validate this baseline repo: company layer, packs, templates.

  python3 tools/kiro_lint.py team --repo <team-repo> [--baseline <baseline-repo>]
      Validate a team repo's .kiro/ and AGENTS.md against company guardrails.

Exit code 1 if any ERROR is found. WARNs never fail the build.
Standard library only.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

INCLUSION_MODES = {"always", "fileMatch", "manual", "auto"}
HOOK_TRIGGERS = {
    "PromptSubmit", "AgentStop", "SessionStart", "SessionEnd", "AgentSpawn",
    "PreToolUse", "PostToolUse", "PostFileSave", "FileSave", "FileCreate",
    "FileDelete", "PreTaskExecution", "PostTaskExecution", "Stop",
}
TIER_RE = re.compile(r"<!--\s*tier:\s*(guardrail|default|team)\b", re.I)
OVERRIDE_RE = re.compile(
    r"\b(ignore|disregard|override|bypass|skip|disable|turn\s+off|do\s+not\s+follow|don'?t\s+follow)\b"
    r"[^.\n]{0,40}?\b(company|org(anization)?|global|security)\b[^.\n]{0,20}?"
    r"\b(guardrails?|rules?|polic(y|ies)|standards?|steering|hooks?)\b",
    re.I,
)
SENSITIVE_KEY_RE = re.compile(r"(token|secret|password|passwd|api[_-]?key|authorization|credential|private[_-]?key)", re.I)
ENV_REF_RE = re.compile(r"^\s*(Bearer\s+|Basic\s+|token\s+)?\$\{[A-Za-z_][A-Za-z0-9_]*\}\s*$", re.I)
NAME_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
SEMVER_RE = re.compile(r"^\d+\.\d+\.\d+$")


@dataclass
class Report:
    errors: list[str] = field(default_factory=list)
    warns: list[str] = field(default_factory=list)

    def err(self, path, msg):
        self.errors.append(f"ERROR {path}: {msg}")

    def warn(self, path, msg):
        self.warns.append(f"WARN  {path}: {msg}")

    def emit(self) -> int:
        for line in self.errors + self.warns:
            print(line)
        # GitHub Actions annotations
        for line in self.errors:
            print(f"::error::{line}")
        print(f"\n{len(self.errors)} error(s), {len(self.warns)} warning(s)")
        return 1 if self.errors else 0


# ------------------------------------------------------------------ parsing --
def parse_front_matter(text: str):
    """Return (dict|None, error|None). Minimal YAML subset used by Kiro steering."""
    if not text.startswith("---"):
        return None, None
    lines = text.splitlines()
    try:
        end = next(i for i, l in enumerate(lines[1:], 1) if l.strip() == "---")
    except StopIteration:
        return None, "front matter is not closed with '---'"
    data = {}
    for raw in lines[1:end]:
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        if ":" not in raw:
            return None, f"invalid front matter line: {raw!r}"
        k, v = raw.split(":", 1)
        v = v.strip()
        if v.startswith("[") and v.endswith("]"):
            try:
                v = json.loads(v)
            except json.JSONDecodeError:
                v = [x.strip().strip("'\"") for x in v[1:-1].split(",") if x.strip()]
        else:
            v = v.strip("'\"")
        data[k.strip()] = v
    return data, None


def load_patterns(policy_file: Path):
    out = []
    if not policy_file.exists():
        return out
    for line in policy_file.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        parts = line.split("\t", 2)
        if len(parts) == 3:
            flags = re.I if parts[1] == "i" else 0
            out.append((parts[0], re.compile(parts[2], flags)))
    return out


# ------------------------------------------------------------------- checks --
def check_steering(path: Path, rep: Report, *, central: bool, scope: str = ""):
    text = path.read_text(encoding="utf-8")
    fm, error = parse_front_matter(text)
    if error:
        rep.err(path, error)
        return
    if text.lstrip() != text:
        rep.err(path, "front matter must be the very first content (no leading blank lines)")
    if fm is None:
        rep.warn(path, "no front matter; Kiro treats it as 'inclusion: always'")
        fm = {"inclusion": "always"}
    mode = fm.get("inclusion", "always")
    if mode not in INCLUSION_MODES:
        rep.err(path, f"inclusion '{mode}' is not one of {sorted(INCLUSION_MODES)}")
    if mode == "fileMatch" and not fm.get("fileMatchPattern"):
        rep.err(path, "inclusion: fileMatch requires fileMatchPattern")
    if mode == "auto" and not (fm.get("name") and fm.get("description")):
        rep.err(path, "inclusion: auto requires both name and description")
    if central and scope == "global":
        tier = TIER_RE.search(text)
        if not tier:
            rep.err(path, "company steering must declare '<!-- tier: guardrail|default ... -->'")
        elif tier.group(1).lower() == "guardrail" and mode != "always":
            rep.err(path, "guardrail steering must use inclusion: always")
        if mode == "fileMatch":
            rep.err(path, "fileMatch does not trigger from ~/.kiro/steering (global); use always or auto")
        if not path.name.startswith(("company-guardrails-", "company-defaults-")):
            rep.err(path, "company steering files must be named company-guardrails-* or company-defaults-*")
        if tier and path.name.startswith("company-guardrails-") != (tier.group(1).lower() == "guardrail"):
            rep.err(path, "file name prefix and tier marker disagree")


def check_hook_file(path: Path, rep: Report, *, central: bool):
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as err:
        rep.err(path, f"invalid JSON: {err}")
        return []
    if data.get("version") != "v1":
        rep.err(path, "hook files need \"version\": \"v1\"")
    hooks = data.get("hooks")
    if not isinstance(hooks, list) or not hooks:
        rep.err(path, "hook files need a non-empty \"hooks\" array")
        return []
    names = []
    for i, h in enumerate(hooks):
        where = f"{path}#hooks[{i}]"
        for req in ("name", "trigger", "action"):
            if req not in h:
                rep.err(where, f"missing required field '{req}'")
        if h.get("trigger") and h["trigger"] not in HOOK_TRIGGERS:
            rep.warn(where, f"unrecognized trigger '{h['trigger']}'")
        act = h.get("action", {})
        if act.get("type") == "command" and not act.get("command"):
            rep.err(where, "command action needs 'command'")
        elif act.get("type") == "agent" and not act.get("prompt"):
            rep.err(where, "agent action needs 'prompt'")
        elif act and act.get("type") not in ("command", "agent"):
            rep.err(where, "action.type must be 'command' or 'agent'")
        if h.get("matcher"):
            try:
                re.compile(h["matcher"])
            except re.error as err:
                rep.err(where, f"matcher is not a valid regex: {err}")
        if not central and "{{RUN:" in str(act.get("command", "")):
            rep.err(where, "{{RUN:...}} is reserved for company hooks")
        if h.get("name"):
            names.append(h["name"])
    return names


def check_mcp(path: Path, rep: Report, *, allowlist: set[str], central: bool):
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as err:
        rep.err(path, f"invalid JSON: {err}")
        return
    servers = data.get("mcpServers", {})
    if not isinstance(servers, dict):
        rep.err(path, "'mcpServers' must be an object")
        return

    def walk(node, trail):
        if isinstance(node, dict):
            for k, v in node.items():
                if isinstance(v, str) and SENSITIVE_KEY_RE.search(k) and v and not ENV_REF_RE.match(v) and "{{" not in v:
                    rep.err(path, f"{'.'.join(trail + [k])} looks like a literal credential; use ${{ENV_VAR}}")
                walk(v, trail + [k])
        elif isinstance(node, list):
            for i, v in enumerate(node):
                walk(v, trail + [str(i)])

    for name, s in servers.items():
        where = f"mcpServers.{name}"
        walk(s, ["mcpServers", name])
        aa = s.get("autoApprove", [])
        if aa == "*" or (isinstance(aa, list) and "*" in aa):
            rep.err(path, f"{where}.autoApprove '*' is not allowed (approve specific read-only tools)")
        url = s.get("url", "")
        if url and not (url.startswith("https://") or re.match(r"^http://(localhost|127\.0\.0\.1)(:|/|$)", url)):
            rep.err(path, f"{where}.url must use https (or http://localhost)")
        if not central and allowlist:
            host = re.sub(r"^https?://([^/:]+).*$", r"\1", url) if url else ""
            if name not in allowlist and host not in allowlist:
                rep.warn(path, f"{where} is not on the company MCP allowlist; confirm Security has approved it")


def check_skill_dir(d: Path, rep: Report):
    sk = d / "SKILL.md"
    if not sk.exists():
        rep.err(d, "skill folder needs a SKILL.md")
        return
    fm, error = parse_front_matter(sk.read_text(encoding="utf-8"))
    if error or not fm:
        rep.err(sk, error or "SKILL.md needs YAML front matter with name and description")
        return
    if fm.get("name") != d.name:
        rep.err(sk, f"front matter name '{fm.get('name')}' must match folder '{d.name}'")
    if not NAME_RE.match(d.name):
        rep.err(sk, "skill names must be lowercase kebab-case")
    if len(str(fm.get("description", ""))) < 20:
        rep.err(sk, "description must say what the skill does and when to use it")


def scan_secrets(files, rep: Report, patterns):
    for f in files:
        try:
            lines = f.read_text(encoding="utf-8").splitlines()
        except (UnicodeDecodeError, OSError):
            continue
        for n, line in enumerate(lines, 1):
            if "kiro-secret-scan: allow" in line:
                continue
            for name, rx in patterns:
                if rx.search(line):
                    rep.err(f"{f}:{n}", f"possible secret ({name})")


def scan_override_language(files, rep: Report):
    for f in files:
        try:
            text = f.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        for n, line in enumerate(text.splitlines(), 1):
            if OVERRIDE_RE.search(line):
                rep.err(f"{f}:{n}", "instruction appears to override a company guardrail; guardrails cannot be overridden")


# -------------------------------------------------------------------- modes --
def lint_central(root: Path) -> int:
    rep = Report()
    company = root / "company"
    policy = company / "policy"
    secret_patterns = load_patterns(policy / "secret-patterns.tsv")

    # policy files compile in Python (a proxy for ERE/.NET compatibility)
    for pf in ("blocked-commands.tsv", "secret-patterns.tsv"):
        p = policy / pf
        if not p.exists():
            rep.err(p, "missing policy file")
            continue
        for n, line in enumerate(p.read_text(encoding="utf-8").splitlines(), 1):
            if not line.strip() or line.startswith("#"):
                continue
            parts = line.split("\t", 2)
            if len(parts) != 3 or parts[1] not in ("i", "-"):
                rep.err(f"{p}:{n}", "expected <name>\\t<i|->\\t<regex>")
                continue
            if re.search(r"\\[dswbDSWB]|\(\?[=!<]", parts[2]):
                rep.err(f"{p}:{n}", "regex must not use \\d \\s \\w \\b or lookarounds (POSIX ERE compatibility)")
            try:
                re.compile(parts[2])
            except re.error as err:
                rep.err(f"{p}:{n}", f"invalid regex: {err}")

    version = (root / "VERSION").read_text().strip() if (root / "VERSION").exists() else ""
    if not SEMVER_RE.match(version):
        rep.err(root / "VERSION", "must contain a semantic version like 1.2.3")

    for f in sorted((company / "steering").glob("*.md")):
        check_steering(f, rep, central=True, scope="global")
    hook_names: list[str] = []
    for f in sorted((company / "hooks").glob("*.json")):
        hook_names += check_hook_file(f, rep, central=True)
        if not f.name.startswith("company-"):
            rep.err(f, "company hook files must be named company-*.json")
    if len(hook_names) != len(set(hook_names)):
        rep.err(company / "hooks", "hook names must be unique")
    for d in sorted(p for p in (company / "skills").iterdir() if p.is_dir()):
        check_skill_dir(d, rep)
        if not d.name.startswith("company-"):
            rep.err(d, "company skills must be named company-*")
    check_mcp(company / "settings" / "mcp.json", rep, allowlist=set(), central=True)
    for s in ("guard-shell", "secret-scan"):
        for ext in ("sh", "ps1"):
            if not (company / "scripts" / f"{s}.{ext}").exists():
                rep.err(company / "scripts", f"missing {s}.{ext} (every script needs sh + ps1)")

    for pdir in sorted(p for p in (root / "packs").iterdir() if p.is_dir() and p.name != "_template"):
        pj = pdir / "pack.json"
        try:
            meta = json.loads(pj.read_text())
        except (OSError, json.JSONDecodeError) as err:
            rep.err(pj, f"missing or invalid pack.json: {err}")
            continue
        for k in ("name", "version", "description", "owner"):
            if not meta.get(k):
                rep.err(pj, f"missing '{k}'")
        if meta.get("name") != pdir.name:
            rep.err(pj, "name must match the folder name")
        prefix = f"pack-{pdir.name}-"
        for f in sorted((pdir / "steering").glob("*.md")) if (pdir / "steering").exists() else []:
            check_steering(f, rep, central=False)
            if not f.name.startswith(prefix):
                rep.err(f, f"pack files must be prefixed '{prefix}'")
        for f in sorted((pdir / "hooks").glob("*.json")) if (pdir / "hooks").exists() else []:
            check_hook_file(f, rep, central=False)
            if not f.name.startswith(prefix):
                rep.err(f, f"pack files must be prefixed '{prefix}'")
        if (pdir / "skills").exists():
            for d in sorted(p for p in (pdir / "skills").iterdir() if p.is_dir()):
                check_skill_dir(d, rep)
        if (pdir / "settings" / "mcp.json").exists():
            check_mcp(pdir / "settings" / "mcp.json", rep, allowlist=set(), central=True)

    tpl = root / "templates" / "team" / ".kiro"
    for f in sorted((tpl / "steering").glob("*.md")):
        check_steering(f, rep, central=False)
    check_mcp(tpl / "settings" / "mcp.json", rep, allowlist=set(), central=True)

    scan = [p for p in root.rglob("*") if p.is_file() and ".git" not in p.parts
            and p.suffix in {".md", ".json", ".yml", ".yaml", ".sh", ".ps1", ".py", ".txt"}
            and p.parent.name != "policy" and "fixtures" not in p.parts]
    scan_secrets(scan, rep, secret_patterns)
    return rep.emit()


def lint_team(repo: Path, baseline: Path) -> int:
    rep = Report()
    kiro = repo / ".kiro"
    policy = baseline / "company" / "policy"
    secret_patterns = load_patterns(policy / "secret-patterns.tsv")
    allow_file = policy / "mcp-allowlist.txt"
    allowlist = {l.strip() for l in allow_file.read_text().splitlines()
                 if l.strip() and not l.startswith("#")} if allow_file.exists() else set()
    guardrail_names = {p.name for p in (baseline / "company" / "steering").glob("company-guardrails-*.md")}
    company_hook_names = set()
    for f in (baseline / "company" / "hooks").glob("*.json"):
        company_hook_names |= {h.get("name") for h in json.loads(f.read_text()).get("hooks", [])}

    if not kiro.exists():
        rep.warn(repo, "no .kiro/ folder; run './setup.sh scaffold <repo>' from kiro-ai-baseline")
        return rep.emit()

    marker = kiro / "company-baseline.json"
    if not marker.exists():
        rep.warn(marker, "missing; repo was not scaffolded by kiro-ai-baseline")
    else:
        try:
            m = json.loads(marker.read_text())
            cur = (baseline / "VERSION").read_text().strip()
            if m.get("baselineVersion", "0").split(".")[0] != cur.split(".")[0]:
                rep.warn(marker, f"scaffolded with baseline {m.get('baselineVersion')}; current is {cur}. Re-run scaffold to pick up template changes.")
        except (json.JSONDecodeError, OSError) as err:
            rep.err(marker, f"invalid JSON: {err}")

    steering = sorted((kiro / "steering").rglob("*.md")) if (kiro / "steering").exists() else []
    for f in steering:
        check_steering(f, rep, central=False)
        if f.name.startswith("company-guardrails-") or f.name in guardrail_names:
            rep.err(f, "shadows a company guardrail; guardrails cannot be overridden in team repos")
        elif f.name.startswith("company-defaults-"):
            rep.warn(f, "overrides a company default (allowed); make sure the team agreed")
        elif f.name.startswith("company-"):
            rep.err(f, "the 'company-' prefix is reserved for the baseline")
        if TIER_RE.search(f.read_text(encoding="utf-8") or "") and "tier: guardrail" in f.read_text(encoding="utf-8").lower():
            rep.err(f, "team files cannot declare tier: guardrail")

    for f in sorted((kiro / "hooks").glob("*.json")) if (kiro / "hooks").exists() else []:
        for name in check_hook_file(f, rep, central=False):
            if name in company_hook_names:
                rep.err(f, f"hook name '{name}' collides with a company guardrail hook")
        if f.name.startswith("company-"):
            rep.err(f, "the 'company-' prefix is reserved for the baseline")

    if (kiro / "skills").exists():
        for d in sorted(p for p in (kiro / "skills").iterdir() if p.is_dir()):
            check_skill_dir(d, rep)
            if d.name.startswith("company-"):
                rep.warn(d, "overrides a company skill (allowed for defaults)")

    mcp = kiro / "settings" / "mcp.json"
    if mcp.exists():
        check_mcp(mcp, rep, allowlist=allowlist, central=False)

    agents = [p for p in repo.rglob("AGENTS.md") if ".git" not in p.parts and "node_modules" not in p.parts]
    skill_files = list((kiro / "skills").rglob("*.md")) if (kiro / "skills").exists() else []
    hook_files = list((kiro / "hooks").glob("*.json")) if (kiro / "hooks").exists() else []
    scan_override_language(steering + agents + skill_files + hook_files, rep)
    all_kiro = [p for p in kiro.rglob("*") if p.is_file()]
    scan_secrets(all_kiro + agents, rep, secret_patterns)
    return rep.emit()


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="mode", required=True)
    c = sub.add_parser("central")
    c.add_argument("--root", default=str(Path(__file__).resolve().parent.parent))
    t = sub.add_parser("team")
    t.add_argument("--repo", default=".")
    t.add_argument("--baseline", default=str(Path(__file__).resolve().parent.parent))
    a = ap.parse_args()
    if a.mode == "central":
        return lint_central(Path(a.root).resolve())
    return lint_team(Path(a.repo).resolve(), Path(a.baseline).resolve())


if __name__ == "__main__":
    sys.exit(main())
