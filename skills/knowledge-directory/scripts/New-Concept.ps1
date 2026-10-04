<#
.SYNOPSIS
  Scaffold a new Concept: mint the Note ID, refuse collisions, print the path.

.DESCRIPTION
  Mechanics only — the agent fills description/tags/generated and wires links.
  The type is checked against the Vault's registry when the registry file is
  found; unregistered types warn (governance says they must be registered
  before the agent finishes the capture).

.PARAMETER VaultPath
  Optional explicit Vault path (tests, second vaults). Normally resolved from
  ~/.dan-skills/config.json via Resolve-VaultPath.ps1.

.EXAMPLE
  pwsh -NoProfile -File New-Concept.ps1 -Path ~/OneDrive/agent-knowledge/2-Resources -Title "Pointer stability" -Type Idea
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Path,      # the PARA dir (or topic subdir) it goes in
    [Parameter(Mandatory)][string]$Title,     # descriptive, kebab-case applied to filename
    [string]$Type = 'Idea',
    [string]$VaultPath
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'DanSkills.ps1')

$VaultPath = Resolve-DanSkillsVault -VaultPath $VaultPath
if (-not $VaultPath) {
    Write-Error 'not configured: run Resolve-VaultPath.ps1 for the fix instructions (exit 2).'
    exit 2
}

if (-not (Test-Path $Path)) { throw "-Path does not exist: $Path" }

# Filename: kebab-case slug of the title. Clean and descriptive, no ID prefix.
$slug = ($Title -replace "[^A-Za-z0-9 ]", '' -replace ' +' , '-').Trim('-').ToLowerInvariant()
if (-not $slug) { throw "Title produced an empty filename: '$Title'" }
$file = Join-Path $Path "$slug.md"
if (Test-Path $file) { throw "Refusing: $file already exists." }

# Note ID: timestamp, second precision; retry (bounded) if taken.
# (No Select-String -Quiet: it returns a per-candidate array, not a bool.)
$existingIds = @(Get-ChildItem $VaultPath -Recurse -Filter *.md -ErrorAction SilentlyContinue |
    Select-String -Pattern 'id:\s*"(\d{12,14})"' |
    ForEach-Object { $_.Matches[0].Groups[1].Value })
$now = Get-Date
for ($attempt = 0; $attempt -lt 20; $attempt++) {
    $id = $now.ToString('yyyyMMddHHmmss')
    if (-not ($existingIds -contains $id)) { break }
    $now = $now.AddSeconds(1)
}
if ($existingIds -contains $id) { throw "Note ID collision persists after 20 attempts — investigate $VaultPath" }

# Registry check (warn only — enforcement lives in Test-Vault).
$registry = Join-Path $VaultPath '2-Resources/vocabulary.md'
if (Test-Path $registry) {
    if (@(Select-String -Path $registry -SimpleMatch -Pattern "``$Type``").Count -eq 0) {
        Write-Warning "Type '$Type' is not in the registry ($registry) — register it per its '# Add a type' flow before finishing."
    }
}

Set-Content -Path $file -Encoding utf8NoBOM -Value @"
---
type: $Type
id: "$id"
title: $Title
description:
status: draft
generated:
  by: agent            # agent: replace with your model id
  at: $($now.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))
tags: []
---

placeholder
"@

Write-Host "Concept created: $file"
Write-Host "Note ID:          $id"
Write-Host "Fill description/tags/generated.by, wire links, then log it in log.md."
