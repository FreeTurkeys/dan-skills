<#
.SYNOPSIS
  MVP vault validator: OKF golden rules + registry warnings + staleness.
  Exit code 1 = errors present; 0 otherwise. (#7 hardens this.)

.DESCRIPTION
  Hard errors (must fix): non-reserved .md without parseable frontmatter;
  empty `type`; registry invariant violations.
  Warnings: unregistered `type`; `log.md` date headings out of order;
  unused registry rows. Flags: >15 in-use types (fat vocabulary).
  Staleness: notes past `stale_after` or marked `status: deprecated`.
  Root tool files (AGENTS.md, README.md) are exempt from Concept rules.
#>
[CmdletBinding()]
param(
    [string]$VaultPath,
    [switch]$Quiet   # errors/warnings only
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'DanSkills.ps1')

$script:errors = 0; $script:warnings = 0
$vaultRoot = $VaultPath
if (-not $vaultRoot) {
    $vaultRoot = Resolve-DanSkillsVault
    if (-not $vaultRoot) {
        Write-Error 'not configured: run Resolve-VaultPath.ps1 for the fix instructions (exit 2).'
        exit 2
    }
}
$vaultRoot = (Get-Item $vaultRoot).FullName.TrimEnd('/', '\')
function Note([string]$severity, [string]$message) {
    if ($severity -eq 'ERROR') { $script:errors++ } elseif ($severity -eq 'WARN') { $script:warnings++ }
    if (-not ($Quiet -and $severity -eq 'INFO')) { "{0,-5} {1}" -f $severity, $message }
}
function Is-Reserved([System.IO.FileInfo]$f) {
    $f.Name -in 'index.md', 'log.md' -or
    ($f.DirectoryName -eq $vaultRoot -and $f.Name -in 'AGENTS.md', 'README.md')
}

### 1. Concept rules: frontmatter + non-empty type
$inUseTypes = @{}
foreach ($md in Get-ChildItem $vaultRoot -Recurse -Filter *.md) {
    if (Is-Reserved $md) { continue }
    $rel = $md.FullName.Substring($vaultRoot.Length).TrimStart('/', '\')
    $raw = Get-Content $md.FullName -Raw
    if ($raw -notmatch '(?s)\A---\r?\n.*?\r?\n---\r?\n') {
        Note 'ERROR' "$rel : frontmatter missing or malformed"
        continue
    }
    if ($raw -notmatch '(?m)^type:\s*(\S.*)$') {
        Note 'ERROR' "$rel : `type` required (non-empty)"
        continue
    }
    $type = $Matches[1].Trim()
    $inUseTypes[$type] = $inUseTypes[$type] + 1

    if ($raw -match '(?m)^id:\s*"(\d{12,14})"$') { $script:hasId = $true }
    if ($raw -notmatch '(?m)^id:\s*"\d{12,14}"$') {
        Note 'WARN' "$rel : Note ID missing/malformed (frontmatter id timestamp)"
    }
    if ($raw -match '(?m)^stale_after:\s*(\S+)') {
        try { if ([datetime]::Parse($Matches[1], $null, 'RoundtripKind') -lt (Get-Date)) {
            Note 'INFO' "$rel : stale — past stale_after ($($Matches[1])) — propose maintenance"
        } } catch { Note 'WARN' "$rel : stale_after not parseable ($($Matches[1]))" }
    }
    if ($raw -match '(?m)^status:\s*deprecated\b') {
        Note 'INFO' "$rel : deprecated — propose retire or re-verify"
    }
}

### 2. Registry checks
$registry = Join-Path $vaultRoot '2-Resources/vocabulary.md'
if (Test-Path $registry) {
    $rows = Get-Content $registry | Select-String -Pattern '^\|\s*`([^`]+)`\s*\|\s*(\S.*?)\s*\|'
    $seen = @{}
    foreach ($row in $rows) {
        $type = $row.Matches[0].Groups[1].Value
        $meaning = $row.Matches[0].Groups[2].Value
        if ($meaning -match '^-{2,}|^\*$') { continue }   # table header/dividers
        $key = $type.ToLowerInvariant()
        if ($seen.ContainsKey($key)) { Note 'ERROR' "registry: '$type' duplicates existing row (case-insensitive)" }
        $seen[$key] = $type
        if (-not $meaning -or $meaning -match '^(N/A|)$') { Note 'ERROR' "registry: '$type' has empty Meaning" }
    }
    foreach ($type in $inUseTypes.Keys) {
        if (-not $seen.ContainsKey($type.ToLowerInvariant())) {
            Note 'WARN' "type '$type' in use ($($inUseTypes[$type]) notes) but not registered — register per '# Add a type' flow"
        }
    }
    foreach ($key in $seen.Keys) {
        $used = $inUseTypes.Keys | Where-Object { $_.ToLowerInvariant() -eq $key }
        if (-not $used) { Note 'WARN' "registry type '$($seen[$key])' unused — report-only (deletion needs explicit say-so)" }
    }
    if ($inUseTypes.Count -gt 15) {
        Note 'WARN' "fat vocabulary: $($inUseTypes.Count) in-use types (>15) — consolidation review due"
    }
} else {
    Note 'WARN' 'no 2-Resources/vocabulary.md — type governance unavailable'
}

### 3. log.md ordering (reserved-file structure)
$logFile = Join-Path $vaultRoot 'log.md'
if (Test-Path $logFile) {
    $dates = Get-Content $logFile | Select-String '^(?:## |- )(\d{4}-\d{2}-\d{2})' |
        ForEach-Object { $_.Matches[0].Groups[1].Value }
    for ($i = 1; $i -lt $dates.Count; $i++) {
        if ($dates[$i] -gt $dates[$i - 1]) { Note 'WARN' 'log.md: date headings not newest-first'; break }
    }
} else {
    Note 'WARN' 'log.md missing (reserved file)'
}

### Summary
"---"
if ($script:errors) {
    Write-Host "NOT CONFORMANT: $($script:errors) error(s), $($script:warnings) warning(s)"
    exit 1
}
Write-Host "OK: conformant (0 errors, $($script:warnings) warning(s), $($inUseTypes.Count) in-use types)"
exit 0
