# managed by kiro-ai-baseline: do not edit locally
# Kiro PostFileSave hook, Windows version of secret-scan.sh.
param([string]$File = '')
$ErrorActionPreference = 'Stop'
$policy = Join-Path $PSScriptRoot '..\policy\secret-patterns.tsv'
if (-not (Test-Path $policy)) { exit 0 }

if ([string]::IsNullOrEmpty($File) -or $File.Contains('{{')) {
    $File = ''
    try {
        $d = [Console]::In.ReadToEnd() | ConvertFrom-Json
        foreach ($k in 'file_path', 'filePath', 'path') {
            if ($d.$k) { $File = [string]$d.$k; break }
            if ($d.tool_input -and $d.tool_input.$k) { $File = [string]$d.tool_input.$k; break }
        }
    } catch { }
}
if ([string]::IsNullOrEmpty($File) -or -not (Test-Path -LiteralPath $File -PathType Leaf)) { exit 0 }
if ((Get-Item -LiteralPath $File).Length -gt 1MB) { exit 0 }
if ($File -match '(secret-patterns|blocked-commands)\.tsv$') { exit 0 }

$content = Get-Content -LiteralPath $File -ErrorAction SilentlyContinue
if ($null -eq $content) { exit 0 }
if ($content -isnot [array]) { $content = @($content) }
if (($content -join "`n").Contains([char]0)) { exit 0 }  # binary

$found = $false
foreach ($line in Get-Content -LiteralPath $policy) {
    if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) { continue }
    $parts = $line -split "`t", 3
    if ($parts.Count -lt 3) { continue }
    $opts = [System.Text.RegularExpressions.RegexOptions]::None
    if ($parts[1] -eq 'i') { $opts = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase }
    $hits = @()
    for ($i = 0; $i -lt $content.Count; $i++) {
        $l = [string]$content[$i]
        if ($l.Contains('kiro-secret-scan: allow')) { continue }
        if ([regex]::IsMatch($l, $parts[2], $opts)) { $hits += ($i + 1) }
    }
    if ($hits.Count -gt 0) {
        [Console]::Error.WriteLine("Possible secret ($($parts[0])) in $File at line(s): $($hits -join ',')")
        $found = $true
    }
}
if ($found) {
    [Console]::Error.WriteLine('Company guardrail: remove the secret, read it from an environment variable or the secret manager, and tell the user it may need rotation.')
    exit 1
}
exit 0
