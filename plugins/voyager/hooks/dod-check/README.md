# Voyager DoD Check Hook

Runs automatically when the coding agent session ends. Verifies the
Story-level Definition of Done.

## Stages

### Stage 1: Automated (blocks on failure)

| Check | Command | DoD Item |
|-------|---------|----------|
| Linting | `uv run ruff check .` | Code meets standards |
| Formatting | `uv run ruff format --check .` | Code meets standards |
| Tests | `uv run pytest` | Unit tests passing |
| Coverage | `uv run pytest --cov --cov-fail-under=80` | Coverage >80% |

Requires `pyproject.toml` in the working directory. If not found,
Python checks are skipped with a warning.

### Stage 2: LLM-Evaluated (not yet implemented)

Placeholder for future LLM-based evaluation of acceptance criteria.

### Stage 3: Remaining Human Actions

Prints a checklist of actions that require human judgment:
PR review, merge, PO verification, story closure.

## Manual testing

```bash
# In a Python project directory with pytest and ruff:
node check.js

# In a non-Python directory:
node check.js
# Should skip gracefully
```
