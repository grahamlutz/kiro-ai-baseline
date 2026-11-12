# Smoke test for setup.ps1 and the PowerShell hook scripts.
# Runs in CI on Windows PowerShell 5.1 and PowerShell 7: ./tests/smoke.ps1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('kiro-smoke-' + [guid]::NewGuid())
$env:KIRO_HOME = Join-Path $tmp '.kiro'
$failures = 0
function Check($cond, $msg) {
    if ($cond) { Write-Host "PASS $msg" -ForegroundColor Green }
    else { Write-Host "FAIL $msg" -ForegroundColor Red; $script:failures++ }
}
function Setup { & (Join-Path $root 'setup.ps1') @args *>&1 | Out-String }

New-Item -ItemType Directory -Force -Path (Join-Path $env:KIRO_HOME 'settings'), (Join-Path $env:KIRO_HOME 'steering') | Out-Null
'{"mcpServers":{"personal":{"command":"x"}}}' | Set-Content (Join-Path $env:KIRO_HOME 'settings\mcp.json')
'# mine' | Set-Content (Join-Path $env:KIRO_HOME 'steering\my-notes.md')

# install
$out = Setup install
Check (Test-Path (Join-Path $env:KIRO_HOME 'steering\company-guardrails-security.md')) 'guardrail steering installed'
Check (Test-Path (Join-Path $env:KIRO_HOME 'steering\my-notes.md')) 'personal steering kept'
$mcp = Get-Content -Raw (Join-Path $env:KIRO_HOME 'settings\mcp.json') | ConvertFrom-Json
Check ($null -ne $mcp.mcpServers.personal) 'personal MCP server kept'
Check ($mcp.mcpServers.github.disabled -eq $false) 'github MCP enabled'
Check ($mcp.mcpServers.slack.disabled -eq $true) 'slack MCP awaiting admin setup'
$hookRaw = [System.IO.File]::ReadAllBytes((Join-Path $env:KIRO_HOME 'hooks\company-guard-shell.json'))
Check (-not ($hookRaw[0] -eq 0xEF -and $hookRaw[1] -eq 0xBB)) 'hook JSON written without BOM'
$hook = Get-Content -Raw (Join-Path $env:KIRO_HOME 'hooks\company-guard-shell.json') | ConvertFrom-Json
Check (-not $hook.hooks[0].action.command.Contains('{{RUN:')) 'hook command rendered'

# idempotent
$out = Setup install
Check ($out -match '\(0 changed\)') 're-install changes nothing'

# drift detection
Add-Content (Join-Path $env:KIRO_HOME 'steering\company-guardrails-security.md') 'tampered'
$out = Setup status
Check ($out -match 'locally modified') 'status detects tampering'
$null = Setup install
Check (-not ((Get-Content -Raw (Join-Path $env:KIRO_HOME 'steering\company-guardrails-security.md')) -match 'tampered')) 'install restores managed file'

# hook scripts (PowerShell versions, run directly)
$guard = Join-Path $root 'company\scripts\guard-shell.ps1'
$shell = if ($PSVersionTable.PSEdition -eq 'Desktop') { 'powershell.exe' } else { 'pwsh' }
foreach ($case in @(@('rm -rf /', 2), @('git push --force origin main', 2), @('terraform apply', 2), @('pytest -q', 0), @('git push origin feat/x', 0))) {
    $payload = (@{ tool_name = 'shell'; tool_input = @{ command = $case[0] } } | ConvertTo-Json -Compress)
    $payload | & $shell -NoProfile -ExecutionPolicy Bypass -File $guard 2>$null | Out-Null
    Check ($LASTEXITCODE -eq $case[1]) "guard-shell.ps1 '$($case[0])' -> $($case[1])"
}
$scan = Join-Path $root 'company\scripts\secret-scan.ps1'
$bad = Join-Path $tmp 'bad.py'; 'password = "hunter2hunter2xx"' | Set-Content $bad  # kiro-secret-scan: allow
$good = Join-Path $tmp 'good.py'; 'password = os.environ["PW"]' | Set-Content $good
& $shell -NoProfile -ExecutionPolicy Bypass -File $scan $bad 2>$null; Check ($LASTEXITCODE -eq 1) 'secret-scan.ps1 flags secret'
& $shell -NoProfile -ExecutionPolicy Bypass -File $scan $good 2>$null; Check ($LASTEXITCODE -eq 0) 'secret-scan.ps1 passes clean file'

# scaffold
$repo = Join-Path $tmp 'svc'; New-Item -ItemType Directory -Force -Path $repo | Out-Null
$null = Setup scaffold $repo --pack python
Check (Test-Path (Join-Path $repo '.kiro\steering\pack-python-standards.md')) 'scaffold installed python pack'
Check (-not ((Get-Content -Raw (Join-Path $repo '.github\workflows\kiro-guardrails.yml')) -match '\{\{')) 'workflow placeholders rendered'
$meta = Get-Content -Raw (Join-Path $repo '.kiro\company-baseline.json') | ConvertFrom-Json
Check (@($meta.packs) -contains 'python') 'baseline marker lists pack'
$py = Get-Command python, python3 -ErrorAction SilentlyContinue | Select-Object -First 1
if ($py) {
    & $py.Source (Join-Path $root 'tools\kiro_lint.py') team --repo $repo | Out-Null
    Check ($LASTEXITCODE -eq 0) 'scaffolded repo passes team lint'
}

# uninstall
$null = Setup uninstall
Check (-not (Test-Path (Join-Path $env:KIRO_HOME 'steering\company-guardrails-security.md'))) 'uninstall removes managed files'
$mcp = Get-Content -Raw (Join-Path $env:KIRO_HOME 'settings\mcp.json') | ConvertFrom-Json
Check (@($mcp.mcpServers.PSObject.Properties.Name) -join ',' -eq 'personal') 'uninstall leaves only personal MCP servers'

Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
if ($failures -gt 0) { Write-Host "$failures failure(s)" -ForegroundColor Red; exit 1 }
Write-Host 'All smoke tests passed' -ForegroundColor Green
