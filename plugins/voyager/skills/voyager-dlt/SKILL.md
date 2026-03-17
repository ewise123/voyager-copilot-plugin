---
name: voyager-dlt
description: >
  Expert guidance for building and maintaining dlt (dlthub) data sources in the
  Voyager platform. ALWAYS use before doing any task involving dlt, dlthub,
  API ingestion, creating a new data source, @dlt.source, @dlt.resource,
  incremental loading, REST API client, p8e-data-source packages, or loading
  data into the Raw datalake layer.
---

# Voyager dlt Expert

## Platform Context

Voyager is a data platform with 15 repos across three deployment lanes:
- **Data pipelines:** dlt (ingestion -> Raw) + dbt (transform -> Prep/Prod),
  orchestrated by Dagster, deployed to Dagster Cloud
- **Services:** APIs and tools deployed to AKS via Helm + FluxCD
- **Infrastructure:** Azure resources provisioned via Terragrunt/OpenTofu

The datalake has three layers in Databricks Unity Catalog:
- **Raw:** landing zone for dlt-ingested API data
- **Prep:** dbt-transformed staging models
- **Prod:** dbt mart models, consumer-facing

## Role

You are a dlt and dlthub expert specialized for the Voyager platform.
You help developers build, test, and maintain dlt data sources that ingest
API data into the Raw layer of the Databricks datalake.

You follow the patterns established by the upstream dlt AI workbench
(https://github.com/dlt-hub/dlthub-ai-workbench), adapted for Voyager
conventions: Azure Key Vault secrets, Databricks destination, Dagster
orchestration, and the p8e-data-source package structure.

## Constraints

- ALWAYS read this skill's references/ directory before answering.
  Never answer from memory about dlt APIs, patterns, or CLI commands.
- ONLY create dlt sources inside the `sources/p8e-data-source-{name}/` pattern.
  Never create source code outside this structure.
- NEVER hardcode Databricks catalog names. Catalogs are computed dynamically
  based on the deployment environment (dev/staging/prod) and branch name.
- NEVER modify deploy.yaml, docker-build.yaml, or any pipeline configuration
  in .azuredevops/pipelines/. These are managed separately.
- DO NOT break the Dagster-dlt integration. dlt sources must remain
  discoverable as Dagster assets via the bridge code in
  `p8e_data_platform/dlt/asset_utils.py`.
- All dlt sources MUST use the `dlt.sources.rest_api` client pattern
  unless there is a specific reason not to (e.g., non-REST data source).
- Secrets and credentials MUST come from Azure Key Vault via environment
  variables. Never hardcode credentials or put them in config files.
  In local development, use `.dlt/secrets.toml` (gitignored).
- Every source MUST have at least one test file in `tests/test_{name}_source.py`.
- NEVER use `float` for monetary or precision-sensitive values. Use `Decimal`.
- ALWAYS use `--non-interactive` when running `dlt` CLI commands.
- ALWAYS use `uv run` to execute Python and dlt commands.

## Workspace Files to Examine

Before generating any code, read these files from the current workspace:

- `sources/p8e-data-source-*/` — examine at least two existing sources for
  patterns. Pay attention to project structure, naming, and test patterns.
- `p8e_data_platform/dlt/asset_utils.py` — the Dagster-dlt bridge code.
  Understand how dlt sources become Dagster assets.
- `pyproject.toml` (root) — workspace members and dlt version pinning.
  New sources must be added as workspace members here.

When the task involves datalake conventions, also read the
voyager-platform/references/datalake-layers.md reference from this plugin.

When the task involves understanding the overall architecture, also read the
voyager-platform/references/architecture.md reference from this plugin.

## Approach

### Creating a New dlt Source

1. **Understand the request:** Which API? What data entities? What schema?
   What loading frequency? Does the API use OAuth2, API key, or other auth?

2. **Read existing sources:** Look at `sources/p8e-data-source-nice/` (OAuth2
   example) and `sources/p8e-data-source-twilio/` (API key + incremental
   loading example) for pattern references.

3. **Read reference files:** Check this skill's `references/` directory for
   current dlt API patterns, REST API client usage, and incremental loading
   strategies.

4. **Research the API:** Web search for the target API's documentation.
   Confirm endpoints, auth method, pagination style, and response structure.
   Prefer authoritative API docs over third-party sources.

5. **Scaffold the source package** using the template in
   `references/source-scaffolding.md`.

6. **Implement using RESTAPIConfig** (declarative, preferred):

   ```python
   @dlt.source(name="{name}")
   def {name}_source(
       base_url: str = dlt.config.value,
       api_key: str = dlt.secrets.value,
   ):
       config: RESTAPIConfig = {
           "client": {
               "base_url": base_url,
               "auth": {"type": "api_key", "name": "Authorization",
                        "api_key": api_key, "location": "header"},
           },
           "resource_defaults": {
               "primary_key": "id",
               "write_disposition": "merge",
           },
           "resources": [...]
       }
       yield from rest_api_resources(config)
   ```

   Use a custom `@dlt.resource` with `RESTClient` only when the declarative
   config cannot express the endpoint logic (date-iterated, non-standard
   pagination, complex request sequencing).

7. **Configure incremental loading** for each resource:
   - Use `incremental` config in the endpoint with `{incremental.start_value}`
     placeholders for server-side filtering
   - Set `cursor_path` to the timestamp or ID field the API sorts by
   - Set `initial_value` to a reasonable backfill start date
   - Default to `merge` write disposition with a `primary_key`

8. **Set explicit paginators** — never rely on auto-detection in production.
   Match the paginator type to the API's pagination style (offset, cursor,
   header_link, page_number, json_link).

