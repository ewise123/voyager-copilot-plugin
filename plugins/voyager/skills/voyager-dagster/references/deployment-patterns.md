# Deployment Patterns Reference

Curated from dagster-io/skills v0.0.12 (dagster-expert skill). Adapted for
Voyager platform conventions (Dagster Cloud, Azure, ADO pipelines).

---

## dg CLI Overview

The `dg` CLI is the recommended way to interact with Dagster. Installed via
the `dagster-dg-cli` package. Always run with `uv run dg`.

### Project Scaffolding

```bash
# Create a new Dagster project (NEVER create manually)
uvx create-dagster project <name> --uv-sync

# Create a workspace (multiple related projects)
uvx create-dagster workspace <name>
```

### Adding Definitions

```bash
# Scaffold a new asset
uv run dg scaffold defs dagster.asset assets/my_asset.py

# Scaffold a new schedule
uv run dg scaffold defs dagster.schedule schedules/daily.py

# Scaffold a new sensor
uv run dg scaffold defs dagster.sensor sensors/watcher.py

# Scaffold a component
uv run dg scaffold defs dagster_dbt.DbtProjectComponent my_dbt \
  --project-dir dbt_project
```

After scaffolding, always verify:
```bash
uv run dg list defs --json
```

### Exploring and Validating

```bash
# List all definitions
uv run dg list defs
uv run dg list defs --json  # Machine-readable (prefer for agent use)

# Validate definitions load without errors
uv run dg check defs
uv run dg check defs --verbose

# Validate YAML config
uv run dg check yaml

# Validate pyproject.toml / dg.toml
uv run dg check toml

# List environment variable references
uv run dg list envs

# List available component types
uv run dg list components
```

### Local Development

```bash
# Start local Dagster webserver and daemon
uv run dg dev

# Materialize specific assets
uv run dg launch --assets my_asset
uv run dg launch --assets asset_a,asset_b

# Materialize all assets
uv run dg launch --assets "*"

# Materialize with partition
uv run dg launch --assets my_asset --partition 2024-01-15
uv run dg launch --assets my_asset --partition-range "2024-01-01...2024-01-31"

# With configuration
uv run dg launch --assets my_asset --config '{"limit": 100}'
```

---

## Dagster Cloud (Dagster Plus) Deployment

Voyager deploys to Dagster Cloud (Plus). Key concepts:

### Authentication

```bash
# Login to Dagster Plus (required before deploy commands)
uv run dg plus login
```

### Configuration

```bash
# Set Dagster Plus config
uv run dg plus config set

# View current config
uv run dg plus config view

# Create CI/CD API token
uv run dg plus create ci-api-token
```

### Deployment

```bash
# Configure CI/CD deployment (scaffolds GitHub Actions or GitLab CI)
uv run dg plus deploy configure

# Ad-hoc deployment (prefer CI/CD in practice)
uv run dg plus deploy
```

The `dagster-cloud` Python package must be a project dependency for deployment.

### Environment Variables in Dagster Plus

```bash
# Pull env vars from Dagster Plus into local .env
uv run dg plus pull env
```

### dbt Manifest Management

```bash
# Auto-manage dbt manifest uploads to Dagster Plus
uv run dg plus integrations dbt manage-manifest
```

---

## Voyager Deployment Conventions

### deploy.yaml

The `deploy.yaml` file at the repo root configures which code locations are
deployed to Dagster Cloud. This file is managed by the platform team.
**Never modify deploy.yaml directly.**

### Branch Deployments

PRs automatically create ephemeral Dagster Cloud deployments. This allows
testing new assets, schedules, and sensors in an isolated environment
before merging to main.

### CI/CD Pipeline

Deployment is managed by ADO (Azure DevOps) pipelines in
`.azuredevops/pipelines/`. **Never modify these pipeline configs.**

The pipeline:
1. Builds Docker images with the Dagster project code
2. Pushes to container registry
3. Deploys to Dagster Cloud via the dagster-cloud CLI
4. Creates branch deployments for PRs

---

## dlt-Dagster Bridge

dlt sources become Dagster assets through the bridge in
`p8e_data_platform/dlt/asset_utils.py`.

### How It Works

1. dlt sources are defined in `sources/p8e-data-source-{name}/`
2. The bridge code discovers source packages and wraps each dlt resource
   as a Dagster asset
