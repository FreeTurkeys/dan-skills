# Installer prototype — DESIGN.md

Prototype for issue #4 (`wayfinder:prototype`). Companion artifact:
`install.ps1` (runnable-looking skeleton, untested). Branch:
`prototype/installer`. Do **not** merge to main.

Glossary (per CONTEXT.md): **Installer** = `install.ps1` itself; **Bootstrap**
= the pwsh-7-presence/install step; **Skill home** = `~/.claude/skills/`;
**Agent skills home** = `~/.agents/skills/`; **Hosting tool** = OpenCode /
Claude Code / Cursor; **Vault** = the OneDrive-synced knowledge directory.

## What each section of install.ps1 does

| Section | Purpose | Basis |
|---|---|---|
| `param` block | `-VaultPath` (default `~/OneDrive/agent-knowledge`, `DANSKILLS_VAULT` overrides), `-Tools`, `-Uninstall`, `-DryRun` | ticket spec |
| `Test-PwshAvailable` / `Get-PwshVersion` | Bootstrap step 1: is pwsh ≥7 present? | RESEARCH.md §5 |
| `Install-Pwsh` | Bootstrap step 2, per-OS dispatch. **Windows**: prefer `winget install --id Microsoft.PowerShell --source winget --installer-type wix` elevated via `Start-Process -Verb RunAs` (wix/MSI forced — MSIX is per-user only, no PATH, no remoting per §5). Fallback when winget absent (Server ≤ 2022): query GitHub releases API for latest `win-x64.msi`, download, `msiexec /quiet ADD_PATH=1 REGISTER_MANIFEST=1` elevated. **macOS**: `brew install --cask powershell` (fails helpfully if Homebrew itself is missing). **Linux**: apt or dnf via packages.microsoft.com — repo-key setup lines are elided stubs (see OPEN Q3). | §5 |
| `Invoke-RelaunchUnderPwsh` | Bootstrap step 3: re-exec this same script under newly installed pwsh in a **new process** (session PATH is stale), probing `Program Files\PowerShell\7` first since PATH won't have refreshed. Exits the PS5.1 process on success. | §5 bootstrap pattern |
| `Copy-Skills` | Copies each `skills/<name>/` folder from the repo into BOTH Skill home and Agent skills home (dual copy — RESEARCH §4: `~/.claude/skills` read by all three tools; `~/.agents/skills` read by OpenCode+Cursor). **Idempotent overwrite**: delete dest dir, copy fresh. Drops `.dan-skills.version` stamp (timestamp + short SHA) into each installed skill for uninstall/update discrimination. | ticket + §4 |
| `Remove-Skills` | `-Uninstall` removes only dirs carrying our version stamp — never touches foreign skills. Never touches the Vault. | ticket (semantics = OPEN Q2) |
| `Initialize-Vault` | On first install: interactive prompt, then lays minimal skeleton (4 PARA dirs each with a stub `index.md`, plus `llms.txt`, `log.md`, `index.md`, `AGENTS.md`). **Deliberately no `git init`** (ADR-0002: OneDrive is the history). Template shape references `prototype/vault-template` branch but only writes empty stubs here — real content stays in-repo until we decide the copy mechanism (see OPEN Q4). | ADR-0002, vault-template branch |
| Main | Bootstrap-if-needed → relaunch → skill copy → vault init. | — |

## What this deliberately does NOT do

- **Not tested.** No CI, no PSScriptAnalyzer, no run on real macOS/Windows
  boxes. Syntax may not even parse; treat as reading material first.
- **No update logic.** Version stamps are laid down but nothing *consumes*
  them yet (no "skill changed, re-copy" detection).
- **No Linux repo setup.** The apt/dnf lines don't actually configure the
  packages.microsoft.com keyring/sources.
- **Vault stubs are empty.** `llms.txt`/`index.md` content is not lifted from
  the vault-template branch — only its *shape* is referenced.
- **No skill content.** `skills/` does not exist on main yet; the script will
  throw a clear error until skills land.
- **No PR, no merge.** Branch `prototype/installer` only.

## OPEN QUESTIONS (for the human — none resolved; each with my recommendation)

1. **MSIX vs MSI as the primary Windows package.** winget's default for
   `Microsoft.PowerShell` became MSIX (per-user) with PS 7.6.0; the prototype
   forces `--installer-type wix` (MSI, machine-wide, PATH).
   **Recommendation: MSI primary** — this installer's job is
   "one script, every device," and MSI gives PATH + machine-wide install +
   works under elevation; MSIX's per-user/no-remoting constraints bite later.
2. **Uninstall semantics.** Should `-Uninstall` (a) remove only stamped skills
   (prototype behavior), (b) also remove pwsh, or (c) also offer deleting the
   Vault skeleton? **Recommendation: (a) only** — pwsh is shared
   infrastructure other things may rely on, and the Vault is user knowledge
   (data-loss risk outweighs convenience).
3. **Windows Server / winget-absent fallback.** Prototype falls back to
   direct MSI download from GitHub releases API. Alternative: the
   `aka.ms/install-powershell.ps1` meta-script. **Recommendation: keep the
   direct-MSI fallback** — it's explicit, dependency-free, and we control the
   `ADD_PATH=1` properties; the MS community script is a moving target.