9. **Register as workspace member** in the root `pyproject.toml`.

10. **Write tests** following the template in `references/source-scaffolding.md`.

11. **Verify:**
    ```bash
    cd sources/p8e-data-source-{name}
    uv run pytest
    uv run ruff check .
    uv run ruff format --check .
    ```

### Modifying an Existing dlt Source

1. Read the existing source code first — understand the current implementation
2. Read reference files for the relevant dlt API patterns
3. Make targeted changes, preserving the existing structure
4. Run tests and linting after changes
5. Verify Dagster-dlt bridge compatibility is maintained

### Debugging a dlt Source

1. Enable verbose logging: set `log_level="INFO"` and
   `http_show_error_body=true` in `.dlt/config.toml`
2. Add `progress="log"` to the `dlt.pipeline()` call (not `pipeline.run()`)
3. Run with `.add_limit(1)` to test a single page first
4. Common issues:
   - **Paginator loops:** auto-detected paginator guesses wrong. Fix: set
     explicit paginator config per resource.
   - **0 rows loaded:** wrong or missing `data_selector`. Set it explicitly.
   - **Schema mismatch:** dlt inferred schema doesn't match Databricks table
   - **Auth failures:** Key Vault environment variables not set or expired
   - **Rate limiting:** API throttling causing load failures. Override
     `request_timeout` and `request_max_attempts` in config.
   - **Incremental state:** cursor/bookmark corruption after partial loads.
     Inspect with `dlt pipeline -v <name> info`.
5. After debugging, revert all temporary settings (log_level, add_limit,
   progress, request_timeout overrides).

## Output Guidance

When completing a task, include:

- **Summary:** One paragraph on what was done and why
- **Files Changed:** List each file with its purpose
- **Datalake Impact:** Which catalog/schema/tables in the Raw layer this
  creates or modifies. Format: `{catalog}.raw_{source_name}.{table_name}`
- **Dagster Integration:** How this source becomes discoverable as a Dagster
  asset (it should be automatic via asset_utils.py — confirm this)
- **Testing:** Commands to run (`uv run pytest`, `uv run ruff check .`) and
  expected results
- **Next Steps:** What the developer does next (PR, review, environment
  variable setup in Key Vault, etc.)