3. Assets are named based on the dlt source and resource names
4. The bridge handles materialization by running the dlt pipeline

### Adding a New dlt Source

1. Create the dlt source package (use voyager-dlt skill)
2. Register it as a workspace member in `pyproject.toml`
3. Verify it appears in Dagster:
   ```bash
   uv run dg list defs --json | grep -i "{source_name}"
   ```
4. No manual Dagster asset definition needed -- the bridge is automatic

### Troubleshooting Bridge Issues

- Source not appearing: check package is in pyproject.toml workspace members
- Import error: check dlt source module has proper `__init__.py` exports
- Asset name mismatch: check source/resource naming in the dlt source

---

## dbt-Dagster Bridge

dbt models become Dagster assets via the `dagster-dbt` integration.

### How It Works

1. The `@dbt_assets` decorator loads the dbt manifest
2. Each dbt model becomes an individual Dagster asset
3. dbt `ref()` calls create asset dependencies
4. dbt `source()` calls create dependencies on upstream assets (e.g., dlt Raw tables)
5. Custom `DagsterDbtTranslator` controls naming, grouping, metadata

### Key Patterns

```python
from dagster_dbt import DbtCliResource, DbtProject, dbt_assets

my_dbt_project = DbtProject(project_dir="path/to/dbt", target="dev")
dbt_resource = DbtCliResource(project_dir=my_dbt_project.project_dir)

@dbt_assets(manifest=my_dbt_project.manifest_path)
def my_dbt_assets(context: dg.AssetExecutionContext, dbt: DbtCliResource):
    yield from dbt.cli(["build"], context=context).stream()
```

### Adding dbt Dependencies on dlt Assets

Define a dbt source in `sources.yml` pointing to the Raw layer table:

```yaml
sources:
  - name: raw_data
    tables:
      - name: my_dlt_table
```

Then reference in dbt SQL:
```sql
select * from {{ source('raw_data', 'my_dlt_table') }}
```

This creates the full lineage: dlt -> Raw table -> dbt model -> Prep/Prod.

### Scheduling dbt Assets

```python
from dagster_dbt import build_schedule_from_dbt_selection

daily_dbt_schedule = build_schedule_from_dbt_selection(
    [my_dbt_assets],
    job_name="daily_dbt_models",
    cron_schedule="0 0 * * *",
    dbt_select="tag:daily",
)
```

### Metadata

```python
@dbt_assets(manifest=my_dbt_project.manifest_path)
def my_dbt_assets(context, dbt: DbtCliResource):
    yield from (
        dbt.cli(["build"], context=context)
        .stream()
        .fetch_row_counts()
        .fetch_column_metadata()
    )
```

### Referencing dbt Models in Other Assets

```python
from dagster_dbt import get_asset_key_for_model

@dg.asset(deps=[get_asset_key_for_model([my_dbt_assets], "customers")])
def export_customers():
    pass
```

---

## Components

Components are reusable building blocks that generate Dagster definitions.
Key component types relevant to Voyager:

- `dagster_dbt.DbtProjectComponent` -- wraps a dbt project
- Custom components can be created for domain-specific patterns

### Scaffolding Components

```bash
# List available component types
uv run dg list components

# Scaffold a component
uv run dg scaffold defs dagster_dbt.DbtProjectComponent my_dbt \
  --project-dir dbt_project

# Scaffold a custom component type
uv run dg scaffold component my_custom_component
```

### Component YAML Configuration

Components are configured via `defs.yaml` files with Jinja2 template support:

```yaml
component: dagster_dbt.DbtProjectComponent
params:
  project_dir: dbt_project
  target: "{{ env.DBT_TARGET }}"
```

---

## Troubleshooting Checklist

1. **Definitions won't load:** `uv run dg check defs --verbose`
2. **Asset not visible:** `uv run dg list defs --json` and check filters
3. **Schedule not running:** check `default_status` is `RUNNING`
4. **Sensor not firing:** check `minimum_interval_seconds` and cursor logic
5. **dlt source missing from graph:** check pyproject.toml workspace members
6. **dbt manifest error:** run `dbt parse` or `dbt compile` first
7. **Env var missing:** check `.env` file and `dg list envs`
8. **Branch deployment issues:** check deploy.yaml code location config
9. **Import errors:** check all deps in pyproject.toml `[project.dependencies]`
