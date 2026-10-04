---
name: knowledge-directory
description: >-
  Maintain Dan's agent knowledge Vault — an OKF-format, PARA-organized
  Zettelkasten directory of notes (usually synced by OneDrive). Use when
  capturing or editing notes in the Vault (creating a Concept, linking,
  updating index.md, regenerating llms.txt, appending log.md), when the Vault
  needs validating or shows staleness, and whenever the user mentions the
  Vault, the knowledge directory, or asks the agent to remember something.
  Do not trigger for coding or research work that makes no Vault change.
metadata:
  dan-skills: v0.3-prototype
  vault-default: ~/OneDrive/agent-knowledge
---

# knowledge-directory

You maintain Dan's knowledge **Vault** while working. Judgment is yours;
mechanics belong to the `scripts/` (all pwsh 7). Pairs with the type
governance contract in `docs/type-governance.md` (repo) — its rules are
summarized here as you need them in-session.

## 1. Find the Vault

Resolve in order, stopping at the first that works:

1. `$DANSKILLS_VAULT`
2. `~/OneDrive/agent-knowledge`
3. Walk up from the current directory: a directory with a `log.md` and a
   `0-Projects/` is the Vault.

If none: say what you looked for and offer `scripts/New-Vault.ps1` — do not
create a Vault unasked. If a candidate path exists but has no `llms.txt`,
it may be half-synced; treat as present but verify before writing.

## 2. Capture a Concept (a new note)

1. Decide placement with the PARA rule (see `references/vault-practice.md`):
   the most actionable container wins.
2. Run `scripts/New-Concept.ps1 -Path <dir> -Title "..." [-Type <type>]`.
   It mints the Note ID, refuses collided filenames, prints the file path.
3. Fill in `description` (one sentence), `tags`, and set
   `generated: { by: <your model id>, at: <now> }` — never leave the
   placeholder. `status: draft` is correct for fresh captures.
4. `type` must be non-empty (always). Check the registry — the Vault's
   `2-Resources/vocabulary.md` is the single source of truth for types.
   Fit an existing row when one works; otherwise add a row per the flow in
   that file (agent may mint; mention it in-turn; the audit log is the veto
   channel). Unknown-but-unregistered `type` values get only a validator
   warning — the registry update is still your job before you finish.
5. Link: bind the new Concept into existing context (see
   `references/vault-practice.md`) — links from related notes, plus membership
   in the topic's Structure Note / the container's `index.md`.
6. Append one line to the Vault `log.md` under `## <today>` (create the
   heading if it is not already the newest section).

## 3. Update Structure notes and indexes

`index.md` files are curation, not a mechanical listing — order by what
matters first, prune dead entries, keep one topic per Structure Note.
Edit these by hand; do not script-generate them.

## 4. Regenerate the Front door

After any structural change (files added, moved, renamed; registry updated;
indexes restructured), run
`scripts/Update-FrontDoor.ps1 -VaultPath <vault>`. The script owns the H2
file-list sections of `llms.txt` including the computed type-audit line;
you own the H1, blockquote, and prose sections. Never hand-edit the
generated lists; never let the script touch your prose.

## 5. Validate and tend

Run `scripts/Test-Vault.ps1 -VaultPath <vault>` after sessions that touched
structure, and when the user asks "is anything stale?".

- `ERROR` lines are always fixed in-session — never leave them.
- `WARN` lines are reported to the user with a one-line proposed remedy;
  fix on their nod.
- The staleness section lists notes past `stale_after` or `status:
  deprecated` — propose maintenance (refresh, re-verify, or retire) rather
  than rewriting content unasked.

Idempotent edits only: never reuse a Note ID, never renumber; renames are
free because nothing addresses files by name.

## 6. Never

- Never lint OKF-optional gaps (missing tags, missing `sources`, unknown
  types, broken links) as errors — conformant bundles tolerate all of that.
- Never touch anything outside the resolved Vault path.
- Never `git init` in the Vault (ADR-0002 — OneDrive is the history) or
  recommend git-based tooling there.
- Never write bulk prose into `index.md`/`llms.txt` by hand beyond what
  section 3/4 assigns to you.
