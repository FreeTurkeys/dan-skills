# Survey: existing OKF skill + GCP spec v0.2

Resolves: https://github.com/FreeTurkeys/dan-skills/issues/5
Date: 2026-10-03 (verified current — both repos cloned/fetched today; fabricio skill SKILL.md dated 2026-08-25, spec v2.0)

## Sources inspected

- **fabricioctelles/skills** — shallow-cloned. Skill lives at
  `skills/okf-open-knowledge-format/` (note: `okf-…` under `skills/`, not as documented in some issue text).
- **GoogleCloudPlatform/open-knowledge-format** — shallow-cloned. `SPEC.md` at HEAD is v0.2.

## fabricioctelles/skills/okf-open-knowledge-format — file-by-file

| File | Size | What's in it |
|---|---|---|
| `SKILL.md` | 694 loc | Full agent playbook: frontmatter field tables (core + v0.2 trust/lifecycle/provenance + Attested Computation), actor convention, trust tiers, create-bundle workflow (9 steps), Attested Computation guide, validation section, enrichment workflow, v0.1→v0.2 migration, conversion quick rules, guardrails, the GCP `kcmd`/Knowledge Catalog integration summary, output format. |
| `references/spec-v01.md` | 451 loc | Legacy spec copy. |
| `references/spec-v02.md` | 1006 loc | Vendored copy of GCP `SPEC.md`. Diffed against upstream: **only typographic char differences** (`=>` vs `⇒`); substantively identical (different md5 only from those chars). |
| `references/examples.md` | 643 loc | Three worked bundles: finance analytics with Attested Computations, e-commerce analytics, SaaS incident playbooks. |
| `references/conversion.md` | 141 loc | Converters: Notion export → OKF (property→frontmatter map, UUID filename cleanup), Obsidian vault (`[[wikilinks]]` → md links, inline tags → frontmatter), CSV/spreadsheet (row = concept). |
| `scripts/validate.sh` | 270 loc | Bash validator (see below). |

