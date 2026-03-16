# Voyager Copilot Plugin — Setup Guide

## What This Is

A VS Code Agent Plugin that gives GitHub Copilot curated expertise about the
Voyager data platform. Install the plugin and Copilot becomes a Voyager expert —
it knows dlt source patterns, Dagster orchestration, dbt transformations, and
platform conventions.

Skills show up in Copilot's `/skills` menu. Copilot auto-matches them by
keyword or you invoke them explicitly (e.g., `/voyager-dlt`).

## Setup (One-Time, ~10 minutes)

### Step 1: Clone the repo

```powershell
git clone https://dev.azure.com/SSAAIAccelerator/VoyagerCopilot/_git/voyager-copilot-plugin "$env:USERPROFILE\projects\voyager-copilot-plugin"
```

Or run the setup script (if you already have the repo):

```powershell
.\setup-option-c.ps1
```

### Step 2: Add the plugin to VS Code

Open VS Code settings JSON: **Ctrl+Shift+P** -> `Preferences: Open User Settings (JSON)`

Add:

```json
"chat.plugins.enabled": true,
"chat.plugins.paths": {
    "C:\\Users\\YOUR_USERNAME\\projects\\voyager-copilot-plugin\\plugins\\voyager": true
}
```

Replace `YOUR_USERNAME` with your Windows username.

### Step 3: Add the Azure DevOps MCP server

This gives Copilot access to ADO work items, so you can say "work on task #250"
and it fetches the full context.

Open: **Ctrl+Shift+P** -> `MCP: Open User Configuration`

Add this server entry inside the `"servers"` object:

```json
"ado": {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "@azure-devops/mcp", "SSAAIAccelerator", "-d", "core", "work", "work-items"]
}
```

**Note:** Change `SSAAIAccelerator` to your ADO org name if different. First
time you use an ADO tool, a browser window will open for Microsoft
authentication. Credentials are cached after that.

### Step 4: Reload VS Code

**Ctrl+Shift+P** -> `Developer: Reload Window`

### Step 5: Verify

1. Type `/skills` in Copilot Chat. You should see `voyager-dlt`,
   `voyager-workflow`, and `voyager-dod` with "Plugins" labels.
2. Try: `work on task #250` (use any real ADO task ID) — Copilot should
   fetch the work item, walk the hierarchy, and check Definition of Ready.

## Updating the Plugin

When the team pushes skill updates:

**PowerShell:**
```powershell
git -C "$env:USERPROFILE\projects\voyager-copilot-plugin" pull
```

**Bash/WSL:**
```bash
voyager-pull
```

Then reload VS Code: **Ctrl+Shift+P** -> `Developer: Reload Window`

## Available Skills

| Skill | When to Use | Invocation |
|-------|-------------|------------|
| `voyager-workflow` | Starting work from ADO work items, DoR/DoD checks | Say "work on task #NNN" or `/voyager-workflow` |
| `voyager-dlt` | dlt sources, API ingestion, p8e-data-source packages, Raw layer | `/voyager-dlt` or auto-matches on dlt keywords |
| `voyager-dod` | Verify Definition of Done after coding | Say "check DoD" or "ready for PR" or `/voyager-dod` |

More skills (voyager-dagster, voyager-dbt, voyager-infra) coming in later phases.

## Typical Workflow

### 1. Pick up a task

> work on task #250

Copilot auto-matches `voyager-workflow`:
- Fetches the task from ADO via the MCP server
- Walks the hierarchy: Task -> Story -> Feature -> Epic
- Checks Story Definition of Ready (acceptance criteria, sprint, estimate, blockers)
- Presents acceptance criteria and DoD checklist
- Hands off to the appropriate domain skill (e.g., voyager-dlt)

### 2. Do the work

Copilot uses the domain skill to guide implementation. For example, `voyager-dlt`
provides dlt source patterns, scaffolding templates, and Voyager conventions.

### 3. Check Definition of Done

> check DoD

Or: `/voyager-dod`

Copilot auto-matches `voyager-dod` and runs:
- **Stage 1 (automated):** Ruff linting, formatting, pytest, coverage >= 80%
- **Stage 2 (manual):** Reviews acceptance criteria from the parent story
- **Stage 3 (checklist):** Prints remaining human actions

### 4. Create PR and finish

Follow the Stage 3 checklist: create PR, get review, merge, PO verification,
close story in ADO.

## Story DoR and DoD Reference

### Definition of Ready (Story must meet ALL before starting)

- User story format: "As a [role], I can [action], so that [benefit]"
- Acceptance criteria explicit (Given/When/Then or testable checklist)
- Team understands what success looks like
- Testable (team knows how to verify)
- Estimated (1, 2, 3, or 5 points; if >5, break down further)
- No blockers (access granted, dependencies resolved)
- Assigned to sprint
- Team member volunteered

### Definition of Done (ALL must be true to close)

- Code written and meets standards (no linting errors)
- Unit tests written and passing (coverage >80%, edge cases tested)
- Code reviewed and approved (peer review, comments addressed)
- Integrated with main branch (merged, CI/CD green)
- Acceptance criteria verified (manual or automated test)
- PO can verify in dev/test environment
- PO accepted (Sprint Review or delegated)
- Story closed in ADO

## Troubleshooting

**Skills don't appear in `/skills`:**
- Verify `chat.plugins.enabled` is `true` in settings
- Verify `chat.plugins.paths` points to `...\plugins\voyager` (not the repo root)
- Path must be a Windows path (`C:\Users\...`), not a WSL path
- Reload VS Code after changing settings

**ADO MCP not working:**
- Open **Ctrl+Shift+P** -> `MCP: Open User Configuration`
- Verify the `ado` server entry exists with the correct org name
- Check that `npx` is available (Node.js must be installed)
- First use requires browser authentication — check for a popup

**Skill doesn't auto-match:**
- Use more domain-specific keywords in your prompt
- Or invoke explicitly: `/voyager-dlt your prompt here`

**Updates not taking effect:**
- Run `git pull` in the repo directory
- Reload VS Code (Ctrl+Shift+P -> Developer: Reload Window)

## Repository Structure

```
voyager-copilot-plugin/
├── .github/plugin/
│   └── marketplace.json           # Marketplace registry (for future Option A)
├── plugins/voyager/
│   ├── .github/plugin.json        # Plugin manifest (backup)
│   ├── .mcp.json                  # ADO MCP config (bundled, may not auto-load)
│   ├── plugin.json                # Plugin manifest
│   └── skills/
│       ├── voyager-dlt/           # dlt source expertise
│       │   ├── SKILL.md
│       │   ├── UPSTREAM-SOURCE.md
│       │   ├── skill-metadata.json
│       │   └── references/
│       ├── voyager-workflow/      # ADO work item workflow + DoR/DoD
│       │   └── SKILL.md
│       └── voyager-dod/           # Definition of Done checker
│           └── SKILL.md
├── setup-option-c.ps1             # Onboarding script
├── SETUP-GUIDE.md                 # This file
├── version.json
└── docs/archive/                  # Historical Phase 0 docs
```

## Distribution

| Option | How | Status |
|--------|-----|--------|
| **A: GitHub Marketplace** | `chat.plugins.marketplaces: ["org/repo"]` | Pending approval |
| **C: Local Clone (ADO)** | `chat.plugins.paths` pointing to local clone | **Active** |

Switching to Option A is a one-line settings change per developer when approved.
