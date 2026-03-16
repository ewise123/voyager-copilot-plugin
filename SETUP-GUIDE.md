# Voyager Copilot Plugin — Setup Guide

## What This Is

A VS Code Agent Plugin that gives GitHub Copilot curated expertise about the
Voyager data platform. Install the plugin and Copilot becomes a Voyager expert —
it knows dlt source patterns, Dagster orchestration, dbt transformations, and
platform conventions.

Skills show up in Copilot's `/skills` menu. Copilot auto-matches them by
keyword or you invoke them explicitly (e.g., `/voyager-dlt`).

## Option C: Local Clone Setup

We distribute the plugin via a local git clone. Developers clone the repo from
ADO and point VS Code at the local copy.

### One-Time Setup (5 minutes)

**Step 1: Clone the repo**

```powershell
git clone https://dev.azure.com/SSAAIAccelerator/VoyagerCopilot/_git/voyager-copilot-plugin "$env:USERPROFILE\projects\voyager-copilot-plugin"
```

Or run the setup script (if you already have the repo):

```powershell
.\setup-option-c.ps1
```

**Step 2: Update VS Code settings**

Open VS Code settings JSON: **Ctrl+Shift+P** → `Preferences: Open User Settings (JSON)`

Add these lines:

```json
"chat.plugins.enabled": true,
"chat.plugins.paths": {
    "C:\\Users\\YOUR_USERNAME\\projects\\voyager-copilot-plugin\\plugins\\voyager": true
}
```

Replace `YOUR_USERNAME` with your Windows username.

**Step 3: Reload VS Code**

**Ctrl+Shift+P** → `Developer: Reload Window`

**Step 4: Verify**

Type `/skills` in Copilot Chat. You should see `voyager-dlt` with a "Plugins"
label. If it appears, you're done.

### Updating the Plugin

When the team pushes skill updates, you'll get a notification. To update:

**PowerShell:**
```powershell
git -C "$env:USERPROFILE\projects\voyager-copilot-plugin" pull
```

**Bash/WSL:**
```bash
voyager-pull
```

Then reload VS Code: **Ctrl+Shift+P** → `Developer: Reload Window`

## Using the Skills

### Auto-matching

Just describe your task naturally. Copilot matches keywords from your prompt
to the right skill:

> I need to create a new dlt source for the ServiceNow API using the
> p8e-data-source pattern

Copilot reads the `voyager-dlt` skill and follows Voyager conventions
automatically.

### Explicit invocation

Prefix with the skill name:

> /voyager-dlt Create a new dlt source for ServiceNow

### Available Skills

| Skill | When to Use |
|-------|-------------|
| `/voyager-dlt` | dlt sources, API ingestion, p8e-data-source packages, Raw layer |

More skills (voyager-dagster, voyager-dbt, voyager-infra, etc.) will be added
in Phase 1-3.

## How It Works

```
Developer prompt
       |
       v
Copilot matches keywords → reads SKILL.md
       |
       v
SKILL.md provides:
  - Platform context (deployment lanes, datalake layers)
  - Constraints (what to do, what NOT to do)
  - Workspace files to examine
  - Step-by-step approach
  - Reference files with API patterns
       |
       v
Copilot generates code following Voyager conventions
```

The plugin bundles:
- **Skills** — curated knowledge for each domain (dlt, Dagster, dbt, etc.)
- **References** — API patterns, scaffolding templates, filtered for Voyager
- **Platform context** — deployment lanes, datalake layers, vocabulary

## Troubleshooting

**Skills don't appear in `/skills`:**
- Check that `chat.plugins.enabled` is `true` in VS Code settings
- Check that `chat.plugins.paths` points to `...\plugins\voyager` (not the
  repo root)
- The path must be a Windows path (`C:\Users\...`), not a WSL path
- Reload VS Code after changing settings

**Skill doesn't auto-match:**
- Use more domain-specific keywords in your prompt
- Or invoke explicitly: `/voyager-dlt your prompt here`

**Duplicate skills appear:**
- Check for multiple plugin paths or marketplace entries in settings
- Remove old `chat.plugins.marketplaces` entries if present

**Updates not taking effect:**
- Run `git pull` in the repo directory
- Reload VS Code (Ctrl+Shift+P → Developer: Reload Window)

## Repository Structure

```
voyager-copilot-plugin/
├── .github/plugin/
│   └── marketplace.json           # Marketplace registry (for future Option A)
├── plugins/voyager/
│   ├── plugin.json                # Plugin manifest
│   └── skills/
│       └── voyager-dlt/
│           ├── SKILL.md           # Skill instructions + constraints
│           ├── UPSTREAM-SOURCE.md # Upstream version tracking
│           ├── skill-metadata.json
│           └── references/        # API patterns, scaffolding templates
├── setup-option-c.ps1             # Onboarding script for new developers
└── version.json
```

## Distribution Options

| Option | How | Status |
|--------|-----|--------|
| **A: GitHub Marketplace** | `chat.plugins.marketplaces: ["org/repo"]` | Pending GitHub repo approval |
| **C: Local Clone** | `chat.plugins.paths` pointing to local clone from ADO | **Active** |

When Option A is approved, switching is a one-line change in VS Code settings.
