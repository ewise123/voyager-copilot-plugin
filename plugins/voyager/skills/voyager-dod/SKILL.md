---
name: voyager-dod
description: >
  Story Definition of Done verification and pre-commit quality checks.
  Use when the developer says "check DoD", "am I done", "verify definition
  of done", "run DoD checks", "ready for PR", "ready for review",
  "pre-commit check", "run checks", "lint check", or after completing
  work on a task.
---

# Voyager DoD and Quality Check

Verify code quality and Story-level Definition of Done. Combines automated
pre-commit checks with DoD verification.

## When to run

- Developer says "check DoD", "am I done", "ready for PR"
- Developer says "pre-commit check", "run checks", "lint"
- After completing work from a voyager-workflow task
- Before creating a pull request
- After refactors that may affect multiple packages

## Stage 1: Automated Quality Checks

Detect the repository state and run appropriate checks.

### Step 1: Detect check mode

Check whether `.pre-commit-config.yaml` exists and has hook definitions.

- **If hooks exist and are non-empty:** prefer hook-based execution
- **If hooks are missing or empty:** use fallback direct commands

### Step 2A: Hook-based checks (when .pre-commit-config.yaml exists)

Ask the developer: changed files only, or full repo?

| Scope | Command |
|-------|---------|
| Changed files only | `pre-commit run` |
| Full repo | `pre-commit run --all-files` |

### Step 2B: Fallback checks (when no pre-commit config)

Run these from the repo root:

**Python checks (if pyproject.toml exists):**

| Check | Command | DoD Item |
|-------|---------|----------|
| Linting | `uv run ruff check .` | Code meets standards |
| Formatting | `uv run ruff format --check .` | Code meets standards |
| Tests | `uv run pytest` | Unit tests written and passing |
| Coverage | `uv run pytest --cov --cov-fail-under=80` | Coverage >80% |

**dbt checks (if dbt/ directory exists or dbt files were changed):**

| Check | Command | Purpose |
|-------|---------|---------|
| Dependencies | `uv run dbt deps` | Ensure packages resolved |
| Parse/compile | `uv run dbt parse` | Validate model SQL and refs |

**If neither pyproject.toml nor dbt/ exists:**
Skip automated checks and note:
"No pyproject.toml or dbt project found — skipping automated checks.
Manual verification needed for code standards and test coverage."

### Step 3: Report results

Format as:
```
Quality Checks (mode: hook-based / fallback)

  Linting:        pass / fail
  Formatting:     pass / fail
  Tests:          pass / fail
  Coverage:       pass (87%) / fail (62%, need 80%)
  dbt parse:      pass / skipped (no dbt project)
```

If any check fails:
1. Show the error output and file paths
2. Suggest targeted fixes
3. After fixes, re-run only the failing checks
4. Then run a final full verification

## Stage 2: Acceptance Criteria Review

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

  [ ] Code reviewed and approved
    - Create PR in ADO/GitHub
    - At least one peer review
    - Address all review comments

  [ ] Integrated with main branch
    - Merge PR
    - Confirm CI/CD pipeline green
    - No lingering feature branches

  [ ] Acceptance criteria verified
    - Manual or automated test confirms AC met
    - Edge cases tested

  [ ] Product Owner can verify
    - Story functional in dev/test environment (not just local)

  [ ] Product Owner accepted
    - PO reviewed in Sprint Review
    - Or delegated acceptance to Tech Lead/Designer

  [ ] Story closed in ADO
    - Status updated to Done/Closed
    - DoD checklist completed in ADO
```

## Completion Criteria

- All selected checks return exit code 0
- No unresolved lint errors in touched files
- Any skipped checks are explicitly listed with reason
- Final summary includes exact commands executed and status
