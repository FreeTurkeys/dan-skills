<#
.SYNOPSIS
  Print the Vault path, or exit 2 with instructions if unconfigured.

.DESCRIPTION
  The Vault location is a fact on disk, not a guess: explicit -VaultPath >
  ~/.dan-skills/config.json > nothing. Never falls back to a default and never
  walks the tree looking for a Vault. Exit 2 = "ask the user, then persist
  the answer with Set-VaultConfig.ps1" (see SKILL.md section 1).

.EXAMPLE
  pwsh -NoProfile -File Resolve-VaultPath.ps1
#>
[CmdletBinding()]
param([string]$VaultPath)

. (Join-Path $PSScriptRoot 'DanSkills.ps1')

$resolved = Resolve-DanSkillsVault -VaultPath $VaultPath
if ($resolved) { Write-Output $resolved; exit 0 }

Write-Error @'
not configured: no vault in ~/.dan-skills/config.json

Ask the user where the Vault is (default: ~/OneDrive/agent-knowledge), then:

  pwsh -NoProfile -File Set-VaultConfig.ps1 -VaultPath "<their path>"
'@
exit 2
