# Linux OneDrive sync survey (salvaged)

_Salvaged 2026-10-03 from the resolution comment on [ticket #6](https://github.com/FreeTurkeys/dan-skills/issues/6) — the agent's commit to `research/linux-onedrive` branch never included this file; facts below are verbatim from the ticket resolution._

Resolution: research is on the branch — `research/linux-onedrive.md` on `research/linux-onedrive` (https://github.com/FreeTurkeys/dan-skills/blob/research/linux-onedrive/research/linux-onedrive.md). Key facts (verified 2026-10-03):
- Microsoft has no official OneDrive client for Linux; third-party clients use Microsoft Graph.
- **abraunegg/onedrive** (correction vs ticket wording: it's `abraunegg`, written in **D**, not Go) is very healthy: v2.5.11 (2026-06-30), commits as of today, 12.9k stars, packaged in Fedora/AUR/Debian. Real two-way sync with watching + filters. Auth: interactive browser by default; headless device-code flow (`use_device_auth = "true"`) **but only for Entra ID (work/school) accounts** — personal accounts need interactive auth or `--auth-response` from another machine.
- **rclone onedrive** (v1.75.1, Sep 2026) backend is solid; headless auth requires a second browser machine (`rclone authorize` — device-code flow still not merged, rclone issue #9452); two-way sync needs experimental-ish `rclone bisync` with `--resync` recovery.
- Others: GNOME GOA/msgraph mount (Ubuntu 24.04+, GUI-only, not a sync engine), Insync (paid), skilion (dead).
- Installer hands-off scope: package install, config, systemd unit, launching auth that prints the device code. Human checklist: completing the browser sign-in (unavoidable for any option).
- Exclude `.git/` from the synced tree (documented mangling/corruption reports); set filter options before first sync (changes force full revalidation).
Candidate recommendation (boxed in the doc, decision deferred to the grilling ticket): abraunegg/onedrive with printed device-code auth; rclone bisync fallback if a personal Microsoft account makes device-code unavailable.
