# Research Foundation

Researched 2026-10-03. This document is the shared factual base for all design
decisions in this repo. Sources listed per section.

---

## 1. OKF — Open Knowledge Format

**What it is.** An open format for representing knowledge: a directory tree of
markdown files with YAML frontmatter. "The README.md for your data catalog — but
structured enough for an LLM agent to navigate on its own." Originally from
GoogleCloudPlatform (`open-knowledge-format` repo), spec now at v0.2
(released Jul 24 2026, last revision Aug 21 2026).

**Core model.**

| Term | Meaning |
| --- | --- |
| Knowledge Bundle | A self-contained directory tree of markdown files (unit of distribution — a git repo or subdirectory) |
| Concept | One unit of knowledge = one markdown file |
| Concept ID | File path minus `.md` (e.g. `tables/users`) |
| Frontmatter | YAML block delimited by `---` |
| Link | Standard markdown link between concepts |
| Citation | Link from a concept to an external source backing a claim |

**Reserved filenames** (at every directory level, MUST NOT be concept docs):

- `index.md` — directory listing for progressive disclosure (no frontmatter, except root may declare `okf_version`)
- `log.md` — chronological update history, `## YYYY-MM-DD` date headings, most recent first

**Frontmatter.** Exactly one required field: `type` (free-vocabulary string,
e.g. `Metric`, `Playbook`, `Reference`). Recommended: `title`, `description`
(one sentence), `resource` (URI of the underlying asset), `tags` (list),
`timestamp` (ISO 8601). Producers may add arbitrary extension keys; consumers
MUST preserve unknown keys.

**v0.2 trust & lifecycle layer (recommended fields):**

```yaml
sources:            # where content came from
  - { resource: <url>, id: <id>, title: <t>, last_modified: <iso8601> }
generated: { by: human:jane, at: 2026-07-31T12:00:00Z }   # who produced it
verified:  [ { by: process:ci-lint, at: 2026-07-31T12:05:00Z } ]  # who confirmed it
status: draft       # open vocabulary: draft | stable | deprecated …
stale_after: 2026-12-31T00:00:00Z
```

Actor prefixes: `human:<id>`, `process:<id>`, or `<producer>/<version>` for
agents/tools. All timestamp keys are ISO 8601 with explicit UTC offset.
`status: deprecated` / expired `stale_after` are trust *signals*, not errors.
Legacy v0.1 `timestamp` stays readable; prefer `generated.at` going forward.

**Cross-linking.** Bundle-relative links starting with `/` are recommended
(stable when files move within subdirectories); plain relative links allowed.
Broken links are tolerated and even encouraged (reference first, write later).
Link semantics are untyped directed edges; relationship meaning is conveyed by
surrounding prose.

**Body.** Standard markdown; prefer structural markdown (headings, lists,
tables, fenced code) — RAG/agents retrieve far better with clear headings.
Conventional headings when applicable: `# Schema`, `# Examples`,
`# Citations`. Citations go at the end under `# Citations`, numbered.

**Conformance (the golden rule).** A bundle is conformant if:
1. every non-reserved `.md` has parseable YAML frontmatter,
2. every frontmatter has non-empty `type`,
3. reserved files follow their structure when present.
Everything else is soft guidance; consumers MUST NOT reject bundles for
missing optional fields, unknown types, broken links, or missing `index.md`.

**Relationship to what we want.** OKF explicitly names its neighbors: "LLM
wiki repositories that use markdown + frontmatter as agent-readable knowledge
bases" and "personal knowledge tools like Obsidian and Notion." OKF is the
*specified* intersection of exactly the ideas we're combining.

**Ecosystem.** There is an existing skill for OKF
(`fabricioctelles/skills/okf-open-knowledge-format`, installable with
`npx skills add`) that teaches create/validate/enrich/generate/convert of OKF
bundles, with `references/spec-v01.md`, `references/examples.md`,
`references/conversion.md`, and `scripts/validate.sh`. An Obsidian plugin
("OKF Enforcer") validates OKF v0.2 in-vault. A CLI validator exists
(`okflint`). Google Cloud Knowledge Catalog natively ingests OKF (since June 2026).

