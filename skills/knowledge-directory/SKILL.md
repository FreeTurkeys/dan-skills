---
name: knowledge-directory
description: >-
  Maintain Dan's knowledge Vault — an OKF-format, PARA-organized
  Zettelkasten directory of notes. Use when working in the Vault: capturing a
  Concept, linking notes, tending indexes, regenerating llms.txt, appending
  log.md, validating, staleness sweeps. Also use when the user asks you to
  remember or note something for later. Scope: Vault work only.
---

# knowledge-directory

You maintain Dan's knowledge **Vault** while working. Judgment is yours;
mechanics belong to the `scripts/` (all pwsh 7). Governing rules, in short:
`type` is governed by the Vault's own registry, minted types are mentioned
in-turn, and nothing gets consolidated or deleted without one batched nod.

## 1. Find the Vault

The Vault location is a fact on disk, not a guess. Run:

```
pwsh -NoProfile -File scripts/Resolve-VaultPath.ps1
```

Exit 0 prints the path — use it for every script call below. Exit 2 means
no vault is configured, and you must ask the user (never pick for them):

1. Ask: "Where's your Vault? Default `~/OneDrive/agent-knowledge`."
2. If their path doesn't exist, ask once more: create a new Vault there
   (`New-Vault.ps1 -VaultPath <path>`, which stores the config), or point
   somewhere else?
3. Store the answer — `Set-VaultConfig.ps1 -VaultPath <path>` — then re-run
   the resolver. One question, once per machine.

If the resolved path exists but has no `llms.txt`, it may be half-synced:
treat it as present, but read before you write.

`-VaultPath` on any script is an explicit override — use it for tests or a
second Vault, never as a substitute for configuring the machine.

## 2. Capture a Concept (a new note)

1. Decide placement with the PARA rule (see `references/vault-practice.md`):
   the most actionable container wins.
2. Run `scripts/New-Concept.ps1 -Path <dir> -Title "..." [-Type <type>]`.
   It mints the Note ID, refuses collided filenames, prints the file path.
3. Fill in `description` (one sentence), `tags`, and set
   `generated: { by: <your model id>, at: <now> }` — never leave the
   placeholder. `status: draft` is correct for fresh captures.
4. `type` must be non-empty (always). The Vault's `2-Resources/vocabulary.md`
   is the single source of truth for types. Fit an existing row when one
   works; otherwise mint one per that file's `# Add a type` flow (Title Case
   noun, append the row, mention the mint in-turn — the audit log at the
   bottom of the file is the veto channel). Unregistered types draw only a
   validator warning; the registry update is still yours before you finish.
5. Link: bind the new Concept into existing context (see
   `references/vault-practice.md`) — links from related notes, plus membership
   in the topic's Structure Note / the container's `index.md`.
6. Append one line to the Vault `log.md` under `## <today>` (create the
   heading if it is not already the newest section).

**Done when**: `description` and `generated.by` are filled, `type` is
registered, the note is linked from *and* to related notes, it is listed in
its Structure Note or `index.md`, and `log.md` has its line.

## 3. Update Structure notes and indexes

When an index drifts from its directory, or a topic needs a map: `index.md`
files are curation, not a mechanical listing — order by what matters first,
prune dead entries, keep one topic per Structure Note. Edit these by hand;
do not script-generate them.

**Done when** the order reflects importance and no dead entries remain.

## 4. Regenerate the Front door

The script owns `llms.txt`; you own the H1, blockquote, and prose sections.
Run `scripts/Update-FrontDoor.ps1` when a change actually alters the front
door's contents — indexes restructured, the Type registry updated, a
Structure Note added/moved/renamed, a PARA container added. Capturing an
ordinary Idea does not: it is not listed in `llms.txt`. Hand-edit prose;
never hand-edit the generated H2 lists.

**Done when** the script exits 0 and you have not touched its sections.

## 5. Validate and tend

Run `scripts/Test-Vault.ps1` after sessions that touched structure, and when
the user asks "is anything stale?".

- `ERROR` lines are always fixed in-session — never leave them.
- `WARN` lines are reported to the user with a one-line proposed remedy;
  fix on their nod.
- The staleness section lists notes past `stale_after` or `status:
  deprecated` — propose maintenance (refresh, re-verify, or retire) rather
  than rewriting content unasked.

**Done when** the Vault is conformant: no ERROR lines remain.

## 6. Always

- Judge conformance by OKF's three golden rules only — non-empty `type`,
  parseable frontmatter, reserved-file structure. Everything else (tags,
  sources, unknown types, broken links) is soft: report it, don't enforce it.
- Confine writes to the resolved Vault path.
- OneDrive is the Vault's history — the Vault carries no git and needs none
  (ADR-0002).
