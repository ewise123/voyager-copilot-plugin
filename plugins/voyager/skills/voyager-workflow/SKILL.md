---
name: voyager-workflow
description: >
  Workflow guidance for starting tasks from Azure DevOps work items.
  Use when the developer mentions a work item number, task ID, story ID,
  "my work items", "current sprint", "what should I work on", or
  "pick up task". Guides the agent through checking Definition of Ready,
  pulling work item hierarchy, and understanding acceptance criteria
  before starting work.
---

# Voyager Work Item Workflow

You have access to Azure DevOps via the ADO MCP server. Use it to pull
work item context before starting any task.

## When a developer says "work on task #12345" or similar

1. **Fetch the work item** using the ADO MCP tools. Get the full details
   including description, state, and assigned to.

2. **Walk the hierarchy.** Get the parent work item (user story), then
   its parent (feature), then its parent (epic). Present the full chain
   so the developer sees the context.

3. **Check the Story Definition of Ready.** The parent user story must
   meet ALL of these criteria before work should start:

   **Automated checks (verify from ADO data):**
   - [ ] Acceptance criteria populated (not empty — should be Given/When/Then
     or a checklist of testable criteria)
   - [ ] Story is assigned to current sprint/iteration
   - [ ] Story has an estimate (story points: 1, 2, 3, or 5)
   - [ ] If >5 points, flag: "This story may need to be broken down further"
   - [ ] Story is not in Blocked/Removed state
   - [ ] Check linked items for unresolved blockers

   **Assumed met (cannot verify from ADO data):**
   - [ ] User story format complete: "As a [role], I can [action], so that [benefit]"
   - [ ] Role, action, and benefit are explicit
   - [ ] Team understands what success looks like
   - [ ] Testable (team knows how to verify — manual test, automated test, or demo)
   - [ ] Team member volunteered to work on it

   If any automated check fails, warn the developer:
   "⚠️ Story #XXXXX may not be ready: [list failures]. Recommend
   resolving before starting. Proceed anyway?"

4. **Present the acceptance criteria** from the user story prominently.
   These define what "working" means.

5. **Present the Story Definition of Done checklist.** These define what
   "done" means — the developer should complete all items before closing:

   - [ ] Code written and meets standards (follows team coding conventions,
     no linting errors)
   - [ ] Unit tests written and passing (code coverage >80% or team-agreed
     threshold, edge cases tested)
   - [ ] Code reviewed and approved (at least one peer review in ADO/GitHub,
     review comments addressed)
   - [ ] Integrated with main branch (code merged, no lingering feature
     branches, CI/CD pipeline green)
   - [ ] Acceptance criteria verified (manual or automated test confirms AC met)
   - [ ] Product Owner can verify in dev/test environment (Story functional
     in shared environment, not just local)
   - [ ] Product Owner accepted (PO reviewed and approved in Sprint Review,
     or delegated acceptance to Tech Lead/Designer)
   - [ ] Story closed in ADO (status updated, DoD checklist completed)

   Tell the developer: "When you're done coding, run `/voyager-dod` to check
   the automated items (linting, tests, coverage) before creating a PR."

6. **Then proceed with the task** using the appropriate domain skill
   (voyager-dlt, voyager-dagster, etc.) based on what the task involves.

## Output format when presenting work item context

```
📋 Task #12345: [title]
State: [state] | Assigned to: [name]

📖 Story #12340: [title]
[user story description]

Acceptance Criteria:
[acceptance criteria from ADO]

DoR Status:
  ✅ Acceptance criteria populated
  ✅ Assigned to Sprint 24
  ✅ Estimated (5 points)
  ✅ Not blocked
  ⚠️ Cannot verify: story format, team understanding, testability, volunteer (assumed met)

🎯 Feature #12300: [title]
[brief description]

🏔️ Epic #12000: [title]
[brief description]

Story DoD (verify when complete):
  □ Code meets standards (linting, formatting)
  □ Unit tests passing (coverage >80%)
  □ Code reviewed and approved
  □ Integrated with main branch
  □ Acceptance criteria verified
  □ PO can verify in dev/test
  □ PO accepted
  □ Story closed in ADO

💡 When done coding, run /voyager-dod to check automated items.
```
