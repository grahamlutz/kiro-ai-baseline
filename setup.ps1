<#
.SYNOPSIS
  kiro-ai-baseline setup for Windows (Windows PowerShell 5.1+ or PowerShell 7+).
  Same behavior as setup.sh. Easiest entry point: setup.cmd

.EXAMPLE
  .\setup.cmd                                  # install / re-sync into %USERPROFILE%\.kiro
  .\setup.cmd update                           # git pull this repo, then re-sync
  .\setup.cmd status                           # installed version and local drift
  .\setup.cmd scaffold ..\my-repo --pack python   # add a team .kiro\ to a repo
  .\setup.cmd packs                            # list stack packs
  .\setup.cmd uninstall                        # remove company-managed files
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)][string]$Command = 'install',
    [Parameter(Position = 1)][string]$Target = '',
    [string[]]$Pack = @(),
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Rest = @()
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$RepoRoot = $PSScriptRoot
$KiroHome = if ($env:KIRO_HOME) { $env:KIRO_HOME } else { Join-Path $HOME '.kiro' }
$State = Join-Path $KiroHome 'company'
$Manifest = Join-Path $State 'manifest.tsv'
$McpNames = Join-Path $State 'mcp-servers.txt'
$Version = (Get-Content -Raw (Join-Path $RepoRoot 'VERSION')).Trim()
$ConfigPath = Join-Path $RepoRoot 'config\org.json'
$OnWindows = ($PSVersionTable.PSEdition -eq 'Desktop') -or ((Get-Variable IsWindows -ErrorAction SilentlyContinue) -and $IsWindows)
$Utf8 = New-Object System.Text.UTF8Encoding $false
$script:BackupDir = ''

# Accept bash-style "--pack x" too, so docs work the same on every OS.
for ($i = 0; $i -lt $Rest.Count; $i++) {
    if ($Rest[$i] -in @('--pack', '-p') -and $i + 1 -lt $Rest.Count) { $Pack += $Rest[$i + 1]; $i++ }
    elseif ($Rest[$i] -like '--pack=*') { $Pack += $Rest[$i].Substring(7) }
    elseif (-not $Target) { $Target = $Rest[$i] }
    else { throw "unknown argument $($Rest[$i])" }
}
if ($Target -in @('--pack', '-p')) { throw 'usage: setup.cmd scaffold <repo-dir> --pack <name>' }

