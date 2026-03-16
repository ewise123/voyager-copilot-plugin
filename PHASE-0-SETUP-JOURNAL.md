# Phase 0: Setup Journal

Step-by-step record of how the Voyager Copilot Plugin was set up, validated,
and the problems encountered along the way. Written during Phase 0 testing
on 2026-03-15/16.

---

## 1. Repo Structure Setup

Created the central repo with the v5 architecture layout:

```
voyager-copilot-plugin/
├── .github/plugin/marketplace.json    # Marketplace registry
├── plugins/voyager/
│   ├── .github/plugin.json            # Plugin manifest (backup location)
│   ├── plugin.json                    # Plugin manifest (primary)
│   ├── .instructions.md               # Ambient context (not supported — see Section 7)
│   └── skills/voyager-dlt/            # Single source of truth for skills
│       ├── SKILL.md
│       ├── UPSTREAM-SOURCE.md
│       ├── skill-metadata.json
│       └── references/
├── tests/phase-0-validation.md
└── version.json
```

**Key discoveries:**

1. Skills must live inside the plugin directory. We originally placed skills at
   the repo root (`skills/`) and referenced them from plugin.json with
   `../../skills/voyager-dlt`. This path did not resolve — the skill never
   appeared in Copilot's `/skills` list. Moving the skill into
   `plugins/voyager/skills/` and using `./skills/voyager-dlt` fixed it.

2. **Do NOT keep a second copy at the repo root.** We initially kept a root
   `skills/` directory as an "authoring source" alongside the plugin copy.
   VS Code discovered both copies, causing the skill to appear twice in
   `/skills`. Removed the root copy — `plugins/voyager/skills/` is the single
   source of truth.

---

## 2. Manifest Files

### marketplace.json (.github/plugin/marketplace.json)

```json
{
  "name": "voyager-copilot-marketplace",
  "owner": {
    "name": "Voyager Platform Team"
  },
  "metadata": {
    "description": "Voyager Copilot plugin marketplace",
    "version": "0.1.0"
  },
  "plugins": [
    {
      "name": "voyager",
      "description": "Voyager platform expertise - curated skills for dlt, Dagster, dbt, infrastructure, K8s, and data contracts",
      "version": "0.1.0",
      "source": "./plugins/voyager"
    }
  ]
}
```

### plugin.json (plugins/voyager/plugin.json)

```json
{
  "name": "voyager",
  "description": "Voyager platform expertise for Copilot - curated skills for dlt, Dagster, dbt, Terraform, K8s, and ODCS data contracts",
  "version": "0.1.0",
  "author": {
    "name": "Voyager Platform Team"
  },
  "skills": [
    "./skills/voyager-dlt"
  ]
}
```

**Gotcha:** Avoid em dashes and special characters in description fields. We
replaced all `—` with `-` to avoid potential encoding issues in plugin discovery.

---

## 3. VS Code Settings

Add to **user-level** settings.json (not workspace):

```json
"chat.plugins.enabled": true,
"chat.plugins.marketplaces": [
    "ewise123/voyager-copilot-plugin"
]
```

Open via: **Ctrl+Shift+P** -> "Preferences: Open User Settings (JSON)"

**Important:** Marketplace settings must be user-level. Workspace settings and
dev container settings do not work for marketplace configuration.

---

## 4. ADO as Marketplace Source

### VS Code `chat.plugins.marketplaces` — Does NOT Work with ADO

Tested multiple ADO URL formats in `chat.plugins.marketplaces`:
- `https://dev.azure.com/SSAAIAccelerator/VoyagerCopilot/_git/voyager-copilot-plugin`
- `https://SSAAIAccelerator@dev.azure.com/SSAAIAccelerator/VoyagerCopilot/_git/voyager-copilot-plugin`
- With PAT embedded in URL
- With `.git` suffix

