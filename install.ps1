#Requires -Version 5.1
<#
.SYNOPSIS
    dan-skills Installer (PROTOTYPE SKELETON).

.DESCRIPTION
    Installs Agent Skills from this repo: one real copy in the Agent skills
    home (~/.agents/skills), linked from the Skill home (~/.claude/skills).
    Optionally bootstraps pwsh 7
    if missing (Windows: winget -> MSI fallback; macOS: brew; Linux: apt/dnf),
    and optionally lays down the Vault skeleton (no git inside the Vault —
    ADR-0002).

    Must be runnable under Windows PowerShell 5.1 / cmd.exe so it can
    bootstrap pwsh 7 itself. Use only PS5.1-compatible syntax in this file.

.PARAMETER VaultPath
    Target Vault directory. Default: ~/OneDrive/agent-knowledge, overridable
    via env DANSKILLS_VAULT. The path is whatever you want it to be — the
    script verifies it exists/creates it, and does not care what sync system
    (if any) owns it.

.PARAMETER Tools
    Hosting tools covered, via the linked-copy architecture: real copies in
    ~/.agents/skills (read by OpenCode and Cursor), junction/symlinked into
    ~/.claude/skills (read by Claude Code).

.PARAMETER Uninstall
    Removes previously installed Skills (matched by version stamp).

.PARAMETER DryRun
    Print what would happen; change nothing.

.EXAMPLE
    powershell -File install.ps1            # from cmd.exe, bootstraps pwsh
    pwsh -File install.ps1 -DryRun
