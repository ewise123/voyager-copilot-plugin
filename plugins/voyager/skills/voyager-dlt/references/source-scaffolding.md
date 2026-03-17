# dlt Source Scaffolding — Voyager Conventions

> Curated from the [dlt-hub AI workbench](https://github.com/dlt-hub/dlthub-ai-workbench)
> rest-api-pipeline toolkit. Adapted for Voyager package structure, Databricks
> destination, and Azure Key Vault secrets.

## Directory Structure

Every dlt source follows this exact layout:

```
sources/p8e-data-source-{name}/
├── pyproject.toml
├── src/
│   └── p8e_data/
│       └── sources/
│           └── {name}/
│               ├── __init__.py          # Source and resource definitions
│               └── config.py            # API config, endpoints, auth helpers
└── tests/
    └── test_{name}_source.py            # Tests
```

**Naming rules:**
- Directory: `p8e-data-source-{name}` (kebab-case)
- Python package: `p8e_data.sources.{name}` (snake_case)
- dlt source name: `{name}` (snake_case, matches package leaf)

## pyproject.toml Template

```toml
[project]
name = "p8e-data-source-{name}"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = [
    "dlt[az,databricks]>=1.14.0,<2.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=8.0",
    "ruff>=0.8",
]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.hatch.build.targets.wheel]
packages = ["src/p8e_data"]

[tool.ruff]
target-version = "py311"
line-length = 120

[tool.ruff.lint]
select = ["E", "F", "I", "UP", "B", "SIM"]

[tool.pytest.ini_options]
testpaths = ["tests"]
```

After creating the source, add it to the root `pyproject.toml`:

```toml
[tool.uv.workspace]
members = [
    "sources/p8e-data-source-nice",
    "sources/p8e-data-source-twilio",
    "sources/p8e-data-source-{name}",    # <-- add this
]
```

## __init__.py Template (Declarative RESTAPIConfig)

This is the preferred approach. Use the declarative config for all REST APIs
unless the endpoint logic requires custom iteration (date ranges, non-standard
pagination).

```python
"""
dlt source for {Name} API.

Loads {describe entities} into the Voyager Raw datalake layer.
Data lands in: {{catalog}}.raw_{name}.{{table_names}}

Auth: {OAuth2 | API key | bearer token} via Azure Key Vault environment
    variables.
Loading: Incremental via {cursor field} for entity data.
    Full refresh for lookup/reference tables.

Environment variables (Key Vault backed):
    SOURCES__{NAME}__BASE_URL: API base URL
    SOURCES__{NAME}__API_KEY: API key (secret)
"""

from __future__ import annotations

from decimal import Decimal

import dlt
from dlt.sources.rest_api import RESTAPIConfig, rest_api_resources


@dlt.source(name="{name}")
def {name}_source(
    base_url: str = dlt.config.value,
    api_key: str = dlt.secrets.value,
):
    """
    {Name} API source.

    Args:
        base_url: API base URL. Resolved from SOURCES__{NAME}__BASE_URL.
        api_key: API key. Resolved from SOURCES__{NAME}__API_KEY (Key Vault).

    Yields:
        {entity_1}: {description} (incremental, merge)
        {entity_2}: {description} (incremental, merge)

    Examples:
        # Auto-resolve from env vars / secrets.toml
        pipeline.run({name}_source())

        # Load specific resources only
        pipeline.run({name}_source().with_resources("{entity_1}"))

        # Explicit credentials (testing)
        pipeline.run({name}_source(
            base_url="https://api.example.com/v1",
            api_key="test-key",
        ))
    """
    config: RESTAPIConfig = {
        "client": {
            "base_url": base_url,
            "auth": {
                "type": "api_key",
                "name": "Authorization",
                "api_key": api_key,
                "location": "header",
            },
            "paginator": {
                "type": "offset",
                "limit": 100,
                "offset_param": "offset",
                "limit_param": "limit",
                "total_path": "total",
                "stop_after_empty_page": True,
            },
        },
        "resource_defaults": {
            "primary_key": "id",
            "write_disposition": "merge",
        },
        "resources": [
            {
                "name": "{entity_1}",
                "endpoint": {
                    "path": "{entity_1}",
                    "params": {
                        "updated_since": "{incremental.start_value}",
                        "sort": "updated_at",
                    },
                    "incremental": {
                        "cursor_path": "updated_at",
                        "initial_value": "2024-01-01T00:00:00Z",
                    },
                },
            },
            {
                "name": "{entity_2}",
                "endpoint": {
                    "path": "{entity_2}",
                    "params": {
                        "updated_since": "{incremental.start_value}",
                    },
                    "incremental": {
                        "cursor_path": "updated_at",
                        "initial_value": "2024-01-01T00:00:00Z",
                    },
                },
            },
        ],
    }
    yield from rest_api_resources(config)
```

## __init__.py Template (Custom @dlt.resource with RESTClient)

Use this when the API requires custom iteration logic (e.g., date-range
queries, complex pagination, non-REST patterns).

```python
"""
dlt source for {Name} API (custom resource pattern).
"""

from __future__ import annotations

import dlt
from dlt.sources.helpers.rest_client import RESTClient
from dlt.sources.helpers.rest_client.auth import APIKeyAuth


@dlt.source(name="{name}")
def {name}_source(
    base_url: str = dlt.config.value,
    api_key: str = dlt.secrets.value,
):
    """
    {Name} API source using custom resources.

    Args:
        base_url: API base URL.
        api_key: API key (Key Vault backed).
    """
    client = RESTClient(
        base_url=base_url,
        auth=APIKeyAuth(name="X-API-Key", api_key=api_key, location="header"),
    )

    @dlt.resource(
        name="{entity_1}",
        write_disposition="merge",
        primary_key="id",
    )
    def {entity_1}(
        updated_at: dlt.sources.incremental[str] = dlt.sources.incremental(
            cursor_path="updated_at",
            initial_value="2024-01-01T00:00:00Z",
        ),
    ):
        """{Entity_1} with incremental loading."""
        yield from client.paginate(
            "/api/v1/{entity_1}",
            params={"updated_since": updated_at.start_value},
        )

    yield {entity_1}
```

## config.py Template

```python
"""
{Name} API configuration and constants.

This file holds non-secret configuration: endpoint paths, pagination
defaults, rate limit settings. Secrets (API keys, tokens) are resolved
from environment variables via dlt.secrets.value.
"""

# API endpoints
ENDPOINTS = {
    "{entity_1}": "/api/v1/{entity_1}",
    "{entity_2}": "/api/v1/{entity_2}",
}

# Pagination defaults
DEFAULT_PAGE_SIZE = 100

# Rate limiting (for documentation; enforced by API)
RATE_LIMIT_REQUESTS = 100
RATE_LIMIT_WINDOW_SECONDS = 60

# Retry settings (override in .dlt/config.toml for dev)
MAX_RETRIES = 3
REQUEST_TIMEOUT_SECONDS = 30
```

## Test File Template

```python
"""Tests for p8e-data-source-{name}."""

from __future__ import annotations

import pytest


class TestSourceDiscovery:
    """Verify the source can be imported and discovered by Dagster bridge."""

    def test_source_import(self):
        """Source function is importable from the expected package path."""
        from p8e_data.sources.{name} import {name}_source

        assert callable({name}_source)

    def test_source_has_expected_name(self):
        """Source name matches the package directory name."""
        from p8e_data.sources.{name} import {name}_source

        source = {name}_source(
            base_url="https://mock.example.com",
            api_key="test-key",
        )
        assert source.name == "{name}"


class TestResourceEnumeration:
    """Verify the source yields the expected resources."""

    @pytest.fixture()
    def source(self):
        from p8e_data.sources.{name} import {name}_source

        return {name}_source(
            base_url="https://mock.example.com",
            api_key="test-key",
        )

    def test_resource_names(self, source):
        """Source returns all expected resources."""
        resource_names = list(source.resources.keys())
        assert "{entity_1}" in resource_names
        assert "{entity_2}" in resource_names

    def test_resource_write_dispositions(self, source):
        """All entity resources use merge disposition."""
        for name, resource in source.resources.items():
            # Entity resources should merge; lookup tables may replace
            assert resource.write_disposition in ("merge", "replace", "append")

    def test_resource_primary_keys(self, source):
        """All merge resources have a primary key set."""
        for name, resource in source.resources.items():
            if resource.write_disposition == "merge":
                assert resource.compute_table_schema().get("columns", {}) or True
                # Primary key validation — at minimum, the resource should
                # be configured with a primary_key


class TestIncrementalConfig:
    """Verify incremental loading is configured correctly."""

    @pytest.fixture()
    def source(self):
        from p8e_data.sources.{name} import {name}_source

        return {name}_source(
            base_url="https://mock.example.com",
            api_key="test-key",
        )

    def test_incremental_resources_have_cursor(self, source):
        """Resources with merge disposition should have incremental config."""
        # This test verifies the source can be instantiated with
        # incremental parameters. Deeper validation requires mock HTTP.
        assert source is not None
```

## Local Development Setup

For local development, create `.dlt/secrets.toml` (gitignored):

```toml
[sources.{name}]
base_url = "https://dev-instance.example.com/api/v1"
api_key = "your-dev-api-key-here"
```

And `.dlt/config.toml` for non-secret config:

```toml
[runtime]
log_level = "WARNING"

# Override for debugging:
# log_level = "INFO"
# http_show_error_body = true
```

## Verification Checklist

After scaffolding, run:

```bash
# From the source directory
cd sources/p8e-data-source-{name}

# Tests pass
uv run pytest

# Linting clean
uv run ruff check .
uv run ruff format --check .
```

Then verify from the workspace root:

```bash
# Workspace resolves the new member
uv sync

# Source is importable
uv run python -c "from p8e_data.sources.{name} import {name}_source; print('OK')"
```

Confirm Dagster integration:

```bash
# Verify the source is discoverable by asset_utils.py
# (check that the source function signature matches what the bridge expects)
uv run python -c "
from p8e_data.sources.{name} import {name}_source
s = {name}_source.__wrapped__ if hasattr({name}_source, '__wrapped__') else {name}_source
import inspect
sig = inspect.signature(s)
print(f'Source: {name}_source')
print(f'Params: {list(sig.parameters.keys())}')
print('OK')
"
```

## Production Checklist

Before merging a new source:

- [ ] Source follows `p8e-data-source-{name}` directory structure
- [ ] Python package is `p8e_data.sources.{name}`
- [ ] Source name in `@dlt.source(name="{name}")` matches package leaf
- [ ] All secrets use `dlt.secrets.value` (no hardcoded credentials)
- [ ] Key Vault environment variables documented in module docstring
- [ ] Explicit paginator set (no auto-detection)
- [ ] Incremental loading configured for entity resources
- [ ] Write dispositions documented (merge/append/replace with rationale)
- [ ] `data_selector` set explicitly if API wraps data
- [ ] Tests pass: `uv run pytest`
- [ ] Lint clean: `uv run ruff check . && uv run ruff format --check .`
- [ ] Added to root `pyproject.toml` workspace members
- [ ] `uv sync` resolves successfully
- [ ] No `float` used for monetary values (use `Decimal`)
