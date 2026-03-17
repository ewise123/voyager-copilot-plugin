# Upstream Source Tracking

## dlt (dlthub)

- **Library source:** https://github.com/dlt-hub/dlt
- **Skill source:** https://github.com/dlt-hub/dlthub-ai-workbench
  - Toolkit: `workbench/rest-api-pipeline/` (skills: create-rest-api-pipeline,
    debug-pipeline, validate-data, new-endpoint, adjust-endpoint, find-source)
  - Rules: `workbench/rest-api-pipeline/rules/workflow.md`
  - Init toolkit: `workbench/init/` (setup-secrets, dlthub-workspace rule)
- **Version curated from:** dlt 1.14.x
- **Date curated:** 2026-03-17
- **Curated by:** Voyager platform team

## What was curated from upstream

### From rest-api-pipeline toolkit
- RESTAPIConfig declarative pattern (full structure, auth, pagination, resources)
- Authentication patterns: api_key, bearer, http_basic, oauth2_client_credentials
- Pagination patterns: offset, cursor, header_link, json_link, page_number, single_page
- Incremental loading: declarative (endpoint config) and programmatic (@dlt.resource)
- Processing steps: filter, map, yield_map
- Resource relationships (parent-child via path/params)
- Data selector configuration
- Debug workflow: verbose logging, add_limit, pagination verification

### From init toolkit
- Secrets management: environment variable resolution, TOML config hierarchy
- dlt.secrets.value / dlt.config.value parameter patterns

### From dlt docs
- dlt.sources.incremental full parameter reference
- Write dispositions (merge, append, replace)
- Schema inference behavior for Databricks
- Error handling and retry configuration
- Response actions

## What was changed during curation

- Replaced all destination references with Databricks Unity Catalog only
- Added Azure Key Vault environment variable convention for all secrets
- Added p8e-data-source-{name} directory structure and naming conventions
- Added p8e_data.sources.{name} Python package namespace
- Added Dagster-dlt bridge (asset_utils.py) integration requirements
- Added uv as the package manager (upstream uses uv too)
- Added ruff for linting/formatting
- Removed dlt init / dlt ai CLI workflow (Voyager sources are manually scaffolded)
- Removed dlt workspace MCP server references (not used in Voyager)
- Removed references to duckdb, postgres, bigquery, snowflake destinations
- Removed references to dlthub-runtime deployment (Voyager uses Dagster Cloud)

## Next curation check

- [ ] Check dlthub-ai-workbench for new skills or updated patterns
- [ ] Check dlthub releases for breaking changes to @dlt.source / @dlt.resource API
- [ ] Check if REST API client patterns have changed
- [ ] Check if incremental loading API has changed
- [ ] Check if new authentication types have been added
- [ ] Verify dlt version pinned in voyager-data-platform-repo pyproject.toml
