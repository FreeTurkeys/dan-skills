# dan-skills

A personal system of Agent Skills, installed on every device by one PowerShell 7
script, that sets up and maintains a synced agent knowledge directory (the Vault).

## Language

**Skill**:
A folder following the Agent Skills spec (`SKILL.md` frontmatter + instructions,
optional `scripts/`, `references/`). The unit this repo produces and installs.
_Avoid_: plugin, rule, command

**Installer**:
`install.ps1`, run via PowerShell 7; bootstraps pwsh 7 itself if missing, then
copies Skills into the agent tools' skill directories.
_Avoid_: setup script, bootstrap (reserved for the pwsh prerequisite step)

**Bootstrap**:
The Installer's pwsh-7-presence check and system install (winget → MSI on
Windows, Homebrew on macOS, apt/dnf on Linux) when `pwsh` is missing.

**Vault**:
The agent knowledge directory — one OKF *Knowledge Bundle* of PARAs-organized
Zettelkasten notes, synced by OneDrive at `~/OneDrive/agent-knowledge`
(env-var overridable). What the knowledge-directory Skill manages.
_Avoid_: knowledge base, second brain, bundle (OKF's term — fine inside spec
quotes, but Vault is our word)

**Concept**:
One markdown note in the Vault: frontmatter with required `type`, optional
recommended fields, free-form body (per OKF).

**Zettel ID**:
The unique address of a Concept, a timestamp string (per Zettelkasten),
recorded in frontmatter `id` and/or filename prefix.

**Structure note**:
An `index.md` that orders Concepts on a topic — OKF's per-directory listing
doubled as a Zettelkasten MOC.

**Front door**:
The vault-root `llms.txt` — H1 name, blockquote summary, H2 file-list sections
mapping the Vault (per llms.txt v2). The agent's entry point.

**PARA containers**:
The Vault's four top-level dirs ordered by actionability:
`0-Projects/`, `1-Areas/`, `2-Resources/`, `3-Archives/`.

**Skill home / Agent skills home**:
Global install targets mirrored by the Installer: `~/.claude/skills/` (Skill
home) and `~/.agents/skills/` (Agent skills home). OpenCode and Cursor read
both; Claude Code reads Skill home.

**Hosting tool**:
One of OpenCode, Claude Code, or Cursor — the three agent tools the Skills
must work in.
