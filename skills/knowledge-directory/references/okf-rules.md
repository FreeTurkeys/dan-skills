# OKF rules — the hard part and the trusted part

One Concept = one markdown file. A bundle is **conformant** iff:

1. every non-reserved `.md` has parseable YAML frontmatter (`---` delimited),
2. every frontmatter has a non-empty `type`,
3. reserved files (`index.md`, `log.md`) follow their structure when present.

Everything else is soft. Missing optional fields, unknown types, broken
links, and absent `index.md` files are all tolerable — never error on them.

## Vault tool-file exemption (ours)

Root `AGENTS.md` and `README.md` are pointers, not Concepts — exempt from
Concept rules. Don't add frontmatter to them and don't flag their absence.

## Frontmatter fields

| Field | Status | Meaning |
| --- | --- | --- |
| `type` | **required** | governed vocabulary string (see `2-Resources/vocabulary.md`) |
| `id` | required (ours) | the Note ID — timestamp, e.g. `"202610031425"`; permanent address |
| `title` | recommended | human title |
| `description` | recommended | one sentence |
| `tags` | recommended | list |
| `status` | recommended | open vocabulary: `draft` \| `stable` \| `deprecated` |
| `generated` | recommended | `{ by: <actor>, at: <ISO-8601-UTC> }` — who produced this |
| `sources` | recommended | where content came from (list of `{ resource, id, title, last_modified }`) |
| `verified` | optional | who confirmed it: `[{ by: ..., at: ... }]` |
| `stale_after` | optional | ISO-8601 trust signal — expired ⇒ propose maintenance |
| `resource` | optional | URI of the underlying asset |

Unknown keys are preserved, never stripped. Actor values:
`human:<id>`, `process:<id>`, or `<producer>/<version>`.

## Reserved files

- `index.md` — per-directory listing; no frontmatter except root may
  declare `okf_version: 0.2`.
- `log.md` — chronological update journal; `## YYYY-MM-DD` headings,
  most recent first.

## Links

Markdown links, bundle-relative `/`-prefixed preferred (stable when files
move within subdirectories). Broken links are legitimate — reference
materials before writing them. Citations go at the end under `# Citations`,
numbered. Body prefers structural markdown (headings, lists, tables,
fenced code).