function Ok($m)   { Write-Host "[ok] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "[!]  $m" -ForegroundColor Yellow }
function Die($m)  { Write-Host "[x]  $m" -ForegroundColor Red; exit 1 }
function Log($m)  { Write-Host $m }

function Read-Json($path, $default) {
    if (-not (Test-Path -LiteralPath $path)) { return $default }
    $raw = [System.IO.File]::ReadAllText($path)
    if ([string]::IsNullOrWhiteSpace($raw)) { return $default }
    return $raw | ConvertFrom-Json
}
function Write-Json($path, $obj) {
    New-Item -ItemType Directory -Force -Path (Split-Path $path) | Out-Null
    [System.IO.File]::WriteAllText($path, (($obj | ConvertTo-Json -Depth 30) + "`n"), $Utf8)
}
function Write-Text($path, $text) {
    New-Item -ItemType Directory -Force -Path (Split-Path $path) | Out-Null
    [System.IO.File]::WriteAllText($path, $text, $Utf8)
}
function Set-Prop($obj, $name, $value) {
    if ($obj.PSObject.Properties[$name]) { $obj.$name = $value }
    else { $obj | Add-Member -NotePropertyName $name -NotePropertyValue $value }
}
function Get-Dotted($obj, [string]$dotted) {
    $cur = $obj
    foreach ($p in $dotted.Split('.')) {
        if ($null -eq $cur -or -not $cur.PSObject.Properties[$p]) { return '' }
        $cur = $cur.$p
    }
    return $cur
}
function Get-Sha($path) { (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant() }
function Get-Rel($root, $full) { $full.Substring($root.TrimEnd('\', '/').Length + 1).Replace('\', '/') }
function Read-Manifest {
    $m = @{}
    if (Test-Path $Manifest) {
        foreach ($l in Get-Content -LiteralPath $Manifest) {
            $p = $l -split "`t", 2; if ($p.Count -eq 2) { $m[$p[1]] = $p[0] }
        }
    }
    return $m
}
function Backup-Rel($rel) {
    if (-not $script:BackupDir) { $script:BackupDir = Join-Path $State ('backups\' + (Get-Date -Format 'yyyyMMdd-HHmmss')) }
    $dst = Join-Path $script:BackupDir $rel
    New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
    Copy-Item -LiteralPath (Join-Path $KiroHome $rel) -Destination $dst -Force
}

# ---------------------------------------------------------------- install ---
function New-Stage {
    $s = Join-Path ([System.IO.Path]::GetTempPath()) ('kiro-stage-' + [guid]::NewGuid())
    foreach ($d in 'steering', 'skills', 'hooks', 'company\scripts', 'company\policy') {
        New-Item -ItemType Directory -Force -Path (Join-Path $s $d) | Out-Null
    }
    Copy-Item -Recurse -Force (Join-Path $RepoRoot 'company\steering\*') (Join-Path $s 'steering')
    Copy-Item -Recurse -Force (Join-Path $RepoRoot 'company\skills\*') (Join-Path $s 'skills')
    Copy-Item -Recurse -Force (Join-Path $RepoRoot 'company\policy\*') (Join-Path $s 'company\policy')
    $ext = if ($OnWindows) { 'ps1' } else { 'sh' }
    Copy-Item -Force (Join-Path $RepoRoot "company\scripts\*.$ext") (Join-Path $s 'company\scripts')

    foreach ($f in Get-ChildItem (Join-Path $RepoRoot 'company\hooks') -Filter *.json) {
        $hook = Read-Json $f.FullName $null
        foreach ($h in $hook.hooks) {
            if ($h.action.PSObject.Properties['command']) {
                $h.action.command = [regex]::Replace($h.action.command, '\{\{RUN:([A-Za-z0-9_-]+)\}\}', {
                    param($m)
                    $scriptPath = Join-Path (Join-Path $State 'scripts') ($m.Groups[1].Value + ".$ext")
                    if ($OnWindows) { "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" } else { "sh `"$scriptPath`"" }
                })
            }
        }
        Write-Json (Join-Path $s "hooks\$($f.Name)") $hook
    }
    Write-Text (Join-Path $s 'company\README.md') @"
This folder is managed by kiro-ai-baseline ($Version).
Do not edit files here or the company-* files in ~/.kiro/steering, ~/.kiro/skills,
and ~/.kiro/hooks: they are overwritten by 'setup.cmd update'.
Source: $RepoRoot
"@
    return $s
}

function Sync-Stage($s) {
    $old = Read-Manifest
    $new = New-Object System.Collections.Generic.List[string]
    $seen = @{}
    $changed = 0
    foreach ($f in Get-ChildItem -LiteralPath $s -Recurse -File | Sort-Object FullName) {
        $rel = Get-Rel $s $f.FullName
        $dest = Join-Path $KiroHome $rel
        $newHash = Get-Sha $f.FullName
        if (Test-Path -LiteralPath $dest) {
            $cur = Get-Sha $dest
            if ($cur -ne $newHash) {
                if (-not $old.ContainsKey($rel)) { Backup-Rel $rel; Warn "replaced existing file ~/.kiro/$rel (backup kept)" }
                elseif ($cur -ne $old[$rel]) { Backup-Rel $rel; Warn "local edits to managed file ~/.kiro/$rel were backed up and replaced" }
                $changed++
            }
        } else { $changed++ }
        New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
        Copy-Item -LiteralPath $f.FullName -Destination $dest -Force
        $new.Add("$newHash`t$rel"); $seen[$rel] = $true
    }
    foreach ($rel in $old.Keys) {
        if ($seen.ContainsKey($rel)) { continue }
        $p = Join-Path $KiroHome $rel
        if (Test-Path -LiteralPath $p) {
            if ((Get-Sha $p) -ne $old[$rel]) { Backup-Rel $rel }
            Remove-Item -LiteralPath $p -Force
            Log "  removed retired file ~/.kiro/$rel"
        }
    }
    Write-Text $Manifest (($new -join "`n") + "`n")
    Ok "company files synced ($changed changed)"
}

function Merge-Mcp {
    $userPath = Join-Path $KiroHome 'settings\mcp.json'
    try { $user = Read-Json $userPath $null } catch { Die "$userPath is not valid JSON. Fix it and re-run; nothing was changed." }
    if ($null -eq $user) { $user = [pscustomobject]@{ mcpServers = [pscustomobject]@{} } }
    if (-not $user.PSObject.Properties['mcpServers']) { Set-Prop $user 'mcpServers' ([pscustomobject]@{}) }
    if (Test-Path $userPath) { Backup-Rel 'settings/mcp.json' }

    $prev = @{}
    # names file: "<server>`t<managed|gated-off>" per line
    if (Test-Path $McpNames) {
        foreach ($l in Get-Content $McpNames) {
            $p = $l.Trim() -split "`t"
            if ($p[0]) { $prev[$p[0]] = $(if ($p.Count -gt 1) { $p[1] } else { 'managed' }) }
        }
    }
    $states = @{}
    $cfg = Read-Json $ConfigPath ([pscustomobject]@{})
    $company = Read-Json (Join-Path $RepoRoot 'company\settings\mcp.json') $null
    $names = @()
    Log 'MCP servers (merged into ~/.kiro/settings/mcp.json; your personal servers are kept):'
    foreach ($prop in $company.mcpServers.PSObject.Properties) {
        $name = $prop.Name; $names += $name
        $script:missing = 0
        $json = $prop.Value | ConvertTo-Json -Depth 30
        $json = [regex]::Replace($json, '\{\{\s*([A-Za-z0-9_.]+)\s*\}\}', {
            param($m)
            $v = [string](Get-Dotted $cfg $m.Groups[1].Value)
            if (-not $v) { $script:missing++ }
            ($v | ConvertTo-Json).Trim('"')
        })
        $server = $json | ConvertFrom-Json
        $gated = $cfg.PSObject.Properties['connectors'] -and $cfg.connectors.PSObject.Properties[$name]
        $configured = $null
        if ($gated) {
            $configured = [bool]$cfg.connectors.$name.enabled -and ($script:missing -eq 0)
            Set-Prop $server 'disabled' (-not $configured)
        }
        $existing = $user.mcpServers.PSObject.Properties[$name]
        if ($existing -and -not $prev.ContainsKey($name)) { Warn "personal MCP server '$name' replaced by the company definition (backup saved)." }
        if ($existing -and $prev[$name] -eq 'managed' -and $existing.Value.PSObject.Properties['disabled'] -and ($configured -ne $false)) {
            Set-Prop $server 'disabled' $existing.Value.disabled
        }
        $states[$name] = $(if ($configured -eq $false) { 'gated-off' } else { 'managed' })
        Set-Prop $user.mcpServers $name $server
        $stateTxt = if ($server.disabled) { 'disabled' } else { 'enabled' }
        $note = if ($configured -eq $false) { ' (awaiting admin setup: see docs/admin-setup.md)' } else { '' }
        Log ('  mcp: {0,-14} {1}{2}' -f $name, $stateTxt, $note)
    }
    foreach ($n in $prev.Keys) {
        if ($names -notcontains $n -and $user.mcpServers.PSObject.Properties[$n]) {
            $user.mcpServers.PSObject.Properties.Remove($n); Log "  mcp: $n removed (retired from company baseline)"
        }
    }
    Write-Json $userPath $user
    Write-Text $McpNames ((($names | Sort-Object | ForEach-Object { "$_`t$($states[$_])" }) -join "`n") + "`n")
}

function Invoke-Install {
    if (-not (Test-Path $ConfigPath)) { Die "missing $ConfigPath" }
    Log "Installing kiro-ai-baseline $Version into $KiroHome"
    New-Item -ItemType Directory -Force -Path $State, (Join-Path $KiroHome 'settings') | Out-Null
    $prevVersion = if (Test-Path (Join-Path $State 'version')) { (Get-Content -Raw (Join-Path $State 'version')).Trim() } else { '' }
    $stage = New-Stage
    try { Sync-Stage $stage } finally { Remove-Item -Recurse -Force $stage }
    Merge-Mcp
    Write-Text (Join-Path $State 'version') "$Version`n"
    Write-Text (Join-Path $State 'source') "$RepoRoot`n"
    if ($script:BackupDir) { Log "  backups: $($script:BackupDir)" }
    if ($prevVersion -and $prevVersion -ne $Version) { Ok "upgraded $prevVersion -> $Version" } else { Ok "installed $Version" }
    Log ''
    Log 'Next steps'
    if (-not $env:GITHUB_PERSONAL_ACCESS_TOKEN) {
        Log '  1. Create a fine-grained GitHub PAT and store it as a user environment variable:'
        Log '       setx GITHUB_PERSONAL_ACCESS_TOKEN "<token>"   (then open a new terminal)'
    } else { Log '  1. GITHUB_PERSONAL_ACCESS_TOKEN is set' }
    Log "  2. Restart Kiro. When it asks, approve the env var GITHUB_PERSONAL_ACCESS_TOKEN"
    Log "     (Settings -> 'Mcp Approved Env Vars')."
    Log '  3. In the Kiro panel -> MCP servers, sign in to Atlassian (browser OAuth).'
    Log '  4. In any repo: .\setup.cmd scaffold <path-to-repo> --pack python'
    Log '  Keep current with: .\setup.cmd update'
}

# ----------------------------------------------------------------- update ---
function Invoke-Update {
    $isGit = $false
    try { git -C $RepoRoot rev-parse --is-inside-work-tree 2>$null | Out-Null; $isGit = ($LASTEXITCODE -eq 0) } catch { }
    if ($isGit) {
        if (git -C $RepoRoot status --porcelain) { Die "this clone has local changes. Commit, stash, or discard them (git -C `"$RepoRoot`" status), then re-run update." }
        Log 'Pulling latest kiro-ai-baseline...'
        git -C $RepoRoot pull --ff-only --quiet
        if ($LASTEXITCODE -ne 0) { Die "git pull failed. Resolve it in $RepoRoot and re-run." }
    } else { Warn "$RepoRoot is not a git clone; re-syncing local files only." }
    & (Join-Path $RepoRoot 'setup.ps1') install   # fresh parse of the pulled script
}

# ----------------------------------------------------------------- status ---
function Invoke-Status {
    $installed = if (Test-Path (Join-Path $State 'version')) { (Get-Content -Raw (Join-Path $State 'version')).Trim() } else { 'not installed' }
    Log 'kiro-ai-baseline'
    Log "  installed: $installed   (repo: $Version)   KIRO_HOME: $KiroHome"
    try {
        git -C $RepoRoot fetch --quiet 2>$null
        if ($LASTEXITCODE -eq 0 -and (git -C $RepoRoot rev-list 'HEAD..@{u}' 2>$null)) { Warn 'a newer baseline is available: run .\setup.cmd update' }
    } catch { }
    $m = Read-Manifest; $drift = $false
    foreach ($rel in $m.Keys) {
        $p = Join-Path $KiroHome $rel
        if (-not (Test-Path -LiteralPath $p)) { Warn "missing: ~/.kiro/$rel"; $drift = $true }
        elseif ((Get-Sha $p) -ne $m[$rel]) { Warn "locally modified: ~/.kiro/$rel"; $drift = $true }
    }
    if ($m.Count -gt 0 -and -not $drift) { Ok "all $($m.Count) managed files match" }
    if ($drift) { Log '  run .\setup.cmd to restore managed files' }
}

# ------------------------------------------------------------------ packs ---
function Invoke-Packs {
    Log 'Available stack packs'
    foreach ($d in Get-ChildItem (Join-Path $RepoRoot 'packs') -Directory) {
        if ($d.Name -eq '_template') { continue }
        $pj = Join-Path $d.FullName 'pack.json'
        if (Test-Path $pj) { Log ('  {0,-14} {1}' -f $d.Name, (Read-Json $pj $null).description) }
    }
}

# --------------------------------------------------------------- scaffold ---
function Copy-IfAbsent($src, $dest, $label) {
    if (Test-Path -LiteralPath $dest) { Log "  kept     $label (already exists)" }
    else {
        New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
        Copy-Item -LiteralPath $src -Destination $dest; Log "  created  $label"
    }
}

function Invoke-Scaffold {
    if (-not $Target) { Die 'usage: .\setup.cmd scaffold <repo-dir> [--pack <name>]...' }
    if (-not (Test-Path -LiteralPath $Target -PathType Container)) { Die "$Target is not a directory" }
    $t = (Resolve-Path -LiteralPath $Target).Path
    if ($t.TrimEnd('\', '/') -eq $RepoRoot.TrimEnd('\', '/')) { Die 'scaffold a team repo, not the baseline repo itself' }
    try { git -C $t rev-parse --is-inside-work-tree 2>$null | Out-Null; if ($LASTEXITCODE -ne 0) { Warn "$t is not a git repo" } } catch { Warn "$t is not a git repo" }
    $packs = @($Pack | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
    foreach ($p in $packs) {
        if ($p -eq '_template' -or -not (Test-Path (Join-Path $RepoRoot "packs\$p\pack.json"))) { Die "unknown pack '$p' (see .\setup.cmd packs)" }
    }

    Log "Scaffolding $t"
    $cfg = Read-Json $ConfigPath ([pscustomobject]@{})
    $ref = 'v' + $Version.Split('.')[0]
    $tpl = Join-Path $RepoRoot 'templates\team'
    foreach ($f in Get-ChildItem -LiteralPath $tpl -Recurse -File -Force | Sort-Object FullName) {
        $rel = Get-Rel $tpl $f.FullName
        $dest = Join-Path $t $rel
        if ($rel -eq '.github/workflows/kiro-guardrails.yml' -and -not (Test-Path -LiteralPath $dest)) {
            $txt = [System.IO.File]::ReadAllText($f.FullName).Replace('{{BASELINE_REPO}}', [string]$cfg.baselineRepo).Replace('{{BASELINE_REF}}', $ref)
            Write-Text $dest $txt; Log "  created  $rel"
        } else { Copy-IfAbsent $f.FullName $dest $rel }
    }
    foreach ($p in $packs) {
        $pdir = Join-Path $RepoRoot "packs\$p"
        Log "  pack: $p"
        foreach ($sub in 'steering', 'hooks', 'skills') {
            $sd = Join-Path $pdir $sub
            if (-not (Test-Path $sd)) { continue }
            foreach ($f in Get-ChildItem -LiteralPath $sd -Recurse -File -Force | Sort-Object FullName) {
                if ($f.Name -eq '.gitkeep') { continue }
                $rel = ".kiro/$sub/" + (Get-Rel $sd $f.FullName)
                Copy-IfAbsent $f.FullName (Join-Path $t $rel) $rel
            }
        }
        $pm = Join-Path $pdir 'settings\mcp.json'
        if (Test-Path $pm) {
            $repoMcpPath = Join-Path $t '.kiro\settings\mcp.json'
            $repoMcp = Read-Json $repoMcpPath ([pscustomobject]@{ mcpServers = [pscustomobject]@{} })
            foreach ($sp in (Read-Json $pm $null).mcpServers.PSObject.Properties) {
                if (-not $repoMcp.mcpServers.PSObject.Properties[$sp.Name]) { Set-Prop $repoMcp.mcpServers $sp.Name $sp.Value }
            }
            Write-Json $repoMcpPath $repoMcp; Log '  merged   .kiro/settings/mcp.json (pack servers)'
        }
        foreach ($req in @((Read-Json (Join-Path $pdir 'pack.json') $null).requires)) {
            if ($req -and -not (Get-Command $req -ErrorAction SilentlyContinue)) { Warn "pack '$p' hooks need '$req' on PATH (install it, or set `"enabled`": false in the hook)" }
        }
    }
    $bp = Join-Path $t '.kiro\company-baseline.json'
    $b = Read-Json $bp ([pscustomobject]@{})
    $now = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    $allPacks = @(@($(if ($b.PSObject.Properties['packs']) { $b.packs } else { @() })) + $packs | Where-Object { $_ } | Sort-Object -Unique)
    Set-Prop $b '$comment' 'Written by kiro-ai-baseline scaffold. Used by the kiro-guardrails CI check.'
    Set-Prop $b 'baselineVersion' $Version
    Set-Prop $b 'packs' ([object[]]$allPacks)
    Set-Prop $b 'updatedAt' $now
    if (-not $b.PSObject.Properties['scaffoldedAt']) { Set-Prop $b 'scaffoldedAt' $now }
    Write-Json $bp $b
    Log '  wrote    .kiro/company-baseline.json'
    Ok 'scaffold complete'
    Log ''
    Log 'Next steps'
    Log '  1. Fill in the TODOs in .kiro/steering/{product,tech,structure}.md'
    Log "     (or ask Kiro: 'Update the steering docs for this repo')."
    Log '  2. Commit .kiro/ and .github/workflows/kiro-guardrails.yml and open a PR.'
    Log '  3. Never commit secrets in .kiro/settings/mcp.json; use ${ENV_VAR} references.'
}

# -------------------------------------------------------------- uninstall ---
function Invoke-Uninstall {
    $m = Read-Manifest
    if ($m.Count -eq 0) { Die "nothing to uninstall (no manifest at $Manifest)" }
    foreach ($rel in $m.Keys) {
        $p = Join-Path $KiroHome $rel
        if (-not (Test-Path -LiteralPath $p)) { continue }
        if ((Get-Sha $p) -ne $m[$rel]) { Backup-Rel $rel }
        Remove-Item -LiteralPath $p -Force
    }
    $userPath = Join-Path $KiroHome 'settings\mcp.json'
    if ((Test-Path $userPath) -and (Test-Path $McpNames)) {
        Backup-Rel 'settings/mcp.json'
        $user = Read-Json $userPath $null
        foreach ($l in Get-Content $McpNames) {
            $n = ($l -split "`t")[0].Trim()
            if ($n -and $user.mcpServers.PSObject.Properties[$n]) { $user.mcpServers.PSObject.Properties.Remove($n) }
        }
        Write-Json $userPath $user
    }
    foreach ($x in 'scripts', 'policy', 'manifest.tsv', 'mcp-servers.txt', 'version', 'source', 'README.md') {
        $p = Join-Path $State $x; if (Test-Path $p) { Remove-Item -Recurse -Force $p }
    }
    $msg = 'company layer removed. Personal files untouched.'
    if ($script:BackupDir) { $msg += " Backups: $($script:BackupDir)" }
    Ok $msg
}

switch ($Command) {
    'install'   { Invoke-Install }
    'update'    { Invoke-Update }
    'status'    { Invoke-Status }
    'packs'     { Invoke-Packs }
    'scaffold'  { Invoke-Scaffold }
    'uninstall' { Invoke-Uninstall }
    default     { Get-Help $PSCommandPath -Examples; exit 1 }
}