**None worked.** VS Code silently ignores ADO URLs — no error in the Output
panel, the marketplace simply doesn't appear. VS Code's marketplace handler
only recognizes GitHub URL patterns (shorthand `owner/repo`, GitHub HTTPS,
GitHub SSH, and `file:///`).

### Copilot CLI `plugin marketplace add` — WORKS with ADO

```bash
npm install -g @github/copilot
copilot plugin marketplace add https://dev.azure.com/SSAAIAccelerator/VoyagerCopilot/_git/voyager-copilot-plugin
# Output: Marketplace "voyager-copilot-marketplace" added successfully.

copilot plugin install voyager@voyager-copilot-marketplace
# Output: Plugin "voyager" installed successfully. Installed 1 skill.
```

**However:** CLI-installed plugins live at `~/.copilot/installed-plugins/` and
are NOT shared with VS Code. VS Code plugins live at
`%APPDATA%/Code/agentPlugins/`. They are separate systems.

### `file:///` local clone — WORKS

```json
"chat.plugins.marketplaces": [
    "file:///C:/Users/ewise/voyager-copilot-ado"
]
```

Cloning the ADO repo locally and using `file:///` works in VS Code. But updates
require a manual `git pull` on the local clone.

### Tech lead's ADO setup

The tech lead confirmed ADO works on her machine using:
`https://dev.azure.com/SSAAIAccelerator/AIAccelerator/_git/copilot-plugins`

She verified via `copilot plugin marketplace list` (CLI). It's unclear whether
it also works in her VS Code `chat.plugins.marketplaces` — need to confirm.

### Resolution

GitHub is the primary marketplace source for VS Code. ADO is kept as a
secondary remote.

```bash
gh repo create voyager-copilot-plugin --public
```

GitHub shorthand (`ewise123/voyager-copilot-plugin`) works reliably in
`chat.plugins.marketplaces`.

### Additional problems encountered during ADO testing

1. **Credential issues from WSL:** `git push` failed with "could not read
   Username" because the terminal couldn't prompt for credentials.