### Interesting extra: the skill now also mentions **okflint**
SKILL.md §"Validate a Bundle" prefers a third-party Python linter, [`okflint`](https://github.com/mattdav/okflint) (18 rules, manifest-driven profiles, wikilink resolution, `--json`, exit codes 0/1/2), with the bundled bash script as fallback. Worth evaluating separately if we want a cross-vault validator — but see verdict.

### License
Root `LICENSE` = **Apache-2.0** (skill dir has no separate LICENSE; also NOT MIT — our inheritance/notice obligations: keep license text + attribution if we vendor code). GCP repo is also Apache-2.0 (`LICENSE.md`). Both fine for vendoring with attribution.

### validate.sh quality assessment
Read in full. Solid, defensive bash: `set -euo pipefail`, null-delimited `find` (safe filenames), documented E1–E4 errors + W1–W7 warnings, legacy `timestamp` migration warning, `sources` resource check via awk block parsing, `status` vocabulary check, `stale_after` staleness check, human/machine verified counts, colored summary, exit code = error count. Known limits (all prependable in our own version):
- Returns 0 only if zero errors but doesn't distinguish error types in exit code.
- Frontmatter extraction (`head -1` + `sed`) fails on `--- ` with trailing space or BOM.
- `human:`-verification detection is a grep on the whole frontmatter, not on `verified` specifically (could false-positive on e.g. `sources[].author: human:x`).
- No `okf_version` declaration check at bundle root.

**Reusable?** Yes — it's a good skeleton; we'd fork-and-extend rather than depend on the skill to get it.

## GCP SPEC.md v0.2 — exact delta from v0.1 (spec §13)

### Breaking (2)
1. `timestamp` → `generated: { by, at }`.
2. Body `# Citations` list → frontmatter `sources` (+ per-claim `[^id]` footnotes).

### Additive
- Frontmatter families: **trust/provenance** — `sources` (per-entry `resource` REQUIRED, `id`, `title`, `author`, `usage_count`, `last_modified`) + sibling `usage_window {from,to}`; `generated {by,at}`; `verified {by,at}`; **lifecycle** — `status: draft|stable|deprecated` (default `stable`), `stale_after: <ISO8601>`.
- New concept type **`Attested Computation`** with required `runtime` (`bigquery|postgres|dbt|python|Looker`…), `parameters: [{name,type,required}]`, `computation`, `executor {resource, receipt:[...]}`, `attester {resource}`, and new conventional heading `# Computation`.
- Actor convention for identity strings: `producer/version`, `human:<id>`, `process:<id>`; trust tiers derived from `human:` prefix (unverified < machine-confirmed < human-reviewed).
- Bundle-root `index.md` MAY declare `okf_version: "0.2"` (§12 minor-version scheme).
- Everything from v0.1 (required `type` only; recommended title/description/resource/tags; reserved `index.md` (no frontmatter) / `log.md` (ISO-8601 `## YYYY-MM-DD` headings, newest first); broken links permitted) carried forward unchanged.
- Appendix A: full income-statement worked example migrating v0.1 → v0.2.

### What v0.2 must a personal knowledge vault support from day one?
- **Must**: `generated` (+ fall back-to/parse `timestamp`), `sources` with `resource`-required entries, `status`, `stale_after` staleness reporting, actor strings, `log.md` ISO headings, `okf_version` on root `index.md`. These are cheap and make the vault trustworthy/self-describing.
- **Optional/defer**: `verified` semantics (we can record but strictly not fabricate), `usage_window`/`usage_count` liveness, and **Attested Computation** whole concept — it presumes sanctioned numeric computations with executor/attester code; irrelevant for PARA+Zettelkasten notes. We should still *permit* the type (validator rule E4) so the vault stays spec-conformant, but never generate it.

## GCP repo beyond the spec (borrowable patterns)

`src/reference_agent/` is a Python ADK/Gemini enrichment agent (BigQuery pass + web pass, two-pass: enrich/mint/skip) plus an HTML force-graph **visualizer** (`visualize` subcommand) for any bundle, `bundles/` samples, `connectors/gcp-knowledge-catalog.md`. Nothing to vendor directly — the visualizer idea (self-contained HTML index of the vault) is a nice future feature.

## Usefulness for our knowledge-directory skill (PARA + Zettelkasten on OKF)

Directly relevant borrowables:
1. **conversion.md** — Notion/Obsidian/CSV import guides; Obsidian wikilink conversion will matter since our vault may contain `[[wikilinks]]`.
2. **SKILL.md's guardrails + conformance reporting format** — the E/W code scheme, "never invent data", "preserve unknown fields", "don't fabricate verification" are exactly right for a personal vault.
3. **validate.sh** — fork and extend: add `okf_version` check, tighten `human:` detection, maybe parse frontmatter with a real YAML tool later.
4. **Freshness as first-class** (`stale_after`) — a personal vault's killer feature: weekly review = staleness sweep.

## Verdict (answers dev's question)

**Build own skill + borrow patterns, as the dev leaned — confirmed, and now for concrete reasons:**

1. The fabricio skill is **enterprise/BigQuery-shaped**: heavy on `kcmd`, Knowledge Catalog, RichQuery-style enrichment, Attested Computations. A personal PARA+Zettelkasten vault needs a small fraction of this.
2. It **imports another tool (okflint)** with install-prompt behavior in SKILL.md — a dependency we don't control and don't need as a hard path.
3. Its SKILL.md is 694 loc — `always-loaded` skill overhead targeted at creating new bundles, not at maintaining/curating an existing vault (backfilling, reviews, staleness sweeps, PARA/Zettel reuse cycles) which is our core job.
4. What we *do* borrow is cleanly severable: the E/W validator scheme (Apache-2.0, attribution), conversion guides, guardrails, and the spec field tables. We should vendor `SPEC.md` (or a condensed reference to it) as our `references/spec-v02.md` with license notice, and write our own thin SKILL.md around vault maintenance.

Licensing note: both repos are **Apache-2.0, not MIT** — vendoring requires preserving the license text ("NOTICE"-style attribution is also present in some fabricio siblings, e.g. deslop-writing).
