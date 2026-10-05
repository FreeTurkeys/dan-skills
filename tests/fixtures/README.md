# Test fixtures

## `vault/`

A small, **conformant** OKF vault used to exercise the validator
(`skills/knowledge-directory/scripts/Test-Vault.ps1`). It is a snapshot of the
throwaway template validated on the `prototype/vault-template` branch (ticket
[#2](https://github.com/FreeTurkeys/dan-skills/issues/2)), preserved as the one
piece of that prototype main could not regenerate.

It carries the full shape on purpose — PARA containers, a topic directory two
levels deep (`2-Resources/agent-skills/{ideas,literature}/`), a Project Note, an
Idea, a Literature Note, a Structure Note, the Type registry, `log.md`,
`AGENTS.md`, and a generated `llms.txt` — so validator tests have something real
to chew on.

Current state:

```
pwsh -NoProfile -File skills/knowledge-directory/scripts/Test-Vault.ps1 \
  -VaultPath tests/fixtures/vault
# OK: conformant (0 errors, 1 warning, 4 in-use types)
# the one warning: registry type 'Area Note' unused — correct for a fixture
```

Rules for using it (enforced as [#7](https://github.com/FreeTurkeys/dan-skills/issues/7) grows):

- **Keep it conformant.** A fixture that fails validation is a bug in the
  fixture, not a new rule.
- **Drift tests copy first.** Mutate a throwaway copy (`cp -R`) to test drift,
  error, or merge paths; never edit the fixture in place.
- Prefer adding a file that shows a *new* shape over editing an existing one, so
  earlier tests keep their subject.
