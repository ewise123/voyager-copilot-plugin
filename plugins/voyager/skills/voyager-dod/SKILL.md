---
name: voyager-dod
description: >
  Story Definition of Done verification. Use when the developer says
  "check DoD", "am I done", "verify definition of done", "run DoD checks",
  "ready for PR", "ready for review", or after completing work on a task.
  Runs automated code quality checks and presents remaining human actions.
---

# Voyager Story DoD Check

Verify the Story-level Definition of Done after completing work on a task.

## When to run

- Developer says "check DoD", "am I done", "ready for PR"
- After completing work from a voyager-workflow task
- Before creating a pull request

## Stage 1: Automated Checks

Run these commands in the current workspace and report results:

### Python projects (pyproject.toml exists)

| Check | Command | DoD Item |
|-------|---------|----------|
| Linting | `uv run ruff check .` | Code meets standards |
| Formatting | `uv run ruff format --check .` | Code meets standards |
| Tests | `uv run pytest` | Unit tests written and passing |
| Coverage | `uv run pytest --cov --cov-fail-under=80` | Coverage >80% |

Run each command and report pass/fail with details on any failures.

If `pyproject.toml` does not exist in the workspace root, skip the Python
checks and note:
"No pyproject.toml found — skipping automated Python checks.
Manual verification needed for code standards and test coverage."

### Format results as:

```
Stage 1: Automated Checks

  Linting (ruff check):        ✅ Passed / ❌ Failed
  Formatting (ruff format):    ✅ Passed / ❌ Failed
  Tests (pytest):              ✅ Passed / ❌ Failed
  Coverage (pytest --cov):     ✅ Passed (87%) / ❌ Failed (62%, need 80%)
```

If any check fails, show the error output and suggest how to fix it.
Do NOT stop — continue to Stage 2 and Stage 3 regardless.

## Stage 2: Acceptance Criteria Review (Manual)

If the developer started work via voyager-workflow (task #NNN), remind them
of the acceptance criteria from the parent story:

"Review the acceptance criteria from Story #NNN:
[list acceptance criteria]

For each criterion, confirm it is met by the code changes."

If no story context is available, ask:
"What are the acceptance criteria for this work? I can help verify them."

## Stage 3: Remaining Human Actions

Always print this checklist at the end:

```
Remaining actions to complete the Story DoD:

  □ Code reviewed and approved
    - Create PR in ADO/GitHub
    - At least one peer review
    - Address all review comments

  □ Integrated with main branch
    - Merge PR
    - Confirm CI/CD pipeline green
    - No lingering feature branches

  □ Acceptance criteria verified
    - Manual or automated test confirms AC met
    - Edge cases tested

  □ Product Owner can verify
    - Story functional in dev/test environment (not just local)

  □ Product Owner accepted
    - PO reviewed in Sprint Review
    - Or delegated acceptance to Tech Lead/Designer

  □ Story closed in ADO
    - Status updated to Done/Closed
    - DoD checklist completed in ADO
```
