# dan-skills

Personal agent skills, installable on every device with a single PowerShell 7 script.

## Goals

- **Cross-tool skills.** Every skill works with OpenCode, Claude Code, and Cursor
  by conforming to the [Agent Skills](https://agentskills.io) open standard
  (a folder with a `SKILL.md`, plus optional `scripts/`, `references/`, `assets/`).
- **One-command install.** `install.ps1` targets PowerShell 7; if `pwsh` is missing
  it bootstraps and installs PowerShell 7 for the system first, then copies skills
  into each tool's skill directory.
- **First skill: agent knowledge directory.** Set up and maintain a personal
  agent knowledge directory in OKF format, structured with the PARA method,
  written llm-wiki style, and maintained with Zettelkasten practices.

## Research

See [RESEARCH.md](RESEARCH.md) for the full research summary (OKF, llms.txt,
Agent Skills spec, per-tool install paths, PowerShell bootstrapping, PARA,
Zettelkasten) with sources.

## Status

Planning — the work is being mapped as decision tickets via wayfinder.
