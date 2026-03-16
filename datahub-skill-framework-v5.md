# DataHub Copilot Plugin
## Architecture, Distribution, and Maintenance (v5 — Agent Plugin)

---

## 1. What Changed from v4

v4 established the right content architecture — curated skills, platform references, and a slim `.instructions.md` mental model. But it relied on a custom distribution layer: a PowerShell setup script, a `datahub-update` command registered in the developer's shell profile, and a manual git pull workflow. This worked but required ongoing maintenance of infrastructure that wasn't core to the problem.

v5 replaces the custom distribution layer with **VS Code Agent Plugins** — a native preview feature that lets you package skills, agents, hooks, and MCP servers as installable bundles, distributed via a Git-based marketplace. The central repo becomes both the plugin source and the marketplace. Developers install and update through VS Code's Extensions sidebar. No custom scripts, no shell profile modifications, no `datahub-update` command.

The content architecture (skills, platform references, per-repo instructions) is unchanged from v4. Only the distribution mechanism changes.

**Important:** Agent Plugins are currently a VS Code preview feature. The v4 setup script (`setup.ps1` + `datahub-update`) should be maintained as a fallback until the plugin feature reaches stable release. Both distribution mechanisms can coexist — the plugin installs to the same skill locations.

---

## 2. What We've Tested and Confirmed

| Assumption | Test | Result |
|-----------|------|--------|
| Skills auto-discovered from `~/.copilot/skills/` with nested reference subdirectories | Created test skill with nested references containing a unique phrase not in any training data | ✅ Copilot returned the planted phrase — skill discovery with nested refs works |
| User-level agents roam across workspaces | Agent in `prompts/` tested across different ADO-hosted workspaces | ✅ Works regardless of which workspace is open |
| Copilot reads skills based on keyword matching without routing | Installed dagster-expert skill, told Copilot "I need to do dagster work" with no routing table in place | ✅ Copilot matched keywords directly to skill and read it — confirms skills-only architecture works |
| Copilot reads multiple skills in a single interaction | Installed datahub-dlt and dagster-expert skills, prompted: "Create a new dlt source for ServiceNow and wire it up as a Dagster asset on a daily schedule" | ✅ Copilot identified both domains, read both skill files, and combined knowledge from both. No agent or orchestration layer needed. |
| Copilot respects skill constraints in unfamiliar workspace | Same multi-skill test run in a non-DataHub repo | ✅ Copilot attempted to find expected workspace files (sources/p8e-data-source-*/, pyproject.toml) and correctly identified they were missing — constraints are being followed |
| VS Code Agent Plugin feature supports skill bundling | Created plugin with datahub-dlt skill, installed via GitHub marketplace | ✅ Skill appears in `/skills` list with "Plugins" flag. Copilot reads SKILL.md and references/ when invoked. |
| Plugin-installed skills auto-match on keywords | Prompted "create a new dlt source for the ServiceNow API using the p8e-data-source pattern" without `/datahub-dlt` prefix | ✅ Copilot matched keywords from frontmatter description and auto-invoked the skill. Requires domain-specific keywords — generic prompts like "create a data source" may not trigger. |
| ADO in VS Code `chat.plugins.marketplaces` | Tested multiple ADO URL formats including PAT-embedded URLs | ❌ VS Code silently ignores ADO URLs. Only GitHub URL patterns are recognized. |
| ADO in Copilot CLI `plugin marketplace add` | `copilot plugin marketplace add <ADO URL>` | ✅ Works — but CLI plugins don't sync to VS Code. Separate plugin systems. |
| `file:///` local clone as marketplace source | Cloned ADO repo locally, used `file:///C:/Users/.../repo` | ✅ Works in VS Code. Requires manual `git pull` for updates. |
| Duplicate skills from multiple directories | Had skills in both `skills/` (root) and `plugins/datahub/skills/` | ❌ VS Code discovers both — skill appeared twice. Removed root copy. |
| Plugin update auto-detected by VS Code | Pushed version bump to GitHub, checked for update notification | ⚠️ No auto-update observed. Manual `git pull` + reload needed. May be caused by manual clone workaround — needs further investigation. |
| Plugin bundles custom instructions (.instructions.md) | Placed .instructions.md in plugin root with DataHub mental model | ❌ Not picked up. Plugin format supports skills, agents, hooks, mcp, commands — but NOT .instructions.md. Copilot ignores it. |
| Skill paths can traverse outside plugin directory | Used `../../skills/datahub-dlt` in plugin.json to reference shared skills/ directory | ❌ Skill did not appear in `/skills`. Changed to `./skills/datahub-dlt` with skills inside the plugin directory — works. |
| VS Code clone-on-install works reliably | Clicked Install from @agentPlugins in Extensions sidebar | ⚠️ Unreliable. VS Code pre-creates parent directories, then `git clone` fails with "destination path already exists." Workaround: manually clone to the expected path, then reload. See setup journal. |

