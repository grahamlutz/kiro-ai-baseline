#!/usr/bin/env python3
"""JSON helpers for setup.sh (setup.ps1 implements the same logic natively).

Subcommands:
  config-get   <org.json> <dotted.key>
  render-hooks <src_dir> <dst_dir> <runner_template> <scripts_dir> <ext>
  merge-mcp    <company_mcp.json> <org.json> <user_mcp.json> <prev_names_file> <names_out_file>
  remove-mcp   <user_mcp.json> <names_file>
  write-baseline <baseline.json> <version> <comma,separated,packs>
  merge-pack-mcp <pack_mcp.json> <repo_mcp.json>

Standard library only, so it runs anywhere python3 exists.
"""
from __future__ import annotations

import datetime as _dt
import json
import os
import re
import sys
from pathlib import Path

PLACEHOLDER = re.compile(r"\{\{\s*([A-Za-z0-9_.]+)\s*\}\}")
RUN_TOKEN = re.compile(r"\{\{RUN:([A-Za-z0-9_-]+)\}\}")


def _load(path: str | Path, default=None):
    p = Path(path)
    if not p.exists() or p.stat().st_size == 0:
        return default
    with p.open(encoding="utf-8") as fh:
        return json.load(fh)


def _dump(path: str | Path, data, private: bool = False) -> None:
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    tmp = p.with_suffix(p.suffix + ".tmp")
    with tmp.open("w", encoding="utf-8", newline="\n") as fh:
        json.dump(data, fh, indent=2)
        fh.write("\n")
    os.replace(tmp, p)
    if private:
        try:
            os.chmod(p, 0o600)
        except OSError:
            pass


def _get(cfg: dict, dotted: str):
    cur = cfg
    for part in dotted.split("."):
        if not isinstance(cur, dict) or part not in cur:
            return ""
        cur = cur[part]
    return cur


def config_get(cfg_path: str, key: str) -> int:
    val = _get(_load(cfg_path, {}), key)
    print(val if not isinstance(val, (dict, list)) else json.dumps(val))
    return 0


def render_hooks(src: str, dst: str, runner: str, scripts_dir: str, ext: str) -> int:
    """Replace {{RUN:name}} with the OS-specific runner for scripts/<name>.<ext>."""
    Path(dst).mkdir(parents=True, exist_ok=True)
    for f in sorted(Path(src).glob("*.json")):
        data = _load(f)
        for hook in data.get("hooks", []):
            action = hook.get("action", {})
            cmd = action.get("command")
            if isinstance(cmd, str):
                def repl(m: re.Match) -> str:
                    script = str(Path(scripts_dir) / f"{m.group(1)}.{ext}")
                    return runner.replace("{script}", script)
                action["command"] = RUN_TOKEN.sub(repl, cmd)
        _dump(Path(dst) / f.name, data)
    return 0


def _render_value(value, cfg: dict, missing: list):
    if isinstance(value, str):
        def repl(m: re.Match) -> str:
            v = _get(cfg, m.group(1))
            if v in ("", None):
                missing.append(m.group(1))
                return ""
            return str(v)
        return PLACEHOLDER.sub(repl, value)
    if isinstance(value, list):
        return [_render_value(v, cfg, missing) for v in value]
    if isinstance(value, dict):
        return {k: _render_value(v, cfg, missing) for k, v in value.items()}
    return value


def render_company_servers(company_path: str, cfg_path: str) -> dict:
    company = _load(company_path, {"mcpServers": {}})
    cfg = _load(cfg_path, {})
    connectors = cfg.get("connectors", {})
    out = {}
    for name, server in company.get("mcpServers", {}).items():
        missing: list = []
        rendered = _render_value(server, cfg, missing)
        gated = name in connectors
        if gated:
            configured = bool(connectors[name].get("enabled")) and not missing
            rendered["disabled"] = not configured
            rendered["_configured"] = configured
        out[name] = rendered
    return out


