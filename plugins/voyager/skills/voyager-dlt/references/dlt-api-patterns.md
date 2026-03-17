# dlt API Patterns — Voyager Curated Reference

> Curated from the [dlt-hub AI workbench](https://github.com/dlt-hub/dlthub-ai-workbench)
> and [dlt docs](https://dlthub.com/docs). Filtered for Voyager conventions:
> Databricks destination, Azure Key Vault secrets, environment variable config.

## Source and Resource Decorators

### @dlt.source

Defines a logical grouping of related resources (API endpoints).
One source per external system (e.g., ServiceNow, Twilio, NICE).

```python
import dlt
from dlt.sources.rest_api import RESTAPIConfig, rest_api_resources

@dlt.source(name="servicenow")
def servicenow_source(
    instance_url: str = dlt.config.value,
    api_key: str = dlt.secrets.value,
):
    """ServiceNow API source — loads incidents and change requests.

    Args:
        instance_url: ServiceNow instance URL. Resolved from env var
            SOURCES__SERVICENOW__INSTANCE_URL.
        api_key: API key. Resolved from env var
            SOURCES__SERVICENOW__API_KEY (Key Vault backed).
    """
    config: RESTAPIConfig = {
        "client": {
            "base_url": instance_url,
            "auth": {"type": "api_key", "name": "Authorization",
                     "api_key": api_key, "location": "header"},
        },
        "resources": [...]
    }
    yield from rest_api_resources(config)
```

**Voyager convention:** Source name must match the directory name.
`p8e-data-source-servicenow` -> `@dlt.source(name="servicenow")`.

### @dlt.resource

Defines a single data stream (typically one API endpoint = one table).
Use when the declarative RESTAPIConfig cannot express the endpoint logic.

```python
@dlt.resource(
    name="incidents",
    write_disposition="merge",
    primary_key="sys_id",
)
def incidents(
    instance_url: str,
    api_key: str,
    updated_at: dlt.sources.incremental[str] = dlt.sources.incremental(
        cursor_path="sys_updated_on",
        initial_value="2024-01-01T00:00:00Z",
    ),
):
    """Load ServiceNow incidents with incremental updates."""
    from dlt.sources.helpers.rest_client import RESTClient

    client = RESTClient(
        base_url=instance_url,
        headers={"Authorization": f"Bearer {api_key}"},
    )
    yield from client.paginate(
        "/api/now/table/incident",
        params={"sysparm_query": f"sys_updated_on>{updated_at.start_value}"},
    )
```

## RESTAPIConfig (Declarative Pattern — Preferred)

The declarative config is the default approach for all REST API sources.

### Full Structure

```python
config: RESTAPIConfig = {
    "client": {
        "base_url": "https://api.example.com/v1/",
        "auth": {...},           # see Authentication section
        "paginator": {...},      # default paginator for all resources
        "headers": {},           # additional headers
    },
    "resource_defaults": {
        "primary_key": "id",
        "write_disposition": "merge",
        "endpoint": {
            "params": {"per_page": 100},
        },
    },
    "resources": [
        {
            "name": "items",
            "endpoint": {
                "path": "items",
                "params": {"sort": "updated_at"},
                "paginator": {...},       # override per-resource
                "data_selector": "data",  # JSONPath to response array
                "incremental": {...},     # incremental loading config
            },
            "primary_key": "id",
            "write_disposition": "merge",
            "processing_steps": [...],
        },
    ],
}
```

### Resource Relationships (Parent-Child)

Resolve parent field values into child endpoint paths or params:

```python
"resources": [
    {
        "name": "issues",
        "endpoint": {"path": "issues"},
    },
    {
        "name": "issue_comments",
        "endpoint": {
            "path": "issues/{resources.issues.number}/comments",
        },
        "include_from_parent": ["id"],
    },
]
```

Or via query parameters:

```python
{
    "name": "post_comments",
    "endpoint": {
        "path": "comments",
        "params": {"post_id": "{resources.posts.id}"},
    },
}
```

## Authentication Patterns

### API Key (header or query parameter)

```python
"auth": {
    "type": "api_key",
    "name": "X-API-Key",        # header name or query param name
    "api_key": api_key,          # from dlt.secrets.value -> Key Vault env var
    "location": "header",        # "header" or "query"
}
```

### Bearer Token

```python
"auth": {
    "type": "bearer",
    "token": access_token,       # from dlt.secrets.value
}
```

### HTTP Basic Auth

```python
"auth": {
    "type": "http_basic",
    "username": username,
    "password": password,        # from dlt.secrets.value
}
```

### OAuth 2.0 Client Credentials

```python
"auth": {
    "type": "oauth2_client_credentials",
    "access_token_url": "https://auth.example.com/oauth2/token",
    "client_id": client_id,      # from dlt.secrets.value
    "client_secret": client_secret,  # from dlt.secrets.value
    "access_token_request_data": {},  # extra form fields if needed
    "default_token_expiration": 3600,
}
```

**Voyager convention:** All credential values MUST come from `dlt.secrets.value`
parameters, which resolve to environment variables backed by Azure Key Vault.
Environment variable naming: `SOURCES__{SOURCE_NAME}__{FIELD_NAME}` (double
underscores). Never hardcode credentials.

## Pagination Patterns

ALWAYS set an explicit paginator. Never rely on auto-detection in production.

### Offset-based

```python
"paginator": {
    "type": "offset",
    "limit": 100,
    "offset_param": "offset",
    "limit_param": "limit",
    "total_path": "total",            # JSONPath to total count in response
    "stop_after_empty_page": True,    # safety: stop if page is empty
}
```

### Cursor-based

```python
"paginator": {
    "type": "cursor",
    "cursor_path": "meta.next_cursor",  # JSONPath to cursor in response
    "cursor_param": "cursor",           # query param name to send cursor
}
```

### Link Header (RFC 5988)

```python
"paginator": {
    "type": "header_link",
    "links_next_key": "next",
}
```

### JSON Link (next URL in response body)

```python
"paginator": {
    "type": "json_link",
    "next_url_path": "pagination.next",  # JSONPath to next URL
}
```

### Page Number

```python
"paginator": {
    "type": "page_number",
    "page_param": "page",
    "base_page": 1,
    "total_path": "total_pages",
    "stop_after_empty_page": True,
}
```

### Single Page (no pagination)

```python
"paginator": {"type": "single_page"}
```

**Common pitfall:** `OffsetPaginator` and `PageNumberPaginator` without
`total_path` or `stop_after_empty_page=True` will loop forever. Always set
at least one stop condition.

## Incremental Loading

### Declarative (in RESTAPIConfig endpoint)

Use `{incremental.start_value}` placeholders in params, path, or JSON body:

```python
{
    "name": "incidents",
    "endpoint": {
        "path": "incidents",
        "params": {
            "updated_since": "{incremental.start_value}",
            "sort": "updated_at",
        },
        "incremental": {
            "cursor_path": "updated_at",
            "initial_value": "2024-01-01T00:00:00Z",
        },
    },
    "primary_key": "id",
    "write_disposition": "merge",
}
```

**Placeholder variants:**
- `{incremental.start_value}` — last tracked max (or initial_value on first run)
- `{incremental.last_value}` — last seen value during current run
- `{incremental.initial_value}` — always the initial value
- `{incremental.end_value}` — upper bound (for backfill ranges)

### Programmatic (with @dlt.resource)

```python
@dlt.resource(primary_key="id", write_disposition="merge")
def items(
    updated_at: dlt.sources.incremental[str] = dlt.sources.incremental(
        cursor_path="updated_at",
        initial_value="2024-01-01T00:00:00Z",
    ),
):
    # updated_at.start_value = max from previous run (or initial_value)
    # updated_at.last_value = tracks max during this run
    yield from fetch_items(since=updated_at.start_value)
```

### dlt.sources.incremental Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `cursor_path` | required | Field name to track (supports JSONPath) |
| `initial_value` | required | Start value for first run |
| `last_value_func` | `max` | Comparison function (`max`, `min`, or custom) |
| `end_value` | None | Upper bound for backfill (stateless) |
| `row_order` | None | `"asc"` or `"desc"` — enables early termination |
| `on_cursor_value_missing` | `"raise"` | `"raise"`, `"include"`, or `"exclude"` |
| `primary_key` | None | Override dedup key; `()` disables dedup |
| `range_start` | `"closed"` | `"closed"` = deduplicate; `"open"` = skip prev cursor |

## Write Dispositions

| Disposition | Use When | Effect |
|-------------|----------|--------|
| `merge` | Data has a primary key and supports updates | Upserts rows by primary key |
| `append` | Event/log data that only grows | Adds new rows, never modifies existing |
| `replace` | Small lookup tables, full refresh needed | Drops and recreates table each run |

**Voyager convention:** Default to `merge` for entity data, `append` for
event/log data. Use `replace` only for small lookup/reference tables.
Document the choice in the source's docstring.

## Data Selector

Extract the data array from nested API responses:

```python
"data_selector": "data"           # {"data": [...]}
"data_selector": "results.items"  # {"results": {"items": [...]}}
```

Always set `data_selector` explicitly if the response wraps data in an object.
Without it, dlt tries to auto-detect but can fail silently (loads 0 rows).

## Processing Steps

Transform or filter data before loading:

```python
"processing_steps": [
    # Filter out inactive records
    {"filter": lambda x: x["status"] == "active"},

    # Transform a field (NEVER use float for money)
    {"map": lambda x: {**x, "amount": Decimal(x["amount"])}},

    # Flatten nested arrays into separate rows
    {"yield_map": flatten_nested_items},
]
```

## Configuration and Secrets

dlt resolves configuration in this order:
1. Environment variables (Voyager standard — backed by Azure Key Vault)
2. `secrets.toml` / `config.toml` (local development only)
3. Function parameter defaults

### Environment Variable Naming

```
SOURCES__{SOURCE_NAME}__{FIELD_NAME}
```

Examples:
```
SOURCES__SERVICENOW__INSTANCE_URL  -> instance_url param
SOURCES__SERVICENOW__API_KEY       -> api_key param
```

**Voyager convention:** Production secrets ALWAYS come from environment
variables backed by Key Vault. Never commit secrets.toml. Add it to
.gitignore. For local development, use `.dlt/secrets.toml`:

```toml
[sources.servicenow]
instance_url = "https://dev-instance.service-now.com"
api_key = "your-dev-api-key"
```

## Schema Inference

dlt infers schemas from the first batch of data. For Databricks:

- JSON objects -> STRUCT columns
- Arrays -> ARRAY columns
- Nested objects are flattened with `__` separator by default
- Column names are normalized to snake_case
- Nested arrays become child tables (e.g., `items__tags`)

**Voyager convention:** Let dlt handle schema inference. Do NOT manually
define schemas unless there's a specific mismatch issue. If schema issues
arise, use `columns` hints on the resource config:

```python
"columns": {"field_name": {"data_type": "text"}}
```

## Error Handling and Retry

dlt has built-in HTTP retry with exponential backoff:
- Default: 5 retries, up to 16s backoff per attempt, 60s request timeout
- A failing endpoint can stall for 60-80+ seconds before raising

Override for faster failure during development:

```toml
# .dlt/config.toml
[runtime]
request_timeout = 15
request_max_attempts = 2
```

For production, use `response_actions` to handle specific HTTP errors:

```python
"endpoint": {
    "response_actions": [
        {"status_code": 404, "action": "ignore"},
        {"status_code": 429, "action": "retry"},
    ],
}
```

## Authoritative Documentation

- REST API source config: https://dlthub.com/docs/dlt-ecosystem/verified-sources/rest_api/basic
- Source/resource decorators: https://dlthub.com/docs/general-usage/source and https://dlthub.com/docs/general-usage/resource
- Incremental loading: https://dlthub.com/docs/general-usage/incremental/cursor
- Credentials setup: https://dlthub.com/docs/general-usage/credentials/setup
- RESTClient (programmatic): https://dlthub.com/docs/general-usage/http/rest-client
- CLI reference: https://dlthub.com/docs/reference/command-line-interface
- How dlt works: https://dlthub.com/docs/reference/explainers/how-dlt-works
- Full docs index: https://dlthub.com/docs/llms.txt
