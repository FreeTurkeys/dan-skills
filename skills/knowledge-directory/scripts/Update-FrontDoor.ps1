<#
.SYNOPSIS
  Regenerate the llms.txt Front door. Script owns the H2 file lists; the
  agent owns the H1, blockquote, and prose sections.

.DESCRIPTION
  Everything before the first H2 is preserved verbatim. H2 file lists are
  regenerated: Start here, Concepts (PARA indexes + discovered Structure
  Notes), Conventions, Optional (Type registry + computed type-audit line).
  The audit line reads the registry's audit log for the last dated entry;
  due = +90 days.
.PARAMETER VaultPath
  Optional explicit Vault path. Normally resolved from
  ~/.dan-skills/config.json via Resolve-VaultPath.ps1.
#>
[CmdletBinding()]
param(
    [string]$VaultPath
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'DanSkills.ps1')

$vaultRoot = $VaultPath
if (-not $vaultRoot) {
    $vaultRoot = Resolve-DanSkillsVault
    if (-not $vaultRoot) {
        Write-Error 'not configured: run Resolve-VaultPath.ps1 for the fix instructions (exit 2).'
        exit 2
    }
}

$frontDoorPath = Join-Path $vaultRoot 'llms.txt'
if (-not (Test-Path $frontDoorPath)) {
    throw "No llms.txt at $vaultRoot — bootstrap first (New-Vault.ps1)."
}

$vaultRoot = (Get-Item $vaultRoot).FullName.TrimEnd('/', '\')

### 1. Preserve agent-owned prose (everything before the first `## `)
$existing = Get-Content $frontDoorPath -Raw
$proseEnd = if ($existing) { $existing.IndexOf("`n## ") } else { -1 }
$prose = if (-not $existing) {
    # Empty or prose-less front door (installer stub): write a minimal H1 and
    # blockquote; the agent owns the wording from here on.
    @"
# Agent knowledge (personal vault)

> Dan's synced personal vault of atomic notes — Projects, Areas, Resources,
> Archives — in OKF format, maintained by the knowledge-directory skill.
"@
}
elseif ($proseEnd -lt 0) { $existing.TrimEnd() }
else { $existing.Substring(0, $proseEnd).TrimEnd() }

### 2. Discover Structure Notes (type: Structure Note) outside reserved index files
$structureNotes = foreach ($md in Get-ChildItem $vaultRoot -Recurse -Filter *.md) {
    if ($md.Name -eq 'index.md') { continue }
    if ($md.Name -eq 'vocabulary.md' -and $md.DirectoryName -eq (Join-Path $vaultRoot '2-Resources')) { continue }
    $content = Get-Content $md.FullName -Raw
    if ($content -match '(?m)^type:\s*Structure Note\s*$') { $md }
}

### 3. Compute the audit-due line from the registry's audit log
$auditLine = '- [Type registry](2-Resources/vocabulary.md): the governed `type` vocabulary; _no audit recorded yet — run `Test-Vault.ps1`_'
if (Test-Path (Join-Path $vaultRoot '2-Resources/vocabulary.md')) {
    $lastAudit = Get-Content (Join-Path $vaultRoot '2-Resources/vocabulary.md') |
        Select-String -Pattern '^- (\d{4}-\d{2}-\d{2})' | Select-Object -Last 1
    if ($lastAudit) {
        $when = [datetime]::ParseExact($lastAudit.Matches[0].Groups[1].Value, 'yyyy-MM-dd', $null)
        $due = $when.AddDays(90).ToString('yyyy-MM-dd')
        $auditLine = "- [Type registry](2-Resources/vocabulary.md): the governed ``type`` vocabulary — _type audit $($when.ToString('yyyy-MM-dd')); due $due_"
    }
}

### 4. Emit front door
$frontDoorContent = @"
$prose

## Start here

- [Agent instructions](AGENTS.md): how an agent session should behave in this Vault
- [Vault index](index.md): the root directory listing with the OKF version declaration

## Concepts

- [0-Projects index](0-Projects/index.md): active efforts, each its own subdirectory
- [1-Areas index](1-Areas/index.md): ongoing responsibilities
- [2-Resources index](2-Resources/index.md): atomic Ideas and topic Structure Notes
- [3-Archives index](3-Archives/index.md): retired material$( $list = ($structureNotes | ForEach-Object {
        $rel = $_.FullName.Substring($vaultRoot.Length).TrimStart('/', '\').Replace('\', '/')
        # Title from frontmatter; fall back to the filename stem.
        $title = if ((Get-Content $_.FullName -Raw) -match '(?m)^title:\s*(.+)$') { $Matches[1].Trim() } else { $_.BaseName }
        "- [$title]($rel): topic map"
    }) -Join "`n"; if ($list) { "`n" + $list } )

## Conventions

- [Update log](log.md): append an entry for every significant Vault change; most recent date first

## Optional

$auditLine
"@
Set-Content -Path $frontDoorPath -Encoding utf8NoBOM -Value $frontDoorContent
Write-Host "Front door regenerated: $frontDoorPath ($($structureNotes.Count) structure notes listed)"