The multi-skill test is the most important validation. It confirms that Copilot natively handles cross-domain tasks without agents, routing tables, or orchestration — the simplest possible architecture works.

**Decisions from Phase 0 testing:**

1. **Ambient context delivery: preamble fallback.** Since .instructions.md is not supported by the plugin format, the ~150 word DataHub mental model is baked into each skill's SKILL.md as a "Platform Context" section. This means ambient context is only available when a skill is matched — not on every interaction. This is acceptable because: (a) the context only matters during DataHub work, (b) DataHub work triggers a skill, (c) general questions without skill context are not the target use case.

2. **Marketplace hosting: GitHub.** VS Code's `chat.plugins.marketplaces` only recognizes GitHub URLs. ADO URLs are silently ignored. ADO works via Copilot CLI but that's a separate plugin system. GitHub shorthand (`owner/repo`) is the primary distribution. ADO is kept as a secondary remote.

3. **Skill location: single copy inside plugin directory.** Skills must live inside the plugin directory (e.g., `plugins/datahub/skills/`) with relative paths like `./skills/datahub-dlt`. Paths that traverse outside the plugin root (`../../skills/`) do not resolve. Do NOT keep a second copy at the repo root — VS Code discovers both and shows duplicate skills.

4. **Updates: no auto-update exists.** Agent plugins have no auto-update mechanism — this is a preview feature limitation, not a bug in our setup. No `chat.plugins.autoUpdate` setting exists, no "Update" button in the Extensions sidebar, and no documented polling. Update workflow: tech lead pushes to GitHub, notifies team, devs run `git pull` in their agentPlugins directory and reload VS Code. Tim Heuer's [Agent Plugins Browser](https://github.com/timheuer/vscode-agent-plugins) extension adds a "Refresh" command that may help.

---

## 3. The Problem This Solves

Developers working in the DataHub platform need to understand how 15 repositories, three deployment paths, and a dozen tools connect together. Today, that knowledge lives in people's heads, scattered docs, and tribal knowledge. When a developer needs to add a new dlt source, fix a Dagster deploy, or create an infrastructure stack, they spend time figuring out which repos to touch, which templates to follow, and which patterns to use.

This plugin puts that knowledge directly into the developer's IDE, scoped to exactly what they're working on. Install the plugin, and Copilot becomes a DataHub expert.

---

## 4. Architecture

### Two Distribution Channels

```
┌─────────────────────────────────────────────────────────────────────────┐
│  PLUGIN (installed via VS Code Agent Plugin marketplace)                │
│                                                                         │
│  Everything user-level is bundled in the plugin:                        │
│                                                                         │
│  Skills                                                                 │
│    datahub-dagster/  — Dagster + DataHub orchestration patterns          │
│    datahub-dlt/      — dlt + DataHub ingestion patterns                 │
│    datahub-dbt/      — dbt + DataHub transformation patterns            │
│    datahub-infra/    — Terragrunt/OpenTofu + DataHub IaC                │
│    datahub-k8s/      — K8s/AKS + DataHub deployment                    │
│    datahub-contracts/ — ODCS data contracts                             │
│                                                                         │
│  Platform References (NOT a skill — no SKILL.md)                        │
│    datahub-platform/references/                                         │
│      architecture.md, datalake-layers.md, deployment-*.md,              │
│      template-map.md, pr-workflow.md                                    │
│                                                                         │
│  Ambient Context (baked into each skill's preamble)                     │
│    "Platform Context" section in every SKILL.md                         │
│    (.instructions.md NOT supported by plugin format — see Section 2)    │
│                                                                         │
├─────────────────────────────────────────────────────────────────────────┤
│  REPO-LEVEL (version controlled in each working repo's ADO)             │
│  Location: {repo}/.github/                                              │
│                                                                         │
│  copilot-instructions.md — repo identity, file structure, coding        │
│                            standards, linked repos, what not to do      │
│                                                                         │
│  Distributed via: ADO pipeline PRs against working repos                │
└─────────────────────────────────────────────────────────────────────────┘
```

