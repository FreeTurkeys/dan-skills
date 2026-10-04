# dan-skills shared library — dot-sourced, defines functions only.
#
# One place that knows where the per-machine state lives and how to read and
# write it. The Installer (repo root install.ps1) dot-sources this same file,
# so installer and skill can never drift on paths, hashing, or config format.
#
# State directory: ~/.dan-skills/
#   config.json    { "vault": "<absolute path>" }
#   manifest.json  what we installed, with per-file hashes (drift detection)
#   backups/<ts>/  archived copies of locally modified skills (never pruned)

$script:DanSkillsStateDirName = '.dan-skills'

function Get-DanSkillsStateDir {
    [CmdletBinding()]
    param()
    return (Join-Path $HOME $script:DanSkillsStateDirName)
}

function Get-DanSkillsConfigPath {
    [CmdletBinding()]
    param()
    return (Join-Path (Get-DanSkillsStateDir) 'config.json')
}

function Get-DanSkillsManifestPath {
    [CmdletBinding()]
    param()
    return (Join-Path (Get-DanSkillsStateDir) 'manifest.json')
}

function Read-DanSkillsJson {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    try { return (Get-Content -Path $Path -Raw | ConvertFrom-Json) }
    catch { throw "Malformed JSON at $Path : $($_.Exception.Message)" }
}

function Get-DanSkillsConfig {
    [CmdletBinding()]
    param()
    return (Read-DanSkillsJson -Path (Get-DanSkillsConfigPath))
}

function Set-DanSkillsConfig {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Vault)
    $dir = Get-DanSkillsStateDir
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    @{ vault = $Vault } | ConvertTo-Json | Set-Content -Path (Get-DanSkillsConfigPath) -Encoding utf8NoBOM
}

function Get-DanSkillsManifest {
    [CmdletBinding()]
    param()
    return (Read-DanSkillsJson -Path (Get-DanSkillsManifestPath))
}

function Set-DanSkillsManifest {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Manifest)
    $dir = Get-DanSkillsStateDir
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $Manifest | ConvertTo-Json -Depth 6 | Set-Content -Path (Get-DanSkillsManifestPath) -Encoding utf8NoBOM
}

# --- Hashing -------------------------------------------------------------------
# Content hash of a file, normalized so platform line endings are not mistaken
# for a local edit (ruling: text normalized, binaries raw). Text = anything
# without NUL bytes, sniffed by extension for the common script types.
function Get-DanSkillsFileHash {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    $ext = [IO.Path]::GetExtension($Path).ToLowerInvariant()
    $binaryExt = @('.png', '.jpg', '.jpeg', '.gif', '.webp', '.ico', '.pdf', '.zip',
                   '.gz', '.woff', '.woff2', '.ttf', '.otf', '.mp3', '.mp4')
    if ($binaryExt -contains $ext) {
        return (Get-FileHash -Path $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    $text = [IO.File]::ReadAllText($Path) -replace "`r`n", "`n"
    $bytes = [Text.Encoding]::UTF8.GetBytes($text)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($bytes)) -replace '-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

# Hash map for a skill folder: relative path (slash-separated) -> hash.
function Get-DanSkillsTreeHash {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    $map = [ordered]@{}
    if (-not (Test-Path $Path)) { return $map }
    foreach ($f in Get-ChildItem $Path -Recurse -File | Sort-Object FullName) {
        $rel = $f.FullName.Substring($Path.Length).TrimStart('/', '\').Replace('\', '/')
        $map[$rel] = Get-DanSkillsFileHash -Path $f.FullName
    }
    return $map
}

function Compare-DanSkillsTree {
    <# Returns @{ Status = 'clean'|'drifted'; Added; Removed; Modified } #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        $Expected = $null
    )
    $actual = Get-DanSkillsTreeHash -Path $Path
    if ($null -eq $Expected) {
        return @{ Status = 'drifted'; Added = @($actual.Keys); Removed = @(); Modified = @() }
    }
    $added = @(); $removed = @(); $modified = @()
    foreach ($k in $actual.Keys) {
        if (-not $Expected.PSObject.Properties[$k]) { $added += $k }
        elseif ($Expected.$k -ne $actual[$k]) { $modified += $k }
    }
    foreach ($p in $Expected.PSObject.Properties) {
        if (-not $actual.Contains($p.Name)) { $removed += $p.Name }
    }
    $status = if (-not $added -and -not $removed -and -not $modified) { 'clean' } else { 'drifted' }
    return @{ Status = $status; Added = $added; Removed = $removed; Modified = $modified }
}

# --- Vault path resolution -----------------------------------------------------
# Precedence: explicit -VaultPath > config.json > (installer -Defaults only)
# the built-in default. Never guesses, never walks up.
function Resolve-DanSkillsVault {
    [CmdletBinding()]
    param([string]$VaultPath)
    if ($VaultPath) {
        New-Item -ItemType Directory -Force -Path $VaultPath | Out-Null
        return (Get-Item $VaultPath).FullName
    }
    $config = Get-DanSkillsConfig
    if ($config -and $config.vault) { return $config.vault }
    return $null
}
