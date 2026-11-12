# Admin setup and rollout runbook

Everything an admin needs to do **once** before engineers run `setup`. Each
item lists who does it and what it unlocks.

## 0. Make this repo yours (AI Enablement, ~30 min)
- [ ] Create `kiro-ai-baseline` in your GitHub org (internal visibility recommended).
- [ ] Edit `config/org.json`: `orgName`, `baselineRepo` (`<org>/kiro-ai-baseline`), team handles.
- [ ] Replace `acme` in `README.md`, `.github/CODEOWNERS`, `packs/python/pack.json`, and the
      `baseline-repo` default in `.github/workflows/kiro-guardrails-reusable.yml`.
- [ ] Replace the `TODO(ai-enablement)` data classification text in
      `company/steering/company-guardrails-data-handling.md` with your real policy.
- [ ] Protect `main`: require PR + CODEOWNERS review + `ci` checks.
- [ ] Tag the first release: `git tag v0.1.0 && git push --tags` (creates `v0`, which team CI pins to).

## 1. Team-repo CI access to this repo (GitHub org admin)
The `kiro-guardrails` check in every team repo checks out this repo to get the
lint and policy files. A private or internal repo needs a read credential:

1. Create a GitHub App, e.g. **kiro-baseline-reader**, with permission
   *Repository → Contents: Read-only*. No webhooks are needed.
2. Install it on **only** the `kiro-ai-baseline` repo.
3. Add org secrets `KIRO_BASELINE_APP_ID` and `KIRO_BASELINE_APP_PRIVATE_KEY`, visible to all repositories.
4. In this repo, go to **Settings → Actions → General → Access** and allow access from repositories in the organization,
   so team repos can call the reusable workflow.

Team workflows pass `secrets: inherit`, so nothing else is needed per repo.

## 2. GitHub MCP (enabled by default)
- **Engineers:** create a fine-grained PAT with read access to the repos they work in, and export it as
  `GITHUB_PERSONAL_ACCESS_TOKEN`. The installer prints these steps.
- **Org admin:** if you use Enterprise Managed Users, enable PATs for the enterprise,
  and set a PAT policy (max lifetime, approval) under **Org settings → Personal access tokens**.
- **To drop PATs entirely:** register a GitHub OAuth app and add an `oauth.clientId` to the
  `github` entry in `company/settings/mcp.json`. Kiro needs pre-registered client credentials for
  GitHub because GitHub doesn't support dynamic client registration.

## 3. Atlassian (Jira + Confluence), enabled by default
Uses Atlassian's hosted Rovo MCP server (`https://mcp.atlassian.com/v1/mcp`) with
browser OAuth. Access follows each user's existing Jira and Confluence permissions.
- **Atlassian org admin:** make sure the Rovo MCP server is allowed for your site in
  admin.atlassian.com. If you use IP allowlisting, allow it for the MCP server.
- Atlassian Cloud only. For Data Center, swap in a self-hosted Atlassian MCP server.

## 4. Slack (ships disabled)
Slack's official MCP server (`https://mcp.slack.com/mcp`) requires your own Slack app.

1. **Slack workspace admin:** go to api.slack.com/apps → *Create New App* → *From scratch*, in your workspace.
2. Under **Features**, turn on the **Model Context Protocol** toggle. MCP is only permitted on internal or directory apps.
3. Under **OAuth & Permissions**:
   - Redirect URL: `http://127.0.0.1:7778/oauth/callback`. This must match
     `connectors.slack.redirectPort` in `config/org.json`.
   - Add only the **user token scopes** you're comfortable with. Start read-only, with search and channel history.
4. Copy the **Client ID** into `config/org.json` → `connectors.slack.clientId`, and set `"enabled": true`.
5. Merge and release. Engineers run `setup update`, and Slack turns on for everyone who hasn't opted out.

**The client secret.** Slack's server uses confidential OAuth, so it needs a client
secret, and Kiro's IDE currently supports public OAuth clients only. Pick one route:
- **Recommended:** run a company MCP gateway (for example LiteLLM, MintMCP, or TrueFoundry)
  that holds the Slack secret. Point the `slack` entry's `url` at the gateway instead of `mcp.slack.com`.
  This also gives you central audit logs and per-tool allowlisting.
- **Kiro CLI users:** add `"clientSecret"` to the `oauth` block in their **personal**
  `~/.kiro/settings/mcp.json`. Never commit it to this repo.

Validate whichever route you pick with a pilot user before announcing.

## 5. Microsoft 365: Outlook Calendar, Excel, Word (ships disabled)
Uses [`@softeria/ms-365-mcp-server`](https://github.com/Softeria/ms-365-mcp-server), pinned in
`company/settings/mcp.json`. It runs locally through `npx` and uses delegated
Microsoft Graph permissions, so every call runs as the signed-in user.

1. **Security:** review the pinned server version, then record the approval. Bump the pin deliberately.
2. **Entra admin:** go to entra.microsoft.com → App registrations → *New registration*:
   - Name: `Kiro M365 MCP`. Account types: single tenant.
   - Platform: **Mobile and desktop applications** (public client, no secret).
3. List the exact Graph permissions the configured presets need:
   ```bash
   npx -y @softeria/ms-365-mcp-server@0.179.1 --org-mode --preset calendar,excel,files --list-permissions
   ```
   Add those as **delegated** permissions, then **Grant admin consent**.
   Consider adding `--read-only` to the args in `company/settings/mcp.json` for the pilot.
4. Put the **Directory (tenant) ID** and **Application (client) ID** into `config/org.json` →
   `connectors.microsoft365`, and set `"enabled": true`. Release.
5. Engineers need Node.js 18+ for `npx`.

**Word coverage.** The `files` preset finds and reads Word documents in
OneDrive and SharePoint. For in-place Word editing, Microsoft's own Word MCP
server (Agent 365) is the route; it requires Microsoft 365 Copilot licenses.
Swap the `microsoft365` entry once you're licensed.

## 6. Distribution options beyond `git clone`
Kiro also supports pushing global steering to laptops with MDM or Group Policy. Once
the baseline is stable, the same `setup` command can be run by your MDM agent
(set `KIRO_HOME` if needed). See the roadmap.

## 7. Rollout checklist
- [ ] Pilot with 5–10 engineers across macOS, Windows, and Linux, and at least one Python team.
- [ ] Confirm in Kiro: steering shows under *Agent Steering & Skills*, hooks appear in
      *Agent Hooks*, GitHub and Atlassian MCP connect, and `rm -rf /` gets blocked in chat.
- [ ] Scaffold 2–3 pilot repos; confirm the `kiro-guardrails` check runs on a PR.
- [ ] Announce with the Quick start, and hold office hours.
- [ ] Make `kiro-guardrails` a required check through an org ruleset once repos are scaffolded.