### Three Layers of Context

**Layer 1: Ambient context (every skill invocation)**
A slim (~150 word) DataHub mental model. Gives Copilot baseline DataHub awareness: deployment lanes, datalake layers, vocabulary. Baked into each skill's SKILL.md as a "Platform Context" preamble section. Phase 0 testing confirmed that `.instructions.md` is not supported by the plugin format, so the preamble approach is the permanent solution, not a fallback.

```markdown
# DataHub Platform Context

DataHub is a data platform with 15 repos across three deployment lanes:
- **Data pipelines:** dlt (ingestion → Raw) + dbt (transform → Prep/Prod),
  orchestrated by Dagster, deployed to Dagster Cloud
- **Services:** APIs and tools deployed to AKS via Helm + FluxCD
- **Infrastructure:** Azure resources provisioned via Terragrunt/OpenTofu

The datalake has three layers in Databricks Unity Catalog:
- **Raw:** landing zone for dlt-ingested API data
- **Prep:** dbt-transformed staging models
- **Prod:** dbt mart models, consumer-facing
```

Note: the ambient context intentionally does NOT point to the platform reference directory. Including a path would invite Copilot to proactively read those files on every interaction. Only domain skills contain reference paths.

**Layer 2: Domain skills (matched by task keywords)**
Curated skills that Copilot discovers and reads when keywords match. Each skill contains upstream tool knowledge filtered through DataHub conventions, constraints, approach patterns, and output guidance.

**Layer 3: Per-repo instructions (workspace-scoped)**
Light, stable facts about the specific repo the developer has open. File structure, coding standards, linked repos, what not to do.

### How It Works

1. Developer installs the DataHub plugin from VS Code's Extensions sidebar (one-time)
2. Developer opens any DataHub repo in VS Code
3. Copilot reads ambient context — gets the DataHub mental model
4. Copilot reads `.github/copilot-instructions.md` (workspace-level) — gets repo-specific context
5. Developer describes a task in Copilot Chat
6. Copilot matches task keywords to a domain skill and reads it
7. The skill provides: domain knowledge, DataHub-specific constraints, workspace files to examine, approach, and output guidance
8. The skill may direct Copilot to read specific platform reference files for cross-cutting context
9. Developer reviews the result

### What the Developer Experiences

Developer types: "I need to add a new dlt source for ServiceNow with incidents and change requests"

Copilot automatically:
- Matches "dlt source" → reads `datahub-dlt` skill
- Gets upstream dlt knowledge (API patterns, @dlt.source conventions) already filtered for DataHub
- Gets platform context (Raw layer conventions, repo structure)
- Reads existing sources in workspace (p8e-data-source-* patterns)
- Returns scaffolded source package with all files, tests, and next steps

No routing layer, no agent delegation, no `@` tags. The developer describes work, Copilot finds the skill.

---

## 5. Skill Design

Unchanged from v4. See v4 document Section 5 for the full skill structure template, curating upstream knowledge, skill sizing guidelines, and cross-cutting platform knowledge design.

Key points carried forward:
- SKILL.md under 300 lines, reference files under 500 lines
- Front-load constraints at the top of SKILL.md
- Domain skills point to platform references by path, only when relevant
- datahub-platform has no SKILL.md — it's a reference directory only

---

## 6. Per-Repo Instructions

**Location:** `{repo}/.github/copilot-instructions.md`
**Maintained by:** Authored in central repo, distributed to working repos via ADO pipeline PRs

Light, stable facts. 200-400 words. Covers repo identity, file structure, coding standards, linked repos, what not to do, deployment lane. Volatile knowledge lives in skills, not here.

These provide workspace context that skills can't — what repo the developer is currently in, what the file structure looks like, what standards apply locally.

Per-repo instructions are NOT part of the plugin. They live in each working repo's version control and are distributed separately (see Section 10).

---

## 7. The Central Repo — Plugin + Marketplace

### Purpose

