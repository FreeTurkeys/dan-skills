<#
.SYNOPSIS
  Persist the Vault path to ~/.dan-skills/config.json.

.DESCRIPTION
  Called by the skill after the user names their Vault (chat prompt or
  New-Vault.ps1). One key: { "vault": "<absolute path>" }. Creates the folder
  if missing so the stored path is true on disk, not aspirational.

.EXAMPLE
  pwsh -NoProfile -File Set-VaultConfig.ps1 -VaultPath ~/OneDrive/agent-knowledge
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$VaultPath)

. (Join-Path $PSScriptRoot 'DanSkills.ps1')

New-Item -ItemType Directory -Force -Path $VaultPath | Out-Null
$full = (Get-Item $VaultPath).FullName
Set-DanSkillsConfig -Vault $full
Write-Host "Vault configured: $full"
Write-Host "  (stored at $(Get-DanSkillsConfigPath))"