4. **Vault bootstrap: install-time vs first-use-of-skill.** Prototype offers
   it at install time (interactive y/N). Alternative: the knowledge-directory
   Skill itself creates the skeleton on first activation.
   **Recommendation: install-time prompt** — the human is already at a terminal
   confirming choices, and the Skill should be able to *assume* a Vault exists
   rather than grow one mid-conversation.
5. **Linux distro coverage.** apt + dnf only? Plus zypper/snap/tar.gz?
   **Recommendation: apt + dnf now**, tar.gz escape hatch documented but not
   coded — matches the repo's "personal system" scope; widen only if a device
   needs it.
6. **Dual-copy divergence.** Two copies of every skill can drift if one home
   is edited by hand. Alternative: symlink Agent skills home → Skill home
   (symlink support on Windows needs Developer Mode / admin for file
   symlinks; junctions are dir-only and don't cross OneDrive boundaries well).
   **Recommendation: keep dual copy + version stamp for now**, revisit
   symlinks only if drift actually bites; the copy is mode-conventional on
   this machine.)
7. **macOS without Homebrew.** Prototype errors out telling you to install
   brew. Alternative: fall back to the GitHub `.pkg` installer.
   **Recommendation: error out this prototype**, add `.pkg` fallback only if
   the human's macs are guaranteed brew-less — otherwise dead code.

## Rulings (2026-10-03, ticket #4 decisions — final)

- **Q8 Windows primary package**: MSI (`--installer-type wix`); MSIX stays unwired
- **Q9 `-Uninstall` semantics**: removes only dan-skills-stamped skills + our links; never pwsh, never the Vault
- **Q10 winget-absent fallback**: direct GitHub-releases MSI + `msiexec /quiet ADD_PATH=1` (elevated); `aka.ms` meta-script skipped
- **Q11 Vault path**: generic — `-VaultPath` (default `~/OneDrive/agent-knowledge`, env `DANSKILLS_VAULT`); the script verifies/creates the folder and does not care what sync owns it. OneDrive-ness is the user's choice.
- **Q12 Linux**: apt + dnf coded; tar.gz documented only
- **Q13 Copy architecture (changed from dual copy)**: **symlinks** — single real copy in `~/.agents/skills`, per-skill links in `~/.claude/skills` (junction on Windows, symlink on Unix); foreign directories/links never touched; stamped dual-copy installs migrate to links
- **Q14 macOS without Homebrew**: error out with guidance; `.pkg` fallback deferred

Implemented in root `install.ps1` (this call it is no longer a prototype skeleton — it is the candidate production script; ticket #8 proves it on macOS). Adapted from `prototype/installer/install.ps1` (commit 485e48d) on branch `prototype/installer`.

## Addendum — state layer + drift engine (2026-10-03, ticket #3)

Decided while building the skill. Canonical state lives in `~/.dan-skills/`:

| File | Holds | Written by |
| --- | --- | --- |
| `config.json` | `{ "vault": "<abs path>" }` — the single key | installer, `New-Vault.ps1`, `Set-VaultConfig.ps1` |
| `manifest.json` | `configVersion`, `installedAtRepo`, per-skill `{ installedAt, files: { relpath: sha256 } }` | installer only |
| `backups/<ts>/<skill>/` | archived copies of locally modified skills — never pruned | installer |

- **Vault path is a fact, not a guess** (Q22/Q25/Q32): precedence `-VaultPath` >
  `config.json` > prompt (default `~/OneDrive/agent-knowledge`) > built-in default
  under `-Defaults`/`-Force`. `Resolve-VaultPath.ps1` exits 2 with instructions
  when unconfigured; the skill asks the user in chat and persists the answer.
  The `DANSKILLS_VAULT` env var is retired.
- **Two comparisons, one prompt** (Q27–Q30): installed-vs-manifest = *local drift*
  (prompts); manifest-vs-repo = *version delta* (installs silently). Drift resolves
  as `overwrite` / `backup` (default; archive then install fresh) / `merge`
  (file-granular: repo-new lands, locally-modified kept, conflicts printed) /
  `skip`.
- **Hashes are content-normalized** (Q28): text via CRLF→LF before SHA-256, raw
  bytes for binaries, so a Windows checkout never looks like a local edit.
- **Non-interactive matrix** (Q30): no TTY + no switch = refuse loudly, exit
  non-zero. `-Defaults` = unattended, config-or-default path, drift resolved by
  backup (never overwrite). `-Force` = unattended overwrite, still backs up first.
- **One bootstrap, one implementation**: the installer calls the skill's
  `New-Vault.ps1` instead of keeping its own stub loop (which had drifted).
- Uninstall is manifest-driven; legacy pre-manifest stamped copies are swept.

Implementation: root `install.ps1` + `skills/knowledge-directory/scripts/DanSkills.ps1`
(dot-sourced by both installer and skill — one hashing/config implementation).
Smoke-tested on macOS under a sandboxed `HOME`: fresh install, clean re-run,
CRLF normalization, all four drift answers, uninstall, re-install. **Untested:**
the true no-TTY refusal path (macOS always reports `UserInteractive`), Windows
PS 5.1 bootstrap, Linux packaging — per the parked-verification decision.