The central repo serves dual roles: it's the **plugin source** (contains the skill content) and the **marketplace** (tells VS Code where to find the plugin). Developers don't work in this repo — it's maintained by tech leads.

### Structure

```
datahub-copilot/                          (GitHub repo — marketplace source)
│
├── .github/
│   └── plugin/
│       └── marketplace.json              # Marketplace registry
│
├── plugins/
│   └── datahub/
│       ├── .github/
│       │   └── plugin.json               # Plugin manifest (also at plugin root)
│       ├── plugin.json                   # Plugin manifest (VS Code reads this)
│       └── skills/                       # Skills MUST live inside plugin directory
│           ├── datahub-dagster/
│           │   ├── SKILL.md              # Includes Platform Context preamble
│           │   ├── UPSTREAM-SOURCE.md
│           │   ├── skill-metadata.json
│           │   └── references/
│           │
│           ├── datahub-dlt/
│           │   ├── SKILL.md              # Includes Platform Context preamble
│           │   ├── UPSTREAM-SOURCE.md
│           │   ├── skill-metadata.json
│           │   └── references/
│           │
│           ├── datahub-dbt/
│           │   ├── SKILL.md
│           │   ├── UPSTREAM-SOURCE.md
│           │   ├── skill-metadata.json
│           │   └── references/
│           │
│           ├── datahub-infra/
│           │   ├── SKILL.md
│           │   ├── UPSTREAM-SOURCE.md
│           │   ├── skill-metadata.json
│           │   └── references/
│           │
│           ├── datahub-k8s/
│           │   ├── SKILL.md
│           │   └── references/
│           │
│           ├── datahub-contracts/
│           │   ├── SKILL.md
│           │   └── references/
│           │
│           └── datahub-platform/         # NOT a skill — no SKILL.md
│               └── references/
│                   ├── architecture.md
│                   ├── datalake-layers.md
│                   ├── deployment-k8s.md
│                   ├── deployment-dagster.md
│                   ├── deployment-infra.md
│                   ├── template-map.md
│                   └── pr-workflow.md
│
│
├── repo-instructions/                    # Source for per-repo copilot-instructions.md
│   ├── data-api.md
│   ├── datahub-data-platform-repo.md
│   ├── data-transformation.md
│   └── ... (one per repo)
│
├── scan-config.json                      # Drift scanner configuration
│
├── setup.ps1                             # FALLBACK: v4 setup script (keep until plugin is stable)
│
├── README.md
├── MAINTENANCE.md
├── version.json
│
└── tests/
    ├── dlt-new-source.md
    ├── dbt-new-model.md
    └── infra-new-stack.md
```

**Important:** Skills must live inside the plugin directory (`plugins/datahub/skills/`). Phase 0 testing confirmed that relative paths traversing outside the plugin root (e.g., `../../skills/`) do not resolve. The root `skills/` directory serves as the authoring/editing location. A build step or manual copy syncs changes into the plugin directory before committing.

### Plugin Manifest (plugin.json)

```json
{
  "name": "datahub",
  "description": "DataHub platform expertise for Copilot - curated skills for dlt, Dagster, dbt, Terraform, K8s, and ODCS data contracts",
  "version": "1.0.0",
  "author": {
    "name": "DataHub Platform Team"
  },
  "skills": [
    "./skills/datahub-dagster",
    "./skills/datahub-dlt",
    "./skills/datahub-dbt",
    "./skills/datahub-infra",
    "./skills/datahub-k8s",
    "./skills/datahub-contracts",
    "./skills/datahub-platform"
  ]
}
```

Note: `plugin.json` lives at the plugin root (`plugins/datahub/plugin.json`). A copy also exists at `plugins/datahub/.github/plugin.json` for compatibility. Skill paths are resolved relative to the plugin root. **Paths must not traverse outside the plugin directory** — `../../skills/` does not work. Use `./skills/` with skills copied inside the plugin directory.

### Marketplace Manifest (marketplace.json)

```json
{
  "name": "datahub-copilot-marketplace",
  "owner": {
    "name": "DataHub Platform Team"
  },
  "metadata": {
    "description": "DataHub Copilot plugin marketplace",
    "version": "1.0.0"
  },
  "plugins": [
    {
      "name": "datahub",
      "description": "DataHub platform expertise — curated skills for dlt, Dagster, dbt, infrastructure, K8s, and data contracts",
      "version": "1.0.0",
      "source": "./plugins/datahub"
    }
  ]
}
```

