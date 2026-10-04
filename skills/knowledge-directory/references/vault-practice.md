# Vault practice — PARA placement, Note IDs, linking, log

## PARA placement

Ordering by actionability; ask in this order:

1. Is this a single active effort with a finish line? → `0-Projects/<project-dir>/`
   (one overview note per Project, type `Project Note`).
2. An ongoing responsibility without a finish line? → `1-Areas/`
   (one overview note per Area, type `Area Note`).
3. Knowledge for later use, by topic? → `2-Resources/<topic-dir>/`
   (atomic notes + topic Structure Notes).
4. Retired material → `3-Archives/`. Archived stays self-contained —
   move wholesale, don't shred.

When nothing clearly matches, default to `2-Resources/<topic-dir>/` under
the most relevant existing topic; invent a topic dir only when no home fits.

## Note IDs

Minted at capture by `New-Concept.ps1` (timestamp, second precision).
Never reused, never renumbered, never inferred from date-with-gaps; two
notes taken in the same minute get distinct IDs via the retry loop.
Filenames are clean kebab-case descriptions — renames and moves never
break the address (the ID travels in frontmatter).

## Filename and prose style

- Filenames: kebab-case, descriptive, no type prefix, no ID prefix.
- One idea per note (type `Idea`); state it in our own or the agent's
  distilled words — quotes belong in `Literature Notes`.
- Structure Notes are curated maps (one topic each), maintained by hand;
  `index.md` files are the container listings — also maintained by hand,
  never script-generate either.

## Linking

Link generously, both directions when possible: from the new note to its
context, and add the new note to the Structure Note / `index.md` that
organizes it. Bundle-relative `/` links preferred. Dangling links are fine.

## log.md

One line per significant Vault change, under the newest `## YYYY-MM-DD`
heading (create it directly under the H1 if it's not the newest yet).
What counts as significant: captures, moves, renames, type changes,
de-registrations, regenerated front door. Typo-fixes don't need a line.

## Type registry (governance essentials)

Registry lives at `2-Resources/vocabulary.md` — never duplicate it.
Match on meaning, not string. Agent may mint: append the row
(`Type | Meaning | Since`, Title Case noun), mention the mint in-turn.
The audit log at the registry's bottom is the veto channel; consolidation
never rewrites a note without one batched user confirm.
