# Survey: Linux OneDrive sync options

Research ticket: [#5](https://github.com/FreeTurkeys/dan-skills/issues/5) · Survey date: **2026-10-03** (facts are date-sensitive; re-verify before deciding).

## Context

We need a small markdown vault on the Windows side to appear on one Linux machine, synced **both ways** (read/write), via the installer's PowerShell setup plus minimal human steps. Note: the ticket title said "abraungg/onedrive (Go client)" — the actual project is **abraunegg/onedrive** and it is written in **D**, not Go. Corrected below.

**Microsoft's official stance: there is no official OneDrive client for Linux.** Microsoft does not provide one for desktop Linux; third-party clients use public Microsoft Graph APIs. Sources: [fosslinux guide](https://www.fosslinux.com/8835/how-to-sync-microsoft-onedrive-with-linux.htm) ("Microsoft has no official Linux client for OneDrive"), [Linux Stans](https://linuxstans.com/microsoft-onedrive-on-linux/) ("Microsoft OneDrive doesn't have an official… client"), [Microsoft Community thread](https://techcommunity.microsoft.com/discussions/microsoft-365/onedrive-on-linux/1318644) where the abraunegg client is the de-facto answer.

## Project health sweep (verified 2026-10-03)

| Option | What it is | Health as of Oct 2026 | Auth flow (headless?) | Two-way sync story |
|---|---|---|---|---|
| **abraunegg/onedrive** ("OneDrive Client for Linux") | CLI client, syncs a local dir against OneDrive via Microsoft Graph. Language: **D**. [GitHub](https://github.com/abraunegg/onedrive) · [releases](https://github.com/abraunegg/onedrive/releases) | **Very healthy.** 12.9k stars, last commit 2026-10-03, latest release **v2.5.11 (2026-06-30)**; packaged in Fedora (fc44, 2.5.11), AUR `onedrive-abraunegg`, Debian/Ubuntu PPAs. v2.5.x is the supported line | Default: interactive browser OAuth2 (redirect on `127.0.0.1:53100`). Headless: (a) config option `use_device_auth = "true"` → OAuth2 Device Code flow, prints `https://microsoft.com/devicelogin` + a short code; (b) `--auth-files authUrl:responseUrl` / `--auth-response` for scripted/non-interactive auth. **Limitation: device-code flow works for Entra ID (work/school) accounts only; personal `@outlook.com`/`@hotmail.com` accounts should use interactive auth** ([usage.md](https://github.com/abraunegg/onedrive/blob/master/docs/usage.md)) | True real-time two-way sync (inotify + monitor), upload/download-only modes, `sync_list` filtering, conflict backups. Handles repo-style trees with `skip_dotfiles`/`skip_dir` |
| **rclone `onedrive` remote** | "rsync for cloud storage"; command-driven. [docs](https://rclone.org/onedrive/) · [releases](https://github.com/rclone/rclone/releases) | **Very healthy.** v1.75.1 (2026-09-04), monthly releases, 59k+ stars | Interactive: local loopback browser OAuth (`127.0.0.1:53682`). **Headless: no device-code flow for OneDrive** — [issue #9452 open](https://github.com/rclone/rclone/issues/9452) (working patch exists on a branch, not merged as of 1.73–1.75). Headless recipe = run `rclone authorize "onedrive"` on a browser machine and paste the token JSON ([remote_setup](https://rclone.org/remote_setup/)) | No built-in watcher. `rclone bisync` (bidirectional, [docs](https://rclone.org/bisync/)) works but is **flagged experimental-ish**: requires a first `--resync`, re-`--resync` after a failed run, cron-style scheduling, care with deletion propagation. `rclone mount --vfs-cache-mode full` gives a live FUSE view instead |
| **GNOME Online Accounts + msgraph-Gvfs (Ubuntu 24.04+/Fedora)** | Built-in OneDrive mount in Nautilus via GOA and the `msgraph` GVfs backend, with Microsoft's blessing ([OMG Ubuntu](https://www.omgubuntu.co.uk/2024/04/set-up-onedrive-file-access-in-ubuntu), [follow-up fix](https://www.omgubuntu.co.uk/2024/05/fix-ubuntu-onedrive-account-error)) | Declared working on Ubuntu 26.04 LTS (2026 reports in [MS Community thread](https://techcommunity.microsoft.com/discussions/microsoft-365/onedrive-on-linux/1318644)) | Browser sign-in inside the Settings GUI. **Not scriptable headlessly** (GOA requires a GNOME desktop session) | On-demand virtual mount (browse/copy), not a real sync engine; reported flaky for business accounts ([AskUbuntu](https://askubuntu.com/questions/1524819/how-to-mount-onedrive-in-ubuntu-24-04)) |
| Other / declined | `skilion/onedrive` (original fork; **dead**, abandoned → abraunegg forked it 2018); `onedriver` (FUSE mount, far less maintained vs abraunegg per [Reddit](https://www.reddit.com/r/linuxquestions/comments/10ps2er/any_onedrive_clients/)); `Insync` (proprietary, paid) | Not candidates | — | — |

## Detail: abraunegg/onedrive auth & automation

- Device-code flow is a **config option, not a CLI flag**: `use_device_auth = "true"` ([application-config-options.md](https://github.com/abraunegg/onedrive/blob/master/docs/application-config-options.md)). First run then prints the `microsoft.com/devicelogin` URL + code, ~15 min validity ([usage.md](https://github.com/abraunegg/onedrive/blob/master/docs/usage.md)).
- **Caveat:** several users report `v2.5.10` stable builds not honoring/exposing device auth ([#3680](https://github.com/abraunegg/onedrive/discussions/3680), [#3674](https://github.com/abraunegg/onedrive/discussions/3674)); behavior was added in [v2.5.6](https://github.com/abraunegg/onedrive/releases/tag/v2.5.6) via #3313. Must verify against the exact packaged version we install.
- **Device flow is Entra-ID-only.** For personal Microsoft accounts the maintainer explicitly recommends interactive browser auth. Workaround without a local browser: run auth on another machine, then pass the redirect URL to `onedrive --auth-response '<url>'`, or use `--auth-files`.

## Detail: rclone for a small markdown vault

- `rclone sync` (one-way) is rock solid; `bisync` is the two-way path: first run `rclone bisync path1 path2 --resync`, then scheduled runs **without** `--resync`; `--check-access` (`RCLONE_TEST` sentinel files) recommended for safety ([bisync docs](https://rclone.org/bisync/)).
- Known-mode failure: any interrupted/failed bisync run requires a re-`--resync`; concurrent edits resolve last-writer-wins per run, not per keystroke ([comparison discussion](https://rcloneview.com/support/blog/bisync-bidirectional-cloud-sync-rcloneview)).
- Alternative: `rclone mount` (FUSE) is simpler semantics but slow-hash/liveness quirks and no conflict handling; bisync + one machine is generally better for a small vault.
- Auth is the weak spot for automation: no OneDrive device-code grant in rclone (issue #9452 still open at 1.7x).
- Note: OneDrive shares with you must be authenticated as the folder **owner** ([ligos.net walkthrough](https://blog.ligos.net/2025-05-30/Connecting-To-OneDrive-With-RClone.html)) — irrelevant for our own vault.

## Practical automation split (installer vs human)

**PowerShell installer can do hands-off:**
- Install the package non-interactively (`apt install onedrive` / AUR / dnf / download binary), or install rclone.
- Pre-write the client config (`sync_dir` pointed at the vault path, exclusions listed below) and a systemd user unit for continuous/watch sync.
- Kick off auth in a way that **prints** the device-code URL + code (`onedrive` with `use_device_auth=true`, or `onedrive --auth-response '<url>'` after a sibling machine's auth).

**Must be a human checklist step:**
- **Open the login URL on any browser-capable device, sign in with MFA, and enter the printed code.** No tooling can complete the Microsoft sign-in for them (MFA, TOS consent).
- If the account is **personal** (not Entra ID): complete auth interactively on the Linux box's browser, or do the two-machine `--auth-response` dance by hand.
- First-run supervision & verifying the initial sync completed cleanly.

## Which Vault files must reach Linux & .git caveats

- Assumption for downstream decision: **whole vault tree, read/write** — no exclusions beyond VCS internals.
- **`.git/` inside the synced tree is the main hazard.** With abraunegg: `.git` files sync by default (`skip_dotfiles = "true"` opts out explicitly, and even then dot-dir exceptions are awkward — [#3416](https://github.com/abraunegg/onedrive/issues/3416)); reports of `.git` coming back mangled from the cloud ([#1596](https://github.com/abraunegg/onedrive/issues/1596)). With rclone: a bisync'd `.git` risks lock-file/object churn and repeated recopy logic. **Recommendation candidate: exclude `.git/` (and other dot dirs) from the synced scope** — the vault stays synced; git stays local; or keep the git repo outside the synced path.
- abraunegg also warns: changing filter options (`skip_*`, `sync_list`) triggers a forced full revalidation ([discussion #3183](https://github.com/abraunegg/onedrive/discussions/3183)) — so set exclusions **once, before first sync**.

## Candidate recommendation (boxed — decision happens in a later grilling ticket)

> **Facts:**
> -abraunegg/onedrive is the most-maintained, most-battle-tested Linux OneDrive sync client (v2.5.11, Jun 2026; commits as of Oct 2026; packaged in mainstream distros), does real two-way sync with watching and filters, and supports a printable device-code or `--auth-response` auth path — device code only for Entra ID accounts.
> - rclone 1.75.1 has a rock-solid `onedrive` backend but its headless auth requires a second browser-capable machine (no device-code flow merged), and two-way sync needs experimental-ish `bisync` with `--resync` recovery.
> - GNOME GOA/msgraph mount is turnkey but GUI-only and not a real sync engine.
> - No official Microsoft client for Linux exists.
> - `.git/` should be excluded from any cloud-synced tree regardless of tool.
>
> **Candidate recommendation:** use **abraunegg/onedrive** for the Linux side: installer installs the package/config/systemd unit and launches auth that prints the device code; human completes the browser sign-in (which is unavoidable for any option). Fall back to **rclone bisync** only if the account turns out to be a personal Microsoft account and device-code-style auth is desired — accepting the extra two-machine auth step. Exclusions: sync the whole vault tree read/write, but ignore `.git/`.