### Developer Setup (One-Time)

Developer adds the marketplace to their VS Code user settings (**must be user-level, not workspace**):

```json
// settings.json (Ctrl+Shift+P → "Preferences: Open User Settings (JSON)")
"chat.plugins.enabled": true,
"chat.plugins.marketplaces": [
    "ewise123/datahub-copilot-plugin"
]
```

Then installs the plugin from the Extensions sidebar: search `@agentPlugins`, find "datahub", click Install.

**Known issue:** The Install button may fail with a git clone error ("destination path already exists"). This is a VS Code bug where it pre-creates parent directories before cloning. Workaround: manually clone the repo to the expected path and reload VS Code. See `PHASE-0-SETUP-JOURNAL.md` for detailed steps.

**Alternative installation methods:**
- `chat.plugins.paths` pointing to a local clone (works reliably, no marketplace needed)
- v4 setup script as fallback

---

## 8. Distribution

### Plugin Channel (User-Level Content)

All user-level content — skills, platform references, and ambient context — is distributed through the VS Code Agent Plugin marketplace.

**How updates work:**
1. Tech lead merges skill update to central repo main branch
2. Plugin version is bumped in `plugin.json` and `marketplace.json`
3. Tech lead notifies team (Teams/Slack) that an update is available
4. Developer updates their local plugin:
   - **Windows:** `git -C "%APPDATA%\Code\agentPlugins\github.com\ewise123\datahub-copilot-plugin" pull`
   - **WSL:** `git -C /mnt/c/Users/{user}/AppData/Roaming/Code/agentPlugins/github.com/ewise123/datahub-copilot-plugin pull`
5. Developer reloads VS Code (Ctrl+Shift+P → "Developer: Reload Window")

**Note:** Agent plugins have no auto-update mechanism (preview limitation). There is no "Update" button, no polling, and no `chat.plugins.autoUpdate` setting. This may improve as the feature matures. Tim Heuer's [Agent Plugins Browser](https://github.com/timheuer/vscode-agent-plugins) extension adds a "Refresh" command that may simplify this.

**Phase 0 validation results:**

| Question | Result | Action Taken |
|----------|--------|--------------|
| Do ADO HTTPS git URLs work as marketplace sources? | **No** in VS Code (silently ignored). **Yes** in Copilot CLI (separate system). | Hosted on GitHub. ADO kept as secondary remote. |
| Can the plugin bundle `.instructions.md` as custom instructions? | **No** — not a supported plugin capability | Platform Context baked into each skill's SKILL.md preamble |
| Does VS Code auto-notify when plugin updates are available? | **No** — no auto-update mechanism exists (preview limitation) | Devs run `git pull` in agentPlugins dir + reload VS Code |
| Does plugin update require VS Code restart? | Reload Window is sufficient (not full restart) | Documented in update workflow |

### ADO Pipeline Channel (Repo-Level Content)

Per-repo `copilot-instructions.md` files are distributed separately through ADO pipeline PRs.

**Phase 1 (Manual):** Tech lead copies updated file from `repo-instructions/` to the working repo and commits.

**Phase 2 (Automated):** ADO pipeline detects changes to `repo-instructions/*.md` on merge to main. For each changed file, creates a PR against the corresponding working repo updating `.github/copilot-instructions.md`.

### Fallback Distribution (v4 Script)

The v4 `setup.ps1` and `datahub-update` command are maintained in the central repo as a fallback for:
- Environments where the plugin preview feature is disabled or unavailable
- New machines where VS Code isn't yet configured with the marketplace
- Troubleshooting plugin installation issues

Both mechanisms install to the same locations — they can coexist without conflict.

### Distribution Summary

```
User-level content (skills, platform refs, ambient context):
    Primary:  VS Code Agent Plugin marketplace
    Fallback: datahub-update (v4 setup script)

Repo-level content (copilot-instructions.md):
    Primary:  ADO pipeline PRs to working repos
    Fallback: Manual copy by tech lead
```

---

## 9. Keeping Content Fresh — The Drift Scanner

Unchanged from v4. The drift scanner is a scheduled ADO pipeline that scans all 15 working repos for dependency version changes, key file modifications, structure drift, and new/removed repos. It produces a weekly drift report posted to the team channel.