def merge_mcp(company_path: str, cfg_path: str, user_path: str, prev_names: str, names_out: str) -> int:
    try:
        user = _load(user_path, {"mcpServers": {}})
    except json.JSONDecodeError as err:
        print(f"ERROR: {user_path} is not valid JSON ({err}). Fix it and re-run.", file=sys.stderr)
        return 3
    user.setdefault("mcpServers", {})
    # names file: "<server>\t<managed|gated-off>" per line
    prev: dict[str, str] = {}
    if Path(prev_names).exists():
        for line in Path(prev_names).read_text().splitlines():
            parts = line.strip().split("\t")
            if parts and parts[0]:
                prev[parts[0]] = parts[1] if len(parts) > 1 else "managed"
    states: dict[str, str] = {}

    servers = render_company_servers(company_path, cfg_path)
    for name, new in servers.items():
        configured = new.pop("_configured", None)
        existing = user["mcpServers"].get(name)
        if existing is not None and name not in prev:
            print(f"WARN: personal MCP server '{name}' replaced by the company definition (backup saved).")
        # Keep the engineer's on/off choice for servers we installed before,
        # unless the connector is gated and not yet configured by admins, or it
        # was only off last time because it was awaiting admin setup.
        if (existing is not None and prev.get(name) == "managed"
                and "disabled" in existing and configured is not False):
            new["disabled"] = existing["disabled"]
        states[name] = "gated-off" if configured is False else "managed"
        user["mcpServers"][name] = new
        state = "disabled" if new.get("disabled") else "enabled"
        note = " (awaiting admin setup: see docs/admin-setup.md)" if configured is False else ""
        print(f"  mcp: {name:<14} {state}{note}")

    for name in sorted(set(prev) - set(servers)):
        if name in user["mcpServers"]:
            del user["mcpServers"][name]
            print(f"  mcp: {name:<14} removed (retired from company baseline)")

    _dump(user_path, user, private=True)
    Path(names_out).write_text("".join(f"{n}\t{states[n]}\n" for n in sorted(servers)), encoding="utf-8")
    return 0


def remove_mcp(user_path: str, names_file: str) -> int:
    user = _load(user_path, None)
    if not user or not Path(names_file).exists():
        return 0
    names = {l.split("\t")[0].strip() for l in Path(names_file).read_text().splitlines() if l.strip()}
    for n in names:
        user.get("mcpServers", {}).pop(n, None)
    _dump(user_path, user, private=True)
    return 0


def write_baseline(path: str, version: str, packs_csv: str) -> int:
    data = _load(path, {}) or {}
    packs = sorted(set(data.get("packs", [])) | {p for p in packs_csv.split(",") if p})
    now = _dt.datetime.now(_dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    data.update({
        "$comment": "Written by kiro-ai-baseline scaffold. Used by the kiro-guardrails CI check.",
        "baselineVersion": version,
        "packs": packs,
        "updatedAt": now,
    })
    data.setdefault("scaffoldedAt", now)
    _dump(path, data)
    return 0


def merge_pack_mcp(pack_path: str, repo_path: str) -> int:
    pack = _load(pack_path, {"mcpServers": {}})
    repo = _load(repo_path, {"mcpServers": {}})
    repo.setdefault("mcpServers", {})
    for name, server in pack.get("mcpServers", {}).items():
        repo["mcpServers"].setdefault(name, server)
    _dump(repo_path, repo)
    return 0


def main(argv: list[str]) -> int:
    if not argv:
        print(__doc__)
        return 1
    cmd, args = argv[0], argv[1:]
    table = {
        "config-get": (config_get, 2),
        "render-hooks": (render_hooks, 5),
        "merge-mcp": (merge_mcp, 5),
        "remove-mcp": (remove_mcp, 2),
        "write-baseline": (write_baseline, 3),
        "merge-pack-mcp": (merge_pack_mcp, 2),
    }
    if cmd not in table or len(args) != table[cmd][1]:
        print(__doc__, file=sys.stderr)
        return 1
    return table[cmd][0](*args)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
