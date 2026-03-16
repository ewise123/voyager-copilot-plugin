# Phase 0: Plugin Validation Checklist

ADO Repo: https://dev.azure.com/SSAAIAccelerator/Voyager%20Copilot%20Test

## Prerequisites

- [ ] VS Code Insiders or latest stable with Agent Plugins preview
- [ ] `chat.plugins.enabled: true` in VS Code settings
- [ ] GitHub Copilot extension active

## Test 1: ADO HTTPS Git URL as Marketplace Source

Add to VS Code `settings.json`:
```json
"chat.plugins.marketplaces": [
    "https://dev.azure.com/SSAAIAccelerator/Voyager%20Copilot%20Test/_git/voyager-copilot-plugin"
]
```

- [ ] Does VS Code fetch the marketplace feed without errors?
- [ ] Does the "voyager" plugin appear when searching `@agentPlugins`?
- [ ] If ADO URL fails, try alternate formats:
  - `https://SSAAIAccelerator@dev.azure.com/SSAAIAccelerator/Voyager%20Copilot%20Test/_git/voyager-copilot-plugin`
  - With `.git` suffix
- [ ] Document: auth prompt? PAT required? credential manager integration?

**Fallback if ADO doesn't work:**
Use `chat.plugins.paths` pointing to local clone:
```json
"chat.plugins.paths": [
    "/path/to/local/voyager-copilot-plugin"
]
```

## Test 2: Plugin Installation

- [ ] Plugin installs from Extensions sidebar
- [ ] No errors in VS Code Output > GitHub Copilot Chat
- [ ] Installed plugin shows correct name and description

## Test 3: Skill Discovery

Open a workspace and ask Copilot:
> "I need to create a new dlt source for ServiceNow"

- [ ] Copilot matches keywords and reads the voyager-dlt skill
- [ ] Copilot reads the skill's references/ directory
- [ ] Response follows Voyager conventions (p8e-data-source-* pattern, Key Vault auth, etc.)

## Test 4: .instructions.md Bundling

- [ ] Does Copilot read the .instructions.md from the plugin?
- [ ] Test: ask "What deployment lanes does Voyager have?" — should answer from ambient context
- [ ] If .instructions.md is NOT picked up, plan preamble fallback (bake into each SKILL.md)

## Test 5: Plugin Update Propagation

1. Make a trivial change to SKILL.md (add a comment)
2. Bump version in plugin.json and marketplace.json
3. Push to ADO
4. Check: does VS Code detect the update?
- [ ] Update notification appears
- [ ] Updated skill content is used after update

## Test 6: Copilot CLI Diagnostics

```bash
# If Copilot CLI is available, test for better error messages
copilot plugin list
copilot plugin install ./plugins/voyager
```

- [ ] CLI provides useful error messages for manifest issues
- [ ] CLI confirms skill is loaded

## Results

| Test | Pass/Fail | Notes |
|------|-----------|-------|
| ADO URL as marketplace source | Inconclusive | Credential/network issues. Moved to GitHub. |
| Plugin installation | Pass | Manual clone workaround needed for VS Code bug |
| Skill discovery (explicit /voyager-dlt) | Pass | Skill appears in /skills, reads correctly |
| Skill auto-match on keywords | Pass | Requires domain-specific keywords in prompt |
| .instructions.md bundling | Fail | Not supported by plugin format. Preamble fallback works. |
| Plugin update propagation | Deferred | To be tested in Phase 1 |
| Copilot CLI diagnostics | Deferred | To be tested in Phase 1 |

## Issues Discovered

1. **VS Code clone bug:** Install button fails with "destination path already exists."
   VS Code pre-creates parent dirs, then git clone fails. Workaround: manually
   clone to `%APPDATA%/Code/agentPlugins/github.com/{owner}/{repo}`.

2. **Skill paths cannot traverse outside plugin root:** `../../skills/` does not
   resolve. Skills must be physically inside `plugins/voyager/skills/`.

3. **.instructions.md not a plugin capability:** Plugin format supports skills,
   agents, hooks, mcp, commands. No ambient instruction injection.

4. **ADO credential complexity from WSL:** Git credential manager needed non-standard
   config. Git for Windows was at user-local path, not Program Files.

See `PHASE-0-SETUP-JOURNAL.md` for full details on all issues and workarounds.
