# Type Governance — DRAFT design (ticket #9)

Status: DRAFT for human review. Nothing here is final until the human answers
the open questions at the bottom. Do not merge this branch to `main`.

Reads: `CONTEXT.md` (glossary), `RESEARCH.md` §1 (OKF: open vocabulary, no
central registry required, consumers tolerate unknown types; `type` non-empty
is the ONLY hard conformance rule), ADR 0002 (no git in the Vault — OneDrive is
the only history), and the validated Type registry template
(`prototype/vault-template/2-Resources/vocabulary.md`).

Design stance: OKF deliberately de-solemnizes `type` — vs. Luhmann's hardcoded
address types, we treat types as a **thin, fast-changing, locally governed
vocabulary**. Governance keeps the vocabulary *readable and lean*, not
*closed*.

---

## 1. Add-a-type flow (end-to-end)

Trigger: the agent cannot find a fitting type while creating/retyping a note.
The whole flow lives in the `knowledge-directory` skill, referencing
`2-Resources/vocabulary.md` (the Type registry Structure Note).

**Step 1 — Search the registry.** Read `2-Resources/vocabulary.md`'s
`# Vocabulary` table. Match on word/meaning, not exact string: a stored
`Reference` may cover what the draft type `Citation Card` wants to say. Scan
the front doors/sibling notes too — an in-use-but-unregistered type from a
forgotten audit is a reuse candidate first.

**Step 2 — Reuse-vs-new test.** All three must hold to even consider a new
type (DONE test, adapted from Zettelkasten "is the standard fulfilled?"):

- **Does it Distill?** An existing type (default: `Idea`, plus `Project Note`/
  `Area Note`/`Literature Note`/`Structure Note`) represents the note well
  enough — even if not perfectly. If it does, reuse.
- **Would Elaborate ever re-find it?** Would a *second instance* of this type
  ever plausibly exist? If the answer is "only this one note, ever," do not
  mint a type — reuse `Idea` and let `tags` carry nuance.
- **Is it Evolve-able / useful to Generate from?** Will grouping by this type
  ever drive seeking, structure, or retrieval (e.g. an audit sweep, a
  "gather all Playbooks howto")? Types exist to be *grouped by*; a type that
  never partitions anything is a tag.

**Step 3 — Append the row.** Add one row to the `# Vocabulary` table:

```
| `Playbook` | Step-by-step procedure the agent re_executes | 2026-10-03 |
```

- **Type**: the exact frontmatter value. Must make sense as a noun phrase,
  Title Case, no spaces if a one-word form works.
- **Meaning**: one sentence, starts "What it is / what it is for" — the same
  wording a human would skim.
- **Since**: ISO date of first use.