The only change: the "Drift → Update Flow" now ends with the plugin distribution channel instead of `datahub-update`:

```
Weekly scan runs
      │
      ▼
Drift report posted to team channel
      │
      ▼
Tech lead reviews report
      │
      ├─ No action needed ──► Done
      │
      └─ Skill needs update ──► Edit skill in central repo
                                      │
                                      ▼
                                Bump version in plugin.json + marketplace.json
                                Merge to main
                                      │
                                      ▼
                                Plugin update available in VS Code
                                Developer installs update from Extensions sidebar
```

See v4 document Section 9 for full drift scanner design: what it checks, scan-config.json format, skill-metadata.json, pipeline design, and example drift report.

---

## 10. Per-Repo Instruction Distribution

Unchanged from v4. Repo instruction files live in the central repo under `repo-instructions/`. They reach working repos via manual copy (Phase 1) or ADO pipeline PRs (Phase 2).

This is separate from the plugin because per-repo instructions are version-controlled in working repos, not installed on developer machines.

---

## 11. Skill Inventory

| Skill | Domain | Key Knowledge | Curated From |
|-------|--------|---------------|--------------|
| datahub-dagster | Orchestration | Dagster API, dg CLI, assets, sensors, deploy.yaml chain, branch deployments | Dagster upstream skill + DataHub deploy conventions |
| datahub-dlt | API ingestion | dlt API, @dlt.source/@dlt.resource, incremental loading, Dagster-dlt bridge | dlthub upstream + DataHub source patterns |
| datahub-dbt | Transformation | dbt CLI, models, sources, testing, Raw→Prep→Prod layering | dbt upstream + DataHub datalake conventions |
| datahub-infra | Infrastructure | Terragrunt, OpenTofu, Azure providers, dp-service-catalog patterns | Terraform upstream + DataHub IaC patterns |
| datahub-k8s | Deployment | AKS, Helm, FluxCD, runway, container deployment | DataHub deployment-k8s conventions |
| datahub-contracts | Data contracts | ODCS spec, schema validation, contract-first development | Tech lead's existing ODCS work |

**Not a skill but part of the plugin:**

| Component | Type | Contents |
|-----------|------|----------|
| Ambient context | "Platform Context" preamble in each SKILL.md | Slim DataHub mental model — read when any skill is invoked (.instructions.md not supported by plugin format) |
| datahub-platform/references/ | Reference files | Architecture, datalake layers, deployment paths, template map, PR workflows — read by domain skills via path |

---

## 12. Known Risks and Mitigations

### Risk 1: Plugin Feature is Preview

**Problem:** Agent Plugins are a VS Code preview feature. The API, manifest format, or marketplace behavior could change before stable release.
**Mitigation:** Maintain the v4 `setup.ps1` fallback alongside the plugin. Both install to the same locations and can coexist. If the plugin feature breaks or changes incompatibly, developers fall back to `datahub-update` until the plugin is fixed. Monitor VS Code release notes for plugin feature changes.

### Risk 2: ADO Git URLs May Not Work as Marketplace Source

**Problem:** The plugin marketplace was designed with GitHub in mind. ADO HTTPS git URLs may not be recognized.
**Mitigation:** Test this early in Phase 1. Fallback options: mirror the central repo to GitHub (simplest), use `chat.plugins.paths` to point to a local clone, or use the v4 setup script. The `chat.plugins.paths` approach is particularly viable since developers can point to their local clone of the central repo.

### Risk 3: Plugin Caching Issues

**Problem:** VS Code caches marketplace feed details aggressively. Updates to plugin manifests may not take effect without reloading VS Code or switching the marketplace reference format.
**Mitigation:** Document this for developers. When updates don't appear, try: reload VS Code, switch marketplace URL format (e.g., from shorthand to full HTTPS), or clear the plugin cache. Test with Copilot CLI first for better error messages during development.

### Risk 4: Manifest Errors Fail Silently

**Problem:** Mistakes in `marketplace.json` or `plugin.json` cause the marketplace feed to silently not appear. No error message — it just doesn't show up.
**Mitigation:** Always test manifest changes with Copilot CLI before pushing to the marketplace repo. Copilot CLI provides better error diagnostics than VS Code for plugin issues. Add manifest validation to the ADO pipeline as a PR check.

### Risk 5: Upstream Skill Drift