2. **Credential manager setup:** Found Git for Windows installed at a
   non-standard location (`C:\Users\ewise\AppData\Local\Programs\Git\`).
   Configured the credential helper:
   ```bash
   git config --global credential.helper "/mnt/c/Users/ewise/AppData/Local/Programs/Git/mingw64/bin/git-credential-manager.exe"
   git config --global credential.useHttpPath true
   ```

3. **ADO repo naming:** ADO creates a default repo matching the project name.
   Spaces in project/repo names (e.g., "Voyager Copilot Test") cause URL
   encoding issues. Renamed to `VoyagerCopilot` (no spaces).

4. **Connection reset from Windows:** Pushing from Windows PowerShell via the
   WSL filesystem path hit "Recv failure: Connection was reset."

---

## 5. VS Code Clone Bug — "destination path already exists"

### The problem

Every time you click "Install" on the plugin from the Extensions sidebar
(`@agentPlugins`), VS Code attempts:

```
git clone https://github.com/ewise123/voyager-copilot-plugin.git
  c:\Users\ewise\AppData\Roaming\Code\agentPlugins\github.com\ewise123\voyager-copilot-plugin
```

This fails with:
```
fatal: destination path '...\voyager-copilot-plugin' already exists
  and is not an empty directory.
```

**Root cause:** VS Code pre-creates parent directories
(`agentPlugins/github.com/ewise123/`) before running `git clone`. If a
previous install attempt failed or the plugin was partially installed, the
directory structure remains. `git clone` then refuses because the target path's
parent already exists and contains content (even just empty subdirectories).

Deleting the directory and retrying doesn't reliably help because VS Code
recreates the parent directory before the clone runs.

### Workaround

Manually clone the repo to the expected location:

```bash
# From WSL:
git clone https://github.com/ewise123/voyager-copilot-plugin.git \
  /mnt/c/Users/ewise/AppData/Roaming/Code/agentPlugins/github.com/ewise123/voyager-copilot-plugin
```

Then reload VS Code (**Ctrl+Shift+P** -> "Developer: Reload Window"). The
plugin appears as installed because VS Code finds the repo at its expected path.

### Updating the plugin after manual clone

Since the plugin was manually cloned, updates need a manual pull too:

```bash
git -C /mnt/c/Users/ewise/AppData/Roaming/Code/agentPlugins/github.com/ewise123/voyager-copilot-plugin pull
```

Then reload VS Code. This is a temporary workflow until the VS Code clone bug
is fixed or we find a better approach.

---

## 6. Skill Path Resolution

### What didn't work

```json
// plugin.json
"skills": ["../../skills/voyager-dlt"]
```

Paths traversing outside the plugin root directory do not resolve. The skill
did not appear in `/skills` in Copilot Chat.

### What works

```json
// plugin.json
"skills": ["./skills/voyager-dlt"]
```

Skills must be physically inside the plugin directory.
`plugins/voyager/skills/` is the single location — no separate authoring
directory. A root `skills/` directory was initially kept as an authoring source,
but VS Code discovered both copies and showed the skill twice in `/skills`.
The root copy was removed.

---

## 7. .instructions.md — Not Supported

### What we tried

Placed `.instructions.md` at `plugins/voyager/.instructions.md` containing the
Voyager platform mental model (~80 words covering deployment lanes and datalake
layers).

### What happened

Copilot did not read the file. When asked "What deployment lanes does Voyager
have?" without invoking a skill, Copilot answered from its training data, not
from the plugin's .instructions.md.

### Why

The plugin.json format supports: `skills`, `agents`, `hooks`, `mcp`, and
`commands`. There is no mechanism for plugins to inject ambient instructions
that are read on every interaction.

The `.instructions.md` feature works at two levels in VS Code:
1. **Workspace:** `.github/copilot-instructions.md` in a repo
2. **User:** Files in `~/.github/instructions/`

But plugins cannot inject into either location.

### Resolution

Baked the platform context directly into each skill's SKILL.md as a
"Platform Context" section at the top. This means the context is available
whenever a skill is invoked, but NOT on general questions.

This is acceptable because:
- The context only matters during Voyager work
- Voyager work triggers a skill via keyword matching
- General questions without skill context are not the target use case

**Open decision:** If truly ambient context is needed later, developers could
be asked to place a `voyager-context.instructions.md` in their
`~/.github/instructions/` directory as a one-time manual step outside the
plugin. This hasn't been necessary yet.

---

## 8. Skill Auto-Matching Behavior

### What we observed

| Prompt | Auto-matched? | Notes |
|--------|--------------|-------|
| "I need to create a new dlt source for ServiceNow" | Mixed | First test: No (Copilot saw skill but didn't invoke). Later test after removing duplicate: Yes (read SKILL.md and followed conventions) |
| "I need to create a new dlt source for the ServiceNow API using the p8e-data-source pattern" | **Yes** | Domain-specific keywords triggered auto-match |
| "/voyager-dlt [any prompt]" | **Yes** | Explicit invocation always works |

### How it works

Copilot reads the YAML frontmatter `description` field from SKILL.md to decide
relevance. The more domain-specific keywords in the prompt, the more likely
Copilot matches. Our frontmatter includes: dlt, dlthub, API ingestion, data
source, @dlt.source, @dlt.resource, incremental loading, REST API client,
p8e-data-source, Raw datalake layer.

### Recommendation

Tell developers they can always use `/voyager-dlt` for explicit invocation.
Auto-matching works when prompts contain enough domain keywords, but isn't
guaranteed for vague requests.

---

## 9. Duplicate Skill Discovery

### The problem

VS Code discovered skills in both `skills/voyager-dlt/` (repo root) and
`plugins/voyager/skills/voyager-dlt/` (inside plugin). The skill appeared
twice in `/skills` in Copilot Chat.

### Fix

Removed the root `skills/` directory entirely. `plugins/voyager/skills/` is
the single source of truth.

---

## 10. Update Propagation

### What we tested

1. Added "(v0.2.0 — update test)" to the SKILL.md heading
2. Bumped version to 0.2.0 in plugin.json and marketplace.json
3. Pushed to GitHub
4. Pulled into the cached clone at `%APPDATA%/Code/agentPlugins/...`
5. Reloaded VS Code

### Result

After manual `git pull` + reload, Copilot confirmed it saw the v0.2.0 heading.
**VS Code does NOT auto-pull updates** — and this is NOT specific to our manual
clone workaround. Research confirmed that agent plugins have no auto-update
mechanism at all (preview feature limitation):

- No `chat.plugins.autoUpdate` setting exists
- No "Update" button in the Extensions sidebar for agent plugins
- No documented polling or refresh behavior
- Even a "properly installed" plugin does not auto-update
- Ken Muse's blog, official VS Code docs, and 1.110/1.111 release notes all
  contain zero information about post-installation updates

### Update workflow for the team

1. Tech lead pushes update to GitHub and bumps version
2. Notify team via Teams/Slack
3. Devs run:
   ```
   git -C "%APPDATA%\Code\agentPlugins\github.com\ewise123\voyager-copilot-plugin" pull
   ```
4. Reload VS Code (Ctrl+Shift+P → "Developer: Reload Window")

### Potential improvement

Tim Heuer's [Agent Plugins Browser](https://github.com/timheuer/vscode-agent-plugins)
extension adds a "Refresh" command for agent plugins. Worth evaluating whether
this simplifies the update flow.

---

## 11. Copilot CLI

### Installation

```bash
npm install -g @github/copilot  # v1.0.5
```

### ADO marketplace works via CLI

```bash
copilot plugin marketplace add https://dev.azure.com/SSAAIAccelerator/VoyagerCopilot/_git/voyager-copilot-plugin
copilot plugin install voyager@voyager-copilot-marketplace
copilot plugin list
# Installed plugins:
#   voyager@voyager-copilot-marketplace (v0.2.0)
```

### CLI and VS Code are separate plugin systems

- CLI installs to: `~/.copilot/installed-plugins/`
- VS Code installs to: `%APPDATA%/Code/agentPlugins/`
- They do NOT share plugins or sync with each other

---

## 12. Final Phase 0 Results

| Test | Result |
|------|--------|
| Plugin installs from GitHub marketplace | **Pass** (with manual clone workaround) |
| Skills discoverable via `/skills` | **Pass** (single copy only — no root `skills/` dir) |
| Skill reads and follows conventions when invoked | **Pass** |
| Platform context via preamble | **Pass** |
| Skill auto-matches on domain keywords | **Pass** |
| `.instructions.md` picked up by plugin | **Fail** — not supported by plugin format |
| ADO in VS Code `chat.plugins.marketplaces` | **Fail** — silently ignored |
| ADO in Copilot CLI `plugin marketplace add` | **Pass** |
| `file:///` local clone in VS Code | **Pass** |
| VS Code clone-on-install reliable | **Fail** — manual clone workaround needed |
| VS Code auto-pulls plugin updates | **No** — no auto-update mechanism exists (preview limitation, not our bug) |
| Copilot CLI and VS Code share plugins | **No** — separate systems |

### What's validated for Phase 1

The core mechanism works: skills installed via a plugin are discoverable,
readable, and followed by Copilot. The content architecture (SKILL.md +
references/ + frontmatter keyword matching) is sound. GitHub is the
marketplace source.

### What needs attention in Phase 1

1. **Update workflow:** No auto-update exists (preview limitation). Evaluate
   Tim Heuer's Agent Plugins Browser extension for a Refresh command. Consider
   a simple PowerShell script for devs to run: `git pull` + reload.
2. **Clone bug:** Monitor VS Code updates for a fix. Document the manual clone
   workaround in onboarding materials.
3. **ADO mirroring:** If the team needs ADO, set up GitHub -> ADO mirror or
   use `file:///` with local clones.
