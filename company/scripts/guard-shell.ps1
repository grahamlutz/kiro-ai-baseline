# managed by kiro-ai-baseline: do not edit locally
# Kiro PreToolUse hook (shell tools), Windows version of guard-shell.sh.
# Blocks commands matching ..\policy\blocked-commands.tsv (non-zero exit blocks).
$ErrorActionPreference = 'Stop'
$policy = Join-Path $PSScriptRoot '..\policy\blocked-commands.tsv'
if (-not (Test-Path $policy)) { exit 0 }

$payload = [Console]::In.ReadToEnd()
$text = $payload
try {
    $d = $payload | ConvertFrom-Json
    $ti = $d.tool_input
    if ($null -eq $ti) { $ti = $d.toolInput }
    if ($null -ne $ti) {
        if ($ti -is [string]) { $text = $ti }
        elseif ($ti.command) { $text = [string]$ti.command }
        elseif ($ti.cmd) { $text = [string]$ti.cmd }
        else { $text = ($ti | ConvertTo-Json -Depth 10 -Compress) }
    }
} catch { $text = $payload }

foreach ($line in Get-Content -LiteralPath $policy) {
    if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) { continue }
    $parts = $line -split "`t", 3
    if ($parts.Count -lt 3) { continue }
    $opts = [System.Text.RegularExpressions.RegexOptions]::None
    if ($parts[1] -eq 'i') { $opts = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase }
    if ([regex]::IsMatch($text, $parts[2], $opts)) {
        [Console]::Error.WriteLine("BLOCKED by company guardrail '$($parts[0])' (see ~/.kiro/steering/company-guardrails-security.md).")
        [Console]::Error.WriteLine('Do not retry or work around this. Explain the risk to the user and, if they still want it, give them the exact command to run themselves.')
        exit 2
    }
}
exit 0