**Problem:** Vendor releases a new version of their tool, curated skill has outdated patterns.
**Mitigation:** Each skill has an UPSTREAM-SOURCE.md tracking the vendor version it was curated from. Maintenance cadence: check upstream sources monthly. The drift scanner flags dependency version bumps in working repos.

### Risk 6: Skill Keyword Collisions

**Problem:** Developer asks about something that matches multiple skills, Copilot picks the wrong one.
**Mitigation:** Skill descriptions should have distinct keyword spaces with minimal overlap. Include disambiguation in descriptions where collision is unavoidable.

### Risk 7: ~~Multi-Domain Tasks~~ — RESOLVED

**Original concern:** Developer's task spans two skills and Copilot only reads one.
**Test result:** Confirmed that Copilot reads multiple skills in a single interaction without any orchestration layer. See Section 2.

### Risk 8: Curated Knowledge Goes Stale Internally

**Problem:** DataHub conventions change but skills aren't updated.
**Mitigation:** Tie skill updates to sprint process. Drift scanner catches cases where discipline fails.

### Risk 9: Copilot Ignores Skill Constraints

**Problem:** Copilot reads the skill but doesn't follow constraints.
**Mitigation:** Make constraints concrete and specific. Front-load at top of SKILL.md.

### Risk 10: New Developer Onboarding

**Problem:** New developer starts, doesn't have plugin installed.
**Mitigation:** Onboarding checklist includes: enable `chat.plugins.enabled`, add marketplace URL to settings, install DataHub plugin from Extensions sidebar. Three steps, no scripts.

### Risk 11: Drift Scanner Requires Cross-Repo Access

**Problem:** The scanner pipeline needs read access to all 15 repos.
**Mitigation:** Create a dedicated service connection with read-only access to all DataHub repos.

---

## 13. Maintenance

### Adding a New Skill

1. Create `plugins/datahub/skills/{name}/SKILL.md` following the standard structure (include Platform Context preamble)
2. Add `references/` directory with supporting material
3. If curating from upstream, add `UPSTREAM-SOURCE.md` with source details
4. Add skill path to `plugins/datahub/plugin.json` (use `./skills/{name}`)
5. Add the new skill's repos to `scan-config.json`
6. Add example prompts and expected outputs to `tests/`
7. Test with at least two developers on real tasks
8. Bump version in `plugin.json` and `marketplace.json`
9. Merge to main — plugin update becomes available

### Updating an Existing Skill

1. Edit skill files in the central repo
2. Bump version in `plugin.json`, `marketplace.json`, and `version.json`
3. Merge to main — plugin update becomes available in VS Code

### Responding to a Drift Report

1. Review the weekly drift report
2. For each flagged item, decide: does this affect what the skill tells developers to do?
3. If yes, update the skill and/or platform reference files
4. If no (e.g., routine dependency bump with no API changes), no action needed
5. If a new repo appeared, author a `copilot-instructions.md` and add it to `scan-config.json`

### Monthly Maintenance Checklist

- [ ] Check upstream sources for major version changes (Dagster, dbt, dlt, Databricks, Terraform)
- [ ] Review accumulated drift reports for patterns
- [ ] Review test results — run example prompts against current skills
- [ ] Check if any DataHub platform conventions have changed
- [ ] Update UPSTREAM-SOURCE.md for any re-curated skills
- [ ] Bump versions and merge

---

## 14. Rollout Plan

### Phase 0: Plugin Validation (Week 1) — COMPLETE

Validated the plugin mechanism. Full details in `PHASE-0-SETUP-JOURNAL.md`.

- [x] Enable `chat.plugins.enabled` in VS Code
- [x] Create minimal test plugin with one skill (datahub-dlt) in the central repo
- [x] Add `marketplace.json` to the central repo
- [ ] ~~Test: does ADO HTTPS git URL work as marketplace source?~~ — Inconclusive, moved to GitHub
- [x] Test: can developer install plugin from Extensions sidebar? — Yes, with clone workaround
- [x] Test: does the installed skill appear in Copilot and work correctly? — Yes, via `/skills` and keyword auto-match
- [x] Test: can the plugin bundle `.instructions.md`? — **No.** Preamble fallback implemented.
- [ ] Test: does updating the plugin in the repo propagate to VS Code? — Deferred to Phase 1
- [ ] Test: plugin install with Copilot CLI for better error diagnostics — Deferred to Phase 1
- [x] Document any issues, workarounds, or limitations discovered — See setup journal