**Step 4 — Convention checks** (reject-and-retype in the same turn if any
fail):
1. Noun, not verb/adjective ("Archiving" ✗→ `Archive Note`).
2. Title Case, exact string match between registry row and the note's
   frontmatter `type` (a registered `Playbook` used as `playbook` in
   frontmatter is a typo — fix the note, don't add a second row).
3. Not a near-duplicate of an existing row (diff against each `Meaning`; if
   two rows' meanings would ever match the same note, merge).
4. Not a synonym that duplicates PARA-structural types (`Project Note`,
   `Area Note`) — those are reserved for their structure role.

**Step 5 — Journal.** Append to the vault-root `log.md`:
`* **Type**: Added \`Playbook\` to the Type registry ([vocabulary](/2-Resources/vocabulary.md)).`
Plus `generated.at`-style `since` date in the row itself. One entry per
minted type, in the same `## YYYY-MM-DD` section as the note's own `Create`
entry.

**Step 6 — Who may do it.** [DRAFT recommendation] The agent may append a row
autonomously the first time it needs a type that passes Steps 2–3, and MUST
mention the minted type to the human in the same turn ("minted type
`Playbook`, registered with meaning …"). The human can veto later — the audit
log (§3) is the veto mechanism. Rationale: the registry is one comment-edit in
OneDrive, fully revertible, and OKF already tolerates unknown types forever —
there is no corruption risk worth a blocking approval round-trip. Revisit if
mint-rate turns out to exceed ~2/month.

## 2. Registry file contract

`2-Resources/vocabulary.md` is the ONE Structure Note whose rows are
machine-validated (the validator treats it specially, keyed by
`title: Type registry` + its fixed `id: "202610030930"` — resilient to path
moves).

**Frontmatter (fixed at creation):**

```yaml
type: Structure Note
id: "202610030930"
title: Type registry
description: The governed vocabulary of frontmatter `type` values, and how to add to it.
status: draft
tags: [meta, vocabulary, governance]
```

**Body schema (exact):**

- `# Vocabulary` — one markdown table, exactly these columns:
  `| Type | Meaning | Since |` (title, description, ISO date).
- `# Add a type` — the flow from §1, one short numbered list.
- `# Audit log` — appended audit entries: `## YYYY-MM-DD` heading under it,
  each listing: types added, types retired/renamed, notes retyped, dupes
  merged.

**Row invariants (validator-enforced on this file):**
- Every row's `Type` cell: backticked, Title Case, unique (case-insensitive).
- Every row's `Meaning` non-empty.
- `Since` parses as an ISO date (`YYYY-MM-DD` or the literal `day one`).
- No duplicate case-insensitive type strings.

The registry reflects reality, not ambition: a type counts as "in the
vocabulary" iff its row exists here; the validator's `type-in-registry` check
scans this table.

## 3. Periodic consolidation audit

**Trigger [DRAFT rec: on-demand + quarterly].** Two supported cadences, both
manual:

- A named invocation of the `knowledge-directory` skill: the human says
  "run the type audit" (agent-initiated audit is NOT automatic — no scheduled
  tasks exist in this system).
- A quarterly reminder embedded in the vault-root `llms.txt` front door
  ("last type audit: 2026-10-03 — run a type audit if older than ~3 months
  or 20+ new notes").

**The sweep** (agent runs, human reacts):

1. **Collect**: scan every `.md` (except reserved `index.md`/`log.md`)
   frontmatter for `type` values → count per value.
2. **Compare** to registry rows → classify each in-use value:
   - `registered` — fine.
   - `unregistered` — in use, no row: report and (provisionally) register it,
     flagged as such.
   - `registered-but-unused` — row exists, zero notes: candidate for
     retirement.
3. **Near-duplicate check**: for each pair of in-use types with overlapping
   meanings (semantic, not string — this is short text; the agent judges),
   list them as merge candidates with example notes.
4. **Fat-vocabulary check**: if the registered-but-in-use count exceeds
   ~15, flag: the vocabulary's whole point is skim-ability
   (thin, fast-changing vocabulary vs. Luhmann's hardened one).

**Report:** written into `# Audit log` as a `## YYYY-MM-DD` entry and
summarized to the human in one message.

**Consolidation mechanics [DRAFT rec: agent proposes, one confirmation for a
batch, retype = frontmatter-only rewrite].** Retypes rewrite frontmatter
**only** — never body/links. Type renames do NOT orphan: nothing addresses a
Concept by its `type` (renames only risk search/grouping loss, which is
acceptable for a session); a retired type leaves a one-line tombstone in that
audit's entry ("`Citation` retired → `Literature Note`, 3 notes retyped").
Unregistered-but-used types are registered, never blanket-retyped to
`Idea` — that would delete human intent.

## 4. Validator enforcement

- `type` non-empty: **error, always** (OKF's only hard rule).
- `type-in-registry` (`Playbook` in use, no row found): **warn, not error.**
  The audit sweep already surfaces it; blocking would contradict OKF's
  "consumers MUST NOT reject … unknown types."
- Registry file invariants (§2): error (it's the governance artifact; a
  malformed table means the next audit mints nothing correctly).
- Duplicate/case-clash types in use: warn, promoted to an audit item.

---

## Open questions for the human (each with a recommendation)

1. **Approval step for minting a new type?**
   *Rec: no blocking approval — agent mints autonomously when Steps 2–4 pass,
   Must mention the mint to you in the same turn; the audit log is the veto
   mechanism.* (Revisit if mint-rate > ~2/month.)
2. **Audit cadence?**
   *Rec: on demand ("run the type audit") + a reminder line in `llms.txt`
   ("older than ~3 months or 20+ new notes"). No hard calendar, no automatic
   triggers.*
3. **May the agent auto-consolidate obvious duplicates, or must every retype
   be confirmed?**
   *Rec: one batch confirmation, not per-note — the agent lists every
   proposed retype in one message; you say "yes" once, it executes. Zero
   unconfirmed rewrites.*
4. **Registered-but-unused types: auto-retire (delete row) or keep forever?**
   *Rec: auto-retire in the audit *report only* — rows are deleted only on
   your explicit "retire it"; tombstone in the audit entry either way.*
5. **May you veto after the fact — de-register a type and force a retype at
   any time, not just at audits?**
   *Rec: yes — de-registering is just an audit entry + a confirm batch;
   you never need to wait for the next audit.*
6. **Fat-vocabulary threshold: warn when more than 15 in-use types?**
   *Rec: yes, 15 — flag only, never auto-prune.*
7. **Naming: enforce Title Case + noun for new types, grandfathering any
   older drift?**
   *Rec: yes — validators error on new rows, warn (list in the audit) on
   legacy drift.*

## Rulings (2026-10-03, ticket #9 decisions — final)

All seven recommendations accepted:

1. Mint approval: agent mints autonomously, surfaces each mint in-turn; audit log is the veto channel
2. Audit cadence: on demand + quarterly reminder surfaced in the Front door (`llms.txt`); no background jobs
3. Consolidation: one batch "yes" per retype batch; never per-note; zero unconfirmed rewrites
4. Unused types: report-only flag; rows deleted only on explicit say-so
5. Post-hoc veto: de-register anytime = audit entry + one batch confirmation + `log.md` journal entry
6. Fat-vocabulary threshold: >15 in-use types flags consolidation review only
7. Naming: new registry rows must be Title Case nouns; legacy drift warn-only

Canonical facts: `2-Resources/vocabulary.md` is the machine-validated Type registry (fixed `id: "202610030930"`); validator errors on empty `type`, warns when `type` is unregistered, errors on registry-file invariants. From `prototype/type-governance/DESIGN.md` (branch `prototype/installer` tip — note: the file was committed there by a rebase collision).
