# The Vault lives in OneDrive, with local-only git history

The Vault syncs across devices via OneDrive (user's existing sync), not via a
GitHub remote: a `~/OneDrive/agent-knowledge` per OS. Inside the Vault is a git
repository whose history is purely local (no remote) for diffable, revertible
OKF history. OneDrive versioning is the off-device safety net; GitHub remains
the remote only for `dan-skills` (the Skills + Installer), which is public.

Considered and rejected: vault synced by git remote (reverses the user's
explicit OneDrive choice; two sync mechanisms invite merge hell); no git at all
(loses diffable history OKF explicitly recommends). Linux access rides on the
unofficial `onedrive` CLI (abraungg) or rclone, best-effort — Linux has no
official OneDrive client.

Consequence: `.git` directories live inside a OneDrive-synced tree; occasional
locked-file sync noise is accepted. Do not add a git remote to the Vault without
revisiting this ADR.