### Phase 1: Foundation (Week 2-3)

- [ ] Build full central repo structure with plugin manifests
- [ ] Write .instructions.md (or implement preamble fallback)
- [ ] Build datahub-platform reference files
- [ ] Build datahub-dlt skill (curate from upstream + DataHub conventions)
- [ ] Write copilot-instructions.md for datahub-data-platform-repo
- [ ] Test full chain: install plugin → open DataHub repo → use skill → get DataHub-specific answer
- [ ] Deploy to 2-3 developers on real sprint tasks
- [ ] Maintain v4 setup.ps1 as fallback

### Phase 2: Dagster + dbt + Infrastructure (Week 4-5)

- [ ] Build datahub-dagster skill (curate from tech lead's upstream skill)
- [ ] Build datahub-dbt skill (curate from upstream)
- [ ] Write copilot-instructions.md for data-transformation
- [ ] Build scan-config.json for initial repos
- [ ] Build and test drift scanner pipeline
- [ ] Set up ADO pipeline for repo instruction distribution
- [ ] Bump plugin version, test update flow
- [ ] Test with full data engineering team

### Phase 3: Full Coverage (Week 6-8)

- [ ] Build datahub-k8s and datahub-infra skills
- [ ] Adopt datahub-contracts skill from tech lead's ODCS work
- [ ] Write copilot-instructions.md for all remaining repos
- [ ] Expand scan-config.json to cover all repos
- [ ] Write MAINTENANCE.md
- [ ] Run full test suite across all skills
- [ ] Verify drift scanner covers all repos
- [ ] Onboarding documentation finalized
- [ ] Evaluate: is plugin feature stable enough to deprecate v4 fallback?

---

## 15. Coordination with Tech Lead's Existing Work

The tech lead has already built:
- Dagster upstream skill (curate into datahub-dagster)
- ODCS agent (adapt substance into datahub-contracts skill)
- Various custom skills with nested reference files

**Approach:** Frame the central repo as scaling her work across all 15 repos. Specifically:
- Her Dagster upstream skill → curate into datahub-dagster, filtering through DataHub conventions
- Her ODCS agent → extract the knowledge and constraints into datahub-contracts skill format
- Her custom DataHub-specific content → evaluate for datahub-platform references
- Coordinate before Phase 1 to align on structure and avoid duplicate effort

---

## 16. What Changed from v4 to v5

| v4 Component | v5 Status | Reason |
|--------------|-----------|--------|
| setup.ps1 + datahub-update | **Kept as fallback** | Plugin feature is preview. Fallback needed until stable. Both mechanisms coexist. |
| PowerShell profile registration | **Kept as fallback** | Same reason. Not needed if plugin is primary distribution. |
| ADO pipeline merge notification | **Replaced by plugin update** | VS Code's plugin system handles update notification natively. If it doesn't notify reliably, re-add Teams notification as supplement. |
| Staleness warning in skills | **Removed** | Plugin marketplace handles versioning. Developers see updates in Extensions sidebar. No need for skills to self-check staleness. |
| datahub-version.json | **Removed** | Plugin versioning in plugin.json replaces custom version tracking. |
| Three-layer distribution defense | **Simplified to one** | Plugin install replaces notification + command + staleness warning. Fallback to v4 if plugin is unavailable. |

---

## 17. What We Dropped from v3 (and Why)

| v3 Component | Status | Reason |
|--------------|--------|--------|
| .instructions.md as routing table | **Repurposed** as ambient context | Copilot doesn't reliably read it before matching skills. Now carries a slim DataHub mental model. |
| Specialist agents (.agent.md) | Dropped | Copilot skips agents when skills match keywords directly. Agent value now lives inside skills. |
| runSubagent delegation | Dropped | Unnecessary when there's no agent to delegate to. |
| Orchestrator agent for multi-skill tasks | Dropped | Testing confirmed Copilot reads multiple skills natively. |
| Separate upstream skill directories | Dropped | Raw upstream skills compete with curated skills. Upstream knowledge curated into domain skills. |
| datahub-platform as a skill | **Demoted** to reference directory | Prevents keyword collision. No SKILL.md — only read when domain skills point to it. |