#>
[CmdletBinding()]
param(
    [string]$VaultPath,
    [ValidateSet('all')]
    [string]$Tools = 'all',
    [switch]$Uninstall,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

# --- Constants ---------------------------------------------------------------
$RepoRoot       = $PSScriptRoot
$SkillsSource   = Join-Path $RepoRoot 'skills'          # skills live in-repo
$SkillHome      = Join-Path $HOME '.claude' | Join-Path -ChildPath 'skills'
$AgentsHome     = Join-Path $HOME '.agents' | Join-Path -ChildPath 'skills'
$VersionStampFile = '.dan-skills.version'               # idempotency stamp
$MinPwshMajor   = 7

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

# --- Skill install (linked-copy architecture) ------------------------------------
# Ruling (#4, Q13): ONE real copy per skill lives in the Agent skills home
# (~/.agents/skills); the Skill home (~/.claude/skills) gets a link per skill.
# Windows: junctions (no elevation needed). macOS/Linux: symbolic links.
# Foreign directories in either home are never touched.

function Copy-Skills {
    [CmdletBinding()]
    param()

    if (-not (Test-Path $SkillsSource)) {
        throw "No skills/ directory at $SkillsSource — nothing to install."
    }

    New-Item -ItemType Directory -Force -Path $AgentsHome | Out-Null
    foreach ($skillDir in Get-ChildItem $SkillsSource -Directory) {
        $dest = Join-Path $AgentsHome $skillDir.Name
        if ($DryRun) { Write-Host "[DryRun] copy $($skillDir.FullName) -> $dest"; continue }
        # Idempotent overwrite: remove only OUR stamped installs.
        if (Test-Path $dest) {
            if (Test-Path (Join-Path $dest $VersionStampFile)) {
                Remove-Item $dest -Recurse -Force
            } else {
                Write-Warning "Skip $dest — exists and is not dan-skills-managed."
                continue
            }
        }
        Copy-Item $skillDir.FullName $dest -Recurse
        # Version stamp: lets -Uninstall target only our skills and lets a
        # future update check know it installed an older build.
        Set-Content -Path (Join-Path $dest $VersionStampFile) `
            -Value ("dan-skills " + (Get-Date -Format o) + " / repo " + (git -C $RepoRoot rev-parse --short HEAD 2>$null))
    }
    Write-Host "Installed skills (real copies) -> $AgentsHome"
    Link-Skills
}

# Link each of OUR skills from the Skill home; convert stale stamped
# dual-copy installs to links; never touch foreign directories.
function Link-Skills {
    [CmdletBinding()]
    param()

    New-Item -ItemType Directory -Force -Path $SkillHome | Out-Null
    foreach ($realDir in Get-ChildItem $AgentsHome -Directory -ErrorAction SilentlyContinue) {
        $target = Join-Path $SkillHome $realDir.Name
        if ($DryRun) { Write-Host "[DryRun] link $target -> $($realDir.FullName)"; continue }
        if (Test-Path $target) {
            if ((Get-Item $target).LinkType) { Remove-Item $target -Force }          # relink ours
            elseif (Test-Path (Join-Path $target $VersionStampFile)) {
                Remove-Item $target -Recurse -Force                                  # old dual-copy install
            }
            else { Write-Warning "Skip linking $target — exists and is not ours."; continue }
        }
        if ($IsWindows -or $env:OS -eq 'Windows_NT') {
            New-Item -ItemType Junction -Path $target -Target $($realDir.FullName) | Out-Null
        } else {
            New-Item -ItemType SymbolicLink -Path $target -Target $($realDir.FullName) | Out-Null
        }
    }
    Write-Host "Linked skills -> $SkillHome"
}

function Remove-Skills {
    [CmdletBinding()]
    param()

    # Real copies in the Agent skills home: stamped ones only.
    Get-ChildItem $AgentsHome -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path (Join-Path $_.FullName $VersionStampFile) } |
        ForEach-Object {
            if ($DryRun) { Write-Host "[DryRun] would remove $($_.FullName)" }
            else { Remove-Item $_.FullName -Recurse -Force; Write-Host "Removed $($_.FullName)" }
        }

    # Skill home: our per-skill links and stamped dual-copy leftovers.
    $ourNames = @(Get-ChildItem $SkillsSource -Directory -ErrorAction SilentlyContinue |
        ForEach-Object Name)
    Get-ChildItem $SkillHome -ErrorAction SilentlyContinue |
        Where-Object {
            (($_.LinkType) -and ($ourNames -contains $_.Name)) -or
            (Test-Path (Join-Path $_.FullName $VersionStampFile))
        } |
        ForEach-Object {
            if ($DryRun) { Write-Host "[DryRun] would remove $($_.FullName)" }
            else { Remove-Item $_.FullName -Recurse -Force; Write-Host "Removed $($_.FullName)" }
        }

    Write-Host 'Uninstall (-Uninstall) never touches pwsh or the Vault.'
}

# --- Vault bootstrap (optional) --------------------------------------------------
function Initialize-Vault {
    [CmdletBinding()]
    param()

    if (-not $VaultPath) {
        # LocalAppData is not visible inside *this* PS5.1 simulator; use default.
        $VaultPath = if ($env:DANSKILLS_VAULT) { $env:DANSKILLS_VAULT }
                     else { Join-Path $HOME 'OneDrive' | Join-Path -ChildPath 'agent-knowledge' }
    }

    if (Test-Path (Join-Path $VaultPath 'llms.txt')) {
        Write-Host "Vault already initialized at $VaultPath — skipping."
        return
    }

    $answer = Read-Host "Bootstrap Vault skeleton at '$VaultPath'? [y/N]"
    if ($answer -notmatch '^[Yy]') { Write-Host 'Skipping Vault bootstrap.'; return }

    if ($DryRun) { Write-Host "[DryRun] would lay Vault skeleton at $VaultPath"; return }

    # Validated template shape from prototype/vault-template (do NOT copy the
    # branch wholesale — minimal skeleton only, content authored in-repo):
    $skeleton = @(
        '0-Projects', '1-Areas', '2-Resources', '3-Archives',
        'llms.txt', 'log.md', 'index.md', 'AGENTS.md'
    )
    New-Item -ItemType Directory -Force -Path $VaultPath | Out-Null
    foreach ($s in $skeleton) {
        $p = Join-Path $VaultPath $s
        if ($s -match '^[0-3]-') {   # PARA containers need their own index.md
            New-Item -ItemType Directory -Force -Path $p | Out-Null
            Set-Content -Path (Join-Path $p 'index.md') "# $s`n"   # stub; real copy deferred
        }
        elseif (-not (Test-Path $p)) {
            switch ([IO.Path]::GetExtension($s)) {
                '.txt' { New-Item -ItemType File -Path $p | Out-Null }      # llms.txt authored in-repo
                '.md'  { New-Item -ItemType File -Path $p | Out-Null }
                default { New-Item -ItemType File -Path $p | Out-Null }     # AGENTS.md
            }
        }
    }
    # ADR-0002: deliberately NO `git init` here — OneDrive is the history.
    Write-Host "Vault skeleton laid at $VaultPath (no git, per ADR-0002)."
    Write-Host 'NOTE: llms.txt / index.md stubs are empty in this prototype;'
    Write-Host '      real copies come from the vault-template branch.'
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

Copy-Skills
Initialize-Vault
Write-Host 'Done.'