**Sources.**
- https://okf.md/spec/ (annotated guide, v0.1 text + v0.2 delta)
- https://github.com/GoogleCloudPlatform/open-knowledge-format/blob/main/SPEC.md (canonical)
- https://okf.md/skill/ (existing OKF agent skill)
- https://community.obsidian.md/plugins/okf-enforcer (Obsidian validator plugin)

---

## 2. llms.txt (v2)

**What it is.** A proposal (Jeremy Howard / Answer.AI, Sep 2024; v2 updated
Aug 10 2026) to put an `/llms.txt` markdown file at a site root — or any
subpath, covering the pages under it — giving agents a concise, expert-level
overview with links to detail. Follows the `/robots.txt` / `/sitemap.xml`
convention: a standard filename agents know to look for.

**Format (strict order):**
1. Optional BOM
2. An H1 with the project/site name (the only *required* section)
3. A blockquote with a short summary
4. Zero or more prose sections (any markdown except headings)
5. Zero or more H2 sections, each a "file list": a markdown list of
   `[name](url): optional note` links pointing at LLM-friendly content
   (ideally `.md` versions of pages)

Conventional `## Optional` section = links an agent may skip when it wants a
shorter context. Companion proposal: serve clean markdown at `page.md` /
`page.html.md`, advertise via `rel="alternate" type="text/markdown"` and
`rel="describedby"` link headers. Widely adopted (Anthropic, OpenAI, Gemini
publish their own llms.txt; Lighthouse audits for it).

**Use for us.** The knowledge directory gets an `llms.txt`-style root entry
file — the agent-readable front door (map of the whole vault) — complementing
OKF's per-directory `index.md` files.

**Sources.**
- https://llmstxt.org/ (v2 spec)
- https://github.com/AnswerDotAI/llms-txt

---

## 3. Agent Skills — the open standard

