# The Vault has no git repository; OneDrive versioning is its history

Set during the Vault-template prototype (ticket: Vault template). The Vault
gains **no** git repository. History, versioning, and restore come from
OneDrive's version history; the root `log.md` remains the human/agent-readable
journal of significant changes.

Why: the research on Linux OneDrive sync showed two-way-syncing git internals
is a genuine corruption risk; the Vault has exactly one author and small
text files; a local git repo bought diffable history that was never
consulted in practice. Rolling back = OneDrive file versioning.

**Supersedes ADR-0001** (which proposed git inside the Vault with local-only
history — fully reversed). Do not `git init` inside the Vault, and keep `.git`
out of any Vault-adjacent tooling.
