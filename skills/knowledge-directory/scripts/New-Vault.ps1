<#
.SYNOPSIS
  Lay down the Vault skeleton (idempotent, no git — ADR-0002).

.PARAMETER VaultPath
  Target Vault directory. Overrides $env:DANSKILLS_VAULT.

.EXAMPLE
  pwsh -NoProfile -File New-Vault.ps1
#>
[CmdletBinding()]
param(
    [string]$VaultPath = $(if ($env:DANSKILLS_VAULT) { $env:DANSKILLS_VAULT } else { Join-Path $HOME 'OneDrive/agent-knowledge' })
)

$ErrorActionPreference = 'Stop'

if (Test-Path (Join-Path $VaultPath 'log.md')) {
    Write-Host "Vault already exists at $VaultPath — nothing to bootstrap."
    exit 0
}

Write-Host "Bootstrapping Vault at $VaultPath"
New-Item -ItemType Directory -Force -Path $VaultPath | Out-Null
foreach ($container in '0-Projects', '1-Areas', '2-Resources', '3-Archives') {
    New-Item -ItemType Directory -Force -Path (Join-Path $VaultPath $container) | Out-Null
    $stub = Join-Path $VaultPath "$container/index.md"
    if (-not (Test-Path $stub)) {
        "# $($container -replace '^\d-','')`n`n- (no entries yet — ask the knowledge-directory skill to capture something)`n" |
            Set-Content -Path $stub -Encoding utf8NoBOM
    }
}

# Root index: the OKF version declaration lives here.
$rootIndex = Join-Path $VaultPath 'index.md'
if (-not (Test-Path $rootIndex)) {
    Set-Content -Path $rootIndex -Encoding utf8NoBOM -Value @'
---
okf_version: 0.2
---

# Vault index

- [0-Projects](0-Projects/index.md): active efforts
- [1-Areas](1-Areas/index.md): ongoing responsibilities
- [2-Resources](2-Resources/index.md): atomic Ideas and topic Structure Notes
- [3-Archives](3-Archives/index.md): retired material
- [Update log](log.md): what changed, most recent first
- [Type registry](2-Resources/vocabulary.md): the governed `type` vocabulary
'@
}

# Update log: empty, dated headings newest-first when they appear.
$log = Join-Path $VaultPath 'log.md'
if (-not (Test-Path $log)) {
    Set-Content -Path $log -Encoding utf8NoBOM -Value @'
# Update log

_(Agent sessions append `## YYYY-MM-DD` sections here, newest first.)_
'@
}

# Root index: AGENTS.md — the thin agent pointer.
$agents = Join-Path $VaultPath 'AGENTS.md'
if (-not (Test-Path $agents)) {
    Set-Content -Path $agents -Encoding utf8NoBOM -Value @'
# Agent instructions — read llms.txt first

- `llms.txt` maps the Vault and its conventions.
- Every note carries frontmatter `type` (governed: see `2-Resources/vocabulary.md`)
  and an `id` timestamp that addresses it forever.
- Append a line to `log.md` for every significant Vault change.
- The knowledge-directory skill owns maintenance; this file stays thin.
'@
}

# Type registry: seeded with the day-one vocabulary. Governance rules live in-repo.
$vocab = Join-Path $VaultPath '2-Resources/vocabulary.md'
if (-not (Test-Path $vocab)) {
    Set-Content -Path $vocab -Encoding utf8NoBOM -Value @'
---
type: Structure Note
id: "999901010000"
title: Type registry
description: The governed vocabulary of frontmatter `type` values, and how to add to it.
status: draft
---

# Vocabulary

| Type | Meaning | Since |
| --- | --- | --- |
| `Idea` | One atomic idea, our own/agent's distilled words | day one |
| `Project Note` | Active PARA Project's overview note (one per Project dir) | day one |
| `Area Note` | Ongoing Area of responsibility's overview note | day one |
| `Literature Note` | Source extract/summary, feeding Ideas | day one |
| `Structure Note` | Hand-written curated map (MOC) — not the reserved `index.md` | day one |

# Add a type

1. Search this registry first; match on meaning, not string.
2. Reuse-vs-new test — is it a second instance of something here? would making
   new notes grouped by this type ever drive retrieval?
3. Append a row (`Type | Meaning | Since`), Title Case noun, no near-duplicate.
4. Enter the date in the audit log below (the agent mentions each mint in-turn;
   the audit log is the veto channel).

# Audit log

_(Consolidation reviews and de-registrations append dated lines here.)_
'@
}

# Front door: placeholder until the first regeneration.
$frontDoor = Join-Path $VaultPath 'llms.txt'
if (-not (Test-Path $frontDoor)) {
    Set-Content -Path $frontDoor -Encoding utf8NoBOM -Value @'
# Agent knowledge (personal vault)

> Dan's synced personal vault of atomic notes — Projects, Areas, Resources,
> Archives — in OKF format, maintained by the knowledge-directory skill.

_This front door was bootstrapped with placeholder prose; the H2 file lists
below regenerate via `scripts/Update-FrontDoor.ps1`._
'@
}

Write-Host 'Vault skeleton ready. Done.'
