#Requires -Version 5.1
<#
.SYNOPSIS
    dan-skills Installer.

.DESCRIPTION
    Installs Agent Skills from this repo: one real copy in the Agent skills
    home (~/.agents/skills), linked from the Skill home (~/.claude/skills).
    Bootstraps pwsh 7 if missing (Windows: winget -> MSI fallback; macOS: brew;
    Linux: apt/dnf), records a per-file hash manifest, and optionally lays down
    the Vault skeleton (no git inside the Vault — ADR-0002).

    Must be runnable under Windows PowerShell 5.1 / cmd.exe so it can bootstrap
    pwsh 7 itself. Use only PS5.1-compatible syntax in this file.

    Local edits are never destroyed silently. Re-running over a skill whose
    installed files no longer match ~/.dan-skills/manifest.json is "drift";
    drift is offered as overwrite / backup / merge / skip (or decided by
    -Force / -Defaults). Everything that is overwritten or merged is first
    copied to ~/.dan-skills/backups/<timestamp>/, which is never pruned.

.PARAMETER VaultPath
    Explicit Vault directory. Beats ~/.dan-skills/config.json. Prompted for
    when neither exists (unless -Defaults). The path is whatever you want it
    to be — the script does not care what sync system (if any) owns it.

.PARAMETER Tools
    Hosting tools covered, via the linked-copy architecture: real copies in
    ~/.agents/skills (read by OpenCode and Cursor), junction/symlinked into
    ~/.claude/skills (read by Claude Code).

.PARAMETER Defaults
    Unattended install using stored config or the default Vault path. Drift is
    resolved by backup (never overwrite). For bootstrap scripts and CI.

.PARAMETER Force
    Unattended install that overwrites drifted skills, discarding local edits
    (a copy still lands in backups/ first). Use knowingly.

.PARAMETER Uninstall
    Removes the skills recorded in the manifest. Never touches pwsh or the
    Vault.

.PARAMETER DryRun
    Print what would happen; change nothing.

.EXAMPLE
    powershell -File install.ps1                # from cmd.exe, bootstraps pwsh
    pwsh -File install.ps1 -Defaults            # unattended, non-destructive
    pwsh -File install.ps1 -DryRun