**What it is.** An open standard (originated by Anthropic, now
[agentskills.io](https://agentskills.io), multi-vendor) for packaging agent
capabilities. A skill is a **folder containing a `SKILL.md`** (YAML frontmatter
with at least `name` + `description`, then markdown instructions), plus
optional `scripts/`, `references/`, `assets/` directories.

**Progressive disclosure:** agents see only name+description at startup, load
full SKILL.md on activation, and load references/scripts on execution.

**Portable frontmatter.** For a skill to be portable across tools, stick to
the spec's fields: `name`, `description`, `license`, `compatibility`, `metadata`,
`allowed-tools`. Claude Code-specific fields
(`disable-model-invocation`, `context: fork`, `hooks`, `paths`, `model`, …)
exist but break portability — avoid in shared skills, or tolerate them
(OpenCode ignores unknown fields; Cursor ignores unknown fields).

**Naming rules (OpenCode, strictest):** `name` must match the directory name,
be lowercase alphanumeric with single hyphens, `^[a-z0-9]+(-[a-z0-9]+)*$`,
1–64 chars. Description 1–1024 chars.

**Sources.**
- https://agentskills.io/what-are-skills.md
- https://github.com/agentskills/agentskills

---

## 4. Skill install locations (OpenCode, Claude Code, Cursor)

### OpenCode (https://opencode.ai/docs/skills/)
- Project: `.opencode/skills/<name>/SKILL.md`
- Global: `~/.config/opencode/skills/<name>/SKILL.md`
- Compat (also read): `.claude/skills/`, `~/.claude/skills/`,
  `.agents/skills/`, `~/.agents/skills/` — all `<name>/SKILL.md`
- Project discovery walks up from cwd to the git worktree root.
- Frontmatter recognized: `name`, `description`, `license`, `compatibility`,
  `metadata`. Unknown fields ignored. Skills surface via the `skill` tool;
  permissions via `opencode.json` → `permission.skill` patterns.

### Claude Code (https://code.claude.com/docs/en/skills)
- Personal: `~/.claude/skills/<name>/SKILL.md` (all projects, this machine)
- Project: `.claude/skills/<name>/SKILL.md`; nested `<subdir>/.claude/skills/`
  supported; enterprise + plugin locations also exist
- Directory name (or `name` frontmatter) becomes the `/slash-command`
- Live change detection on skill dirs; reserved names: `synced`,
  `anthropic-skills`

### Cursor (https://cursor.com/docs/skills)
- Project: `.agents/skills/`, `.cursor/skills/`
- Global: `~/.agents/skills/`, `~/.cursor/skills/`
- Compat (also read): `.claude/skills/`, `.codex/skills/`, `~/.claude/skills/`,
  `~/.codex/skills/`
- Category subfolders are organizational only; identity = folder containing
  SKILL.md. `paths` frontmatter scopes a skill to file globs.
  `disable-model-invocation: true` = slash-command-only behavior.

### The overlap that matters
`~/.claude/skills/<name>/SKILL.md` is read by **all three tools**
(Claude Code natively; OpenCode and Cursor as compat locations). A second
globally-readable location is `~/.agents/skills/` (OpenCode + Cursor).
⇒ Installing one copy into `~/.claude/skills/` (and optionally `~/.agents/skills/`)
covers all three tools with zero duplication. OpenCode's own dir
(`~/.config/opencode/skills/`) is only needed if we use OpenCode-specific
frontmatter/permissions.

---

## 5. PowerShell 7 bootstrapping

**Windows.**
- Recommended: `winget install --id Microsoft.PowerShell --source winget`
  (note: since PS 7.6.0 this installs the MSIX per-user package by default;
  `--installer-type wix` selects the MSI)
- MSI silent (machine-wide, adds to PATH):
  `msiexec /package PowerShell-<ver>-win-x64.msi /quiet ADD_PATH=1 …`
  MSI properties include `ADD_PATH`, `REGISTER_MANIFEST`,
  `ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL`, `USE_MU`/`ENABLE_MU`,
  `DISABLE_TELEMETRY`, `INSTALLFOLDER`. Default install dir:
  `$Env:ProgramFiles\PowerShell\7`
- MSI assets are on GitHub releases (latest stable 7.6.6 as of Sep 2026);
  MSIX also available (`Add-AppxPackage`)
- `winget` is built into Windows 11 / Server 2025, **absent on Server 2022
  and earlier** → script needs a fallback (direct MSI download from GitHub
  releases, or the `aka.ms/install-powershell.ps1` script)
- MSIX limitations: per-user only, no PowerShell remoting, no machine-wide
  config — for "install for the system", MSI is the right package

**macOS.**
- `brew install --cask powershell` (official; cask exists again — a 2021-era
  "unavailable" issue is obsolete) or `brew install powershell` (formula;
  don't mix cask and formula installs without uninstalling first)
- Also: pkg installers on GitHub releases, `.tar.gz`, MSIX irrelevant

**Linux.**
- `apt`/`dnf` via packages.microsoft.com, or snap, or `.tar.gz`

**Bootstrap pattern** (the chicken-and-egg problem): the installer script is
authored for PowerShell 7, but on a machine without `pwsh` it must be runnable
by Windows PowerShell 5.1 (`powershell.exe`) or `cmd.exe`. Standard approach:
1. Detect `Get-Command pwsh`
2. If missing: install (winget → MSI fallback), ideally elevated
   (`Start-Process -Verb RunAs`) for machine-wide install
3. Relaunch the same script under the newly installed `pwsh`
   (new process; PATH refresh needed for current session)

**Sources.**
- https://learn.microsoft.com/en-us/powershell/scripting/install/install-powershell-on-windows
- https://learn.microsoft.com/en-us/powershell/scripting/install/alternate-install-methods
- https://github.com/PowerShell/PowerShell/releases

---

## 6. PARA method (Tiago Forte)

Four top-level containers, ordered by *actionability*, not topic:

| Container | Definition | Lifetime |
| --- | --- | --- |
| **Projects** | Active efforts with a goal and a deadline/finish line | Ends when outcome achieved |
| **Areas** | Ongoing spheres of responsibility to maintain over time (health, finances, team) | Never "done" |
| **Resources** | Topics of interest / reference material for future use | As long as useful |
| **Archives** | Inactive items from the other three | Cold storage |

Key properties: information flows freely between the four (archive → projects
on revival, project → archive on completion); organization is "just in time"
(not "just in case") — don't pre-organize; the mapping question for any item is
*"how actionable is this?"* rather than *"what is this about?"*

**Sources.**
- https://fortelabs.com/blog/para/ (canonical)
- https://www.todoist.com/productivity-methods/para-method

## 7. Zettelkasten

Niklas Luhmann's slip-box method. Core principles (per zettelkasten.de):

1. **Atomicity** — one idea per note; notes are building blocks, not documents
2. **Unique address** — every note has an identifier it can be referenced by
   (Luhmann used branching numbers like `21/3a7`; digital practice: timestamp
   IDs like `202610030915`)
3. **Explicit linking** — the value of the system grows from dense connections
   between notes, not from taxonomy; links create the "second brain" network
4. **Structure notes / indexes** — manual (or generated) entry points that
   order a topic's notes; not rigid folders, but navigational hubs
5. **Written in your own words** — permanent notes are distilled, not copied;
   literature notes (source extracts) feed permanent notes

Tension to design around: Zettelkasten traditionally rejects hierarchical
folders (Luhmann: fixed places kill emergent structure), while PARA *is* a
folder system. Resolution used here: PARA provides the top-level routing
(what is this for?), Zettelkasten practices govern the notes *within*
(atomic notes, IDs, links, structure notes as MOCs). OKF's
"broken links are a feature" philosophy aligns perfectly with Zettelkasten's
"reference before it exists."

**Sources.**
- https://zettelkasten.de/introduction/
- https://zettelkasten.de/atomicity/guide/

## 8. Design synthesis (the shape this implies)

- **Knowledge directory** = one OKF bundle (git repo or `knowledge/` dir),
  PARA top-level dirs (`0-Projects/`, `1-Areas/`, `2-Resources/`, `3-Archives/`)
  with numeric prefixes to fix sort order
- **Every concept note**: OKF frontmatter (`type` required; plus `title`,
  `description`, `tags`, `status`, `generated`, `sources`) **+ Zettelkasten ID**
  (e.g. `id: 202610030915` and/or filename prefix) — OKF explicitly permits
  extension keys
- **Navigation**: OKF `index.md` per directory (PARA areas + topic MOCs as
  Zettelkasten structure notes), plus an `llms.txt` at the bundle root as the
  agent front door (H1, blockquote summary, H2 file-list sections mapping PARA)
- **Log**: `log.md` at root (and optionally per area) as the change journal;
  git remains the ground truth of history
- **The skill(s)**: conform to the Agent Skills spec (only portable frontmatter
  fields), shipped as folders under this repo, installed by `install.ps1` into
  `~/.claude/skills/` + `~/.agents/skills/` (global, covers all three tools)
- **Installer**: `install.ps1` requires pwsh 7; a small bootstrap path handles
  "pwsh missing" (PS 5.1 / cmd entry point → install PS7 → relaunch).
  Supports Windows (winget → MSI fallback), macOS (brew cask), Linux (apt/dnf)
  for the pwsh prerequisite; skill copies are plain file copies everywhere.
- **Existing precedent to evaluate**: `npx skills add
  fabricioctelles/skills/okf-open-knowledge-format` — decide whether to
  reuse/vendor it or build our own knowledge-directory skill (PARA+Zettelkasten
  layer is ours; the OKF mechanics overlap).