#>
[CmdletBinding()]
param(
    [string]$VaultPath,
    [ValidateSet('all')]
    [string]$Tools = 'all',
    [switch]$Defaults,
    [switch]$Force,
    [switch]$Uninstall,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

# --- Constants ---------------------------------------------------------------
$RepoRoot       = $PSScriptRoot
$SkillsSource   = Join-Path $RepoRoot 'skills'          # skills live in-repo
$SkillHome      = Join-Path $HOME '.claude' | Join-Path -ChildPath 'skills'
$AgentsHome     = Join-Path $HOME '.agents' | Join-Path -ChildPath 'skills'
$MinPwshMajor   = 7
$DefaultVault   = Join-Path (Join-Path $HOME 'OneDrive') 'agent-knowledge'

# Shared state layer (config.json, manifest.json, hashing) lives with the
# skill so installed copies and the Installer can never disagree.
$LibraryPath = Join-Path $SkillsSource 'knowledge-directory/scripts/DanSkills.ps1'
if (-not (Test-Path $LibraryPath)) { throw "Shared library missing: $LibraryPath" }
. $LibraryPath

# --- Helpers -----------------------------------------------------------------
function Test-PwshAvailable {
    [CmdletBinding()]
    param()
    return [bool](Get-Command pwsh -ErrorAction SilentlyContinue)
}

function Get-PwshVersion {
    [CmdletBinding()]
    param()
    $v = & pwsh -NoProfile -Command '$PSVersionTable.PSVersion.Major'
    return [int]$v
}

function Test-Interactive {
    [CmdletBinding()]
    param()
    if ($Defaults -or $Force) { return $false }
    return [bool][Environment]::UserInteractive -and [bool]$Host.Name
}

function Read-InteractiveChoice {
    <# Read-Host with a default; returns the default on empty input. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Prompt, [string]$Default)
    $answer = Read-Host "$Prompt [$Default]"
    if ([string]::IsNullOrWhiteSpace($answer)) { return $Default }
    return $answer.Trim()
}

# --- Bootstrap: pwsh 7 missing ------------------------------------------------
function Install-Pwsh {
    [CmdletBinding()]
    param()

    $os = if ($IsWindows -or $env:OS -eq 'Windows_NT') { 'windows' }
          elseif ($IsMacOS) { 'macos' }
          else { 'linux' }

    switch ($os) {
        'windows' {
            # Preferred: winget MSI (machine-wide, adds PATH). MSIX is the
            # winget default since 7.6.0 -- we force MSI because MSIX is
            # per-user only, no PATH control, no remoting (RESEARCH.md §5).
            if (Get-Command winget -ErrorAction SilentlyContinue) {
                $wingetArgs = @(
                    'install', '--id', 'Microsoft.PowerShell',
                    '--source', 'winget',
                    '--installer-type', 'wix',
                    '--accept-package-agreements', '--accept-source-agreements'
                )
                # winget may not elevate itself cleanly; run elevated.
                $proc = Start-Process -FilePath 'winget' -ArgumentList $wingetArgs `
                          -Verb RunAs -Wait -PassThru -ErrorAction Stop
                if ($proc.ExitCode -ne 0) { throw "winget install failed: $($proc.ExitCode)" }
            }
            else {
                # Fallback (winget absent, e.g. Windows Server <= 2022):
                # direct MSI from GitHub releases.
                $release = Invoke-RestMethod `
                    'https://api.github.com/repos/PowerShell/PowerShell/releases/latest'
                $msiAsset = $release.assets |
                    Where-Object { $_.name -match 'win-x64\.msi$' } |
                    Select-Object -First 1
                if (-not $msiAsset) { throw 'No win-x64 MSI found in latest PowerShell release.' }

                $msiPath = Join-Path ([IO.Path]::GetTempPath()) $msiAsset.name
                Invoke-WebRequest $msiAsset.browser_download_url -OutFile $msiPath

                $msiArgs = "/package `"$msiPath`" /quiet ADD_PATH=1 REGISTER_MANIFEST=1"
                Start-Process -FilePath 'msiexec.exe' -ArgumentList $msiArgs `
                    -Verb RunAs -Wait -ErrorAction Stop
            }
        }
        'macos' {
            if (-not (Get-Command brew -ErrorAction SilentlyContinue)) {
                throw 'Homebrew missing; install from https://brew.sh then re-run.'
            }
            & brew install --cask powershell
            if ($LASTEXITCODE -ne 0) { throw 'brew install failed.' }
        }
        'linux' {
            # packages.microsoft.com pattern; branch needs the distro check
            # (/etc/os-release -> apt or dnf). Sloppy but concrete for the
            # prototype; two flavors cover Ubuntu/Debian and Fedora/RHEL.
            if (Get-Command apt-get -ErrorAction SilentlyContinue) {
                & sudo apt-get update
                & sudo apt-get install -y wget apt-transport-https software-properties-common
                # NOTE: repo-setup lines (packages.microsoft.com keyring +
                # sources.list.d) elided for the prototype; see OPEN Q3.
                & sudo apt-get install -y powershell
            }
            elseif (Get-Command dnf -ErrorAction SilentlyContinue) {
                & sudo dnf install -y powershell   # repo config elided, see OPEN Q3
            }
            else {
                throw 'Unsupported Linux distro for Bootstrap (need apt or dnf).'
            }
        }
    }
}

function Invoke-RelaunchUnderPwsh {
    <# Re-executes this script under freshly installed pwsh (new process;
       PATH was refreshed by the MSI/APP_DATA but not in the current session,
       so probe the default install dir too). #>
    [CmdletBinding()]
    param()

    $candidates = @(
        (Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe'),
        (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Microsoft\PowerShell\7\pwsh.exe'),
        'pwsh'
    )
    foreach ($c in $candidates) {
        $resolved = Get-Command $c -ErrorAction SilentlyContinue
        if ($resolved) {
            $argList = @('-NoProfile', '-File', "`"$PSCommandPath`"", @($PSBoundParameters.GetEnumerator() |
                ForEach-Object { if ($_.Value -is [switch]) { "-$($_.Key)" } else { "-$($_.Key) '$($_.Value)'"} }))
            if ($DryRun) { Write-Host "[DryRun] would relaunch: $resolved.Source $argList"; exit 0 }
            exit (& $resolved.Source @argList)   # end this process; never return
        }
    }
    throw 'pwsh installed but not found; open a new shell and re-run install.ps1.'
}

# --- Skill install (linked-copy + manifest drift engine) -------------------------
# Ruling (#4, Q13): ONE real copy per skill lives in the Agent skills home
# (~/.agents/skills); the Skill home (~/.claude/skills) gets a link per skill.
# Windows: junctions (no elevation needed). macOS/Linux: symbolic links.
# Foreign directories in either home are never touched.
#
# Drift engine (rulings Q27-Q31): ~/.dan-skills/manifest.json records the hash
# of every file we wrote. On re-install, installed-vs-manifest decides clean or
# drifted; drift is resolved by overwrite / backup / merge / skip, or decided
# by -Force (overwrite) / -Defaults (backup). Backups are never pruned.

function Backup-Skill {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Dest, [Parameter(Mandatory)][string]$Stamp)
    $backupsRoot = Join-Path (Get-DanSkillsStateDir) 'backups'
    $target = Join-Path (Join-Path $backupsRoot $Stamp) (Split-Path $Dest -Leaf)
    # Two drift events in the same second must not share a folder (silent merge).
    $n = 2
    while (Test-Path $target) { $target = Join-Path (Join-Path $backupsRoot $Stamp) "$((Split-Path $Dest -Leaf))-$n"; $n++ }
    New-Item -ItemType Directory -Force -Path $backupsRoot | Out-Null
    Copy-Item -Path $Dest -Destination $target -Recurse -Force
    return $target
}

function Resolve-Drift {
    <# Returns 'overwrite' | 'backup' | 'merge' | 'skip' for a drifted skill. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Name)

    if ($Force)    { return 'overwrite' }
    if ($Defaults) { return 'backup' }
    if (-not (Test-Interactive)) {
        throw "Skill '$Name' has local modifications and there is no terminal to ask (exit $LASTEXITCODE). Re-run with -Defaults (backs up, keeps your edits in backups/) or -Force (overwrites, still backs up first)."
    }
    Write-Host ''
    Write-Host "Skill '$Name' differs from what was installed (local edits?)."
    Write-Host '  [1] overwrite  — install fresh; your version goes to backups/ first'
    Write-Host '  [2] backup      — archive your version, install fresh (default)'
    Write-Host '  [3] merge       — take new repo files, keep your modified files'
    Write-Host '  [4] skip        — leave this skill exactly as it is'
    $choice = Read-InteractiveChoice -Prompt 'Choose 1-4' -Default '2'
    switch ($choice) {
        '1' { return 'overwrite' }
        '3' { return 'merge' }
        '4' { return 'skip' }
        default { return 'backup' }
    }
}

function Install-SkillTree {
    <# Write the repo skill over $Dest, honoring $Action (overwrite|merge).
       For merge: repo files land unless they exist in $Dest and the manifest
       flagged them modified; locally modified files are kept and reported. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Dest,
        [Parameter(Mandatory)][ValidateSet('overwrite', 'merge')][string]$Action,
        $ManifestFiles = $null
    )

    if ($Action -eq 'overwrite') {
        Remove-Item $Dest -Recurse -Force
        New-Item -ItemType Directory -Force -Path $Dest | Out-Null
        Copy-Item -Path (Join-Path $Source '*') -Destination $Dest -Recurse -Force
        return @()
    }

    # merge: copy repo files that are new or were unmodified locally
    $kept = @()
    foreach ($f in Get-ChildItem $Source -Recurse -File) {
        $rel = $f.FullName.Substring($Source.Length).TrimStart('/', '\')
        $target = Join-Path $Dest $rel
        $locallyModified = $false
        if ($ManifestFiles -and $ManifestFiles.PSObject.Properties[$rel] -and (Test-Path $target)) {
            $locallyModified = (Get-DanSkillsFileHash -Path $target) -ne $ManifestFiles.$rel
        }
        if ($locallyModified -and (Test-Path $target)) {
            $kept += $rel
            continue
        }
        New-Item -ItemType Directory -Force -Path (Split-Path $target -Parent) | Out-Null
        Copy-Item -Path $f.FullName -Destination $target -Force
    }
    return $kept
}

function Install-Skills {
    [CmdletBinding()]
    param()

    if (-not (Test-Path $SkillsSource)) {
        throw "No skills/ directory at $SkillsSource — nothing to install."
    }

    $manifest = Get-DanSkillsManifest
    if (-not $manifest) {
        $manifest = [pscustomobject]@{ configVersion = 1; installedAtRepo = $null; skills = [pscustomobject]@{} }
    }

    New-Item -ItemType Directory -Force -Path $AgentsHome | Out-Null
    foreach ($skillDir in Get-ChildItem $SkillsSource -Directory) {
        $name = $skillDir.Name
        $dest = Join-Path $AgentsHome $name
        $record = $manifest.skills.PSObject.Properties[$name]
        $expected = if ($record) { $record.Value.files } else { $null }
        $installed = Test-Path $dest

        # Foreign directory we do not own: leave it be (unless it is a stale
        # copy of ours from a pre-manifest install, which has the old stamp).
        if ($installed -and -not $expected -and -not (Test-Path (Join-Path $dest '.dan-skills.version'))) {
            Write-Warning "Skip $dest — exists and is not dan-skills-managed."
            continue
        }

        $action = 'overwrite'
        if ($installed -and $expected) {
            $diff = Compare-DanSkillsTree -Path $dest -Expected $expected
            if ($diff.Status -eq 'clean') {
                Write-Host "Skill '$name' is unchanged — refreshing to the current repo version."
            }
            else {
                $stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
                if ($DryRun) {
                    Write-Host "[DryRun] $name drifted (+$($diff.Added.Count) ~$($diff.Modified.Count) -$($diff.Removed.Count)); would prompt/resolve, back up to backups/$stamp"
                    continue
                }
                Write-Host "Skill '$name' drifted (+$($diff.Added.Count) new, ~$($diff.Modified.Count) modified, -$($diff.Removed.Count) removed)."
                $action = Resolve-Drift -Name $name
                if ($action -eq 'skip') {
                    Write-Host "  -> skipped '$name'; left as-is."
                    continue
                }
                $backupPath = Backup-Skill -Dest $dest -Stamp $stamp
                Write-Host "  -> backed up to $backupPath"
            }
        }

        if ($DryRun) { Write-Host "[DryRun] install $name -> $dest ($action)"; continue }

        $kept = @()
        if ($installed) {
            # 'backup' and 'overwrite' differ only in that backup already
            # archived the old tree; both then install fresh.
            $treeAction = if ($action -eq 'merge') { 'merge' } else { 'overwrite' }
            $kept = Install-SkillTree -Source $skillDir.FullName -Dest $dest -Action $treeAction -ManifestFiles $expected
        }
        else {
            New-Item -ItemType Directory -Force -Path $dest | Out-Null
            Copy-Item -Path (Join-Path $skillDir.FullName '*') -Destination $dest -Recurse -Force
        }
        if ($kept.Count) {
            Write-Host "  -> merge kept your modified files: $($kept -join ', ')"
        }

        $manifest.skills | Add-Member -NotePropertyName $name -NotePropertyValue ([pscustomobject]@{
            installedAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
            files        = (Get-DanSkillsTreeHash -Path $dest)
        }) -Force
    }

    $repoSha = git -C $RepoRoot rev-parse --short HEAD 2>$null
    $manifest.installedAtRepo = $repoSha
    if (-not $DryRun) { Set-DanSkillsManifest -Manifest $manifest }
    Write-Host "Skills installed (real copies) -> $AgentsHome"
    Link-Skills
}

# Link each of OUR skills from the Skill home; never touch foreign directories.
function Link-Skills {
    [CmdletBinding()]
    param()

    $manifest = Get-DanSkillsManifest
    $ourNames = if ($manifest) { @($manifest.skills.PSObject.Properties.Name) }
                else { @(Get-ChildItem $SkillsSource -Directory -ErrorAction SilentlyContinue | ForEach-Object Name) }

    New-Item -ItemType Directory -Force -Path $SkillHome | Out-Null
    foreach ($name in $ourNames) {
        $real = Join-Path $AgentsHome $name
        if (-not (Test-Path $real)) { continue }
        $target = Join-Path $SkillHome $name
        if ($DryRun) { Write-Host "[DryRun] link $target -> $real"; continue }
        if (Test-Path $target) {
            if ((Get-Item $target).LinkType) { Remove-Item $target -Force }          # relink ours
            elseif (Test-Path (Join-Path $target '.dan-skills.version')) {
                Remove-Item $target -Recurse -Force                                  # old dual-copy install
            }
            else { Write-Warning "Skip linking $target — exists and is not ours."; continue }
        }
        if ($IsWindows -or $env:OS -eq 'Windows_NT') {
            New-Item -ItemType Junction -Path $target -Target $real | Out-Null
        } else {
            New-Item -ItemType SymbolicLink -Path $target -Target $real | Out-Null
        }
    }
    Write-Host "Linked skills -> $SkillHome"
}

function Remove-Skills {
    [CmdletBinding()]
    param()

    # The manifest is the record of what we installed. Real copies in the
    # Agent skills home that it names are ours; anything else is not.
    $manifest = Get-DanSkillsManifest
    $ourNames = if ($manifest) { @($manifest.skills.PSObject.Properties.Name) }
                else { @() }

    foreach ($name in $ourNames) {
        $realCopy = Join-Path $AgentsHome $name
        $link = Join-Path $SkillHome $name
        foreach ($target in @($realCopy, $link)) {
            if (-not (Test-Path $target)) { continue }
            if ($DryRun) { Write-Host "[DryRun] would remove $target" }
            else { Remove-Item $target -Recurse -Force; Write-Host "Removed $target" }
        }
    }

    # Legacy pre-manifest dual-copy installs (stamped, not in the manifest).
    if ($SkillsSource -and (Test-Path $SkillsSource)) {
        $legacy = @(Get-ChildItem $SkillHome -Directory -ErrorAction SilentlyContinue |
            Where-Object { (Test-Path (Join-Path $_.FullName '.dan-skills.version')) -and ($ourNames -notcontains $_.Name) })
        foreach ($dir in $legacy) {
            if ($DryRun) { Write-Host "[DryRun] would remove legacy stamped copy $($dir.FullName)" }
            else { Remove-Item $dir.FullName -Recurse -Force; Write-Host "Removed legacy stamped copy $($dir.FullName)" }
        }
    }

    if (-not $DryRun -and $manifest) { Set-DanSkillsManifest -Manifest ([pscustomobject]@{ configVersion = 1; installedAtRepo = $null; skills = [pscustomobject]@{} }) }

    Write-Host 'Uninstall (-Uninstall) never touches pwsh or the Vault.'
}

# --- Vault bootstrap (optional) --------------------------------------------------
function Resolve-VaultTarget {
    <# explicit -VaultPath > config.json > prompt (default shown) > $DefaultVault
       (only under -Defaults/-Force). Returns $null when it cannot be settled. #>
    [CmdletBinding()]
    param()
    if ($VaultPath) { return $VaultPath }
    $config = Get-DanSkillsConfig
    if ($config -and $config.vault) { return $config.vault }
    if ($Defaults -or $Force) { return $DefaultVault }
    if (-not (Test-Interactive)) {
        Write-Error 'No vault configured and no terminal to ask. Re-run with -VaultPath <path> or -Defaults.'
        return $null
    }
    return (Read-InteractiveChoice -Prompt 'Vault path' -Default $DefaultVault)
}

function Initialize-Vault {
    [CmdletBinding()]
    param([string]$Target)

    if (-not $Target) { return }
    if (Test-Path (Join-Path $Target 'llms.txt')) {
        Write-Host "Vault already initialized at $Target — skipping."
        return
    }

    # Vault location is a fact on disk for every later session (Q25/Q26).
    $exists = Test-Path $Target
    if (-not $Defaults -and -not $Force -and (Test-Interactive)) {
        if ($exists) {
            $answer = Read-InteractiveChoice -Prompt "No Vault skeleton at '$Target' yet. Bootstrap it there? [y/N]" -Default 'N'
        }
        else {
            $answer = Read-InteractiveChoice -Prompt "Bootstrap Vault skeleton at '$Target'? [y/N]" -Default 'N'
        }
        if ($answer -notmatch '^[Yy]') { Write-Host 'Skipping Vault bootstrap.'; return }
    }
    elseif (-not $exists -and -not $Defaults -and -not $Force) {
        Write-Host "No Vault at $Target and unattended — skipping bootstrap."
        return
    }

    if ($DryRun) { Write-Host "[DryRun] would lay Vault skeleton at $Target"; return }

    # One bootstrap, one implementation: the skill's own New-Vault.ps1 (the
    # installer used to keep its own stub loop, which drifted from it).
    $newVault = [IO.Path]::GetFullPath((Join-Path (Split-Path $LibraryPath -Parent) 'New-Vault.ps1'))
    & pwsh -NoProfile -File $newVault -VaultPath $Target
    if ($LASTEXITCODE -ne 0) { throw "New-Vault.ps1 failed (exit $LASTEXITCODE)" }
    Set-DanSkillsConfig -Vault $Target
    # ADR-0002: New-Vault deliberately does NOT `git init` — OneDrive is history.
    Write-Host "Vault skeleton laid at $Target (no git, per ADR-0002); path stored in $(Get-DanSkillsConfigPath)."
}

# --- Main -------------------------------------------------------------------------
switch ($PSVersionTable.PSVersion) {
    { $_.Major -ge $MinPwshMajor } { Write-Verbose "pwsh $($_) — fine."; break }
    default {
        Write-Host "pwsh 7 not found (running $($PSVersionTable.PSVersion)) — bootstrapping."
        Install-Pwsh
        Invoke-RelaunchUnderPwsh
    }
}

if ($Uninstall) {
    Remove-Skills
    Write-Host 'Uninstall does NOT touch the Vault (it holds your knowledge).'
    exit 0
}

Install-Skills
$vaultTarget = Resolve-VaultTarget
if ($vaultTarget) { Initialize-Vault -Target $vaultTarget }
Write-Host 'Done.'
