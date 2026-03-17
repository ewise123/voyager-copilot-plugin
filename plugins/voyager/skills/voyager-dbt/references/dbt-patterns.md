# dbt Patterns for Voyager

Curated patterns for building dbt models in the Voyager platform on
Databricks with Unity Catalog.

## Model File Structure and Naming

### Directory Layout

```
models/
├── staging/                          # Prep layer (1:1 with source tables)
│   ├── {source_name}/
│   │   ├── _stg_{source}__sources.yml   # Source definitions
│   │   ├── _stg_{source}__models.yml    # Model schema + tests
│   │   ├── stg_{source}__{entity}.sql   # Staging model SQL
│   │   └── stg_{source}__{entity2}.sql
│   └── {another_source}/
├── intermediate/                     # Prep layer (joins, reshaping)
│   ├── {domain}/
│   │   ├── _int_{domain}__models.yml
│   │   └── int_{description}.sql
└── marts/                            # Prod layer (consumer-facing)
    ├── {domain}/
    │   ├── _{domain}__models.yml
    │   ├── fct_{entity}.sql           # Fact tables (events, transactions)
    │   └── dim_{entity}.sql           # Dimension tables (entities, attributes)
    └── {another_domain}/
```

### Naming Conventions

| Layer | Prefix | Example |
|-------|--------|---------|
| Staging | `stg_` | `stg_nice__interactions.sql` |
| Intermediate | `int_` | `int_interactions_joined.sql` |
| Fact | `fct_` | `fct_daily_call_volume.sql` |
| Dimension | `dim_` | `dim_agents.sql` |

- Double underscore `__` separates source from entity in staging names
- Domain folders group related models (e.g., `marts/contact_center/`)
- YAML files use underscore prefix `_` for alphabetical sorting

## Materialization Strategies

### Staging Models (Prep Layer)

Use `view` materialization. Staging models are lightweight transformations
that rename, cast, and clean columns from raw sources.

```sql
-- models/staging/nice/stg_nice__agents.sql
{{ config(materialized='view') }}

with source as (
    select * from {{ source('nice', 'agents') }}
),

renamed as (
    select
        agent_id,
        cast(first_name as string) as first_name,
        cast(last_name as string) as last_name,
        cast(email as string) as email,
        cast(hire_date as date) as hire_date,
        cast(is_active as boolean) as is_active,
        _dlt_load_id,
        _dlt_id
    from source
)

select * from renamed
```

### Mart Models (Prod Layer) - Table

Use `table` materialization for models that are queried frequently and
where rebuild cost is acceptable.

```sql
-- models/marts/contact_center/dim_agents.sql
{{ config(materialized='table') }}

with agents as (
    select * from {{ ref('stg_nice__agents') }}
),

teams as (
    select * from {{ ref('stg_nice__teams') }}
),

final as (
    select
        agents.agent_id,
        agents.first_name,
        agents.last_name,
        agents.email,
        teams.team_name,
        agents.hire_date,
        agents.is_active
    from agents
    left join teams on agents.team_id = teams.team_id
)

select * from final
```

### Mart Models (Prod Layer) - Incremental

Use `incremental` for large fact tables where full rebuilds are expensive.
On Databricks, use the `merge` strategy with `unique_key`.

```sql
-- models/marts/contact_center/fct_interactions.sql
{{ config(
    materialized='incremental',
    unique_key='interaction_id',
    incremental_strategy='merge',
    on_schema_change='append_new_columns'
) }}

with interactions as (
    select * from {{ ref('stg_nice__interactions') }}
    {% if is_incremental() %}
    where updated_at > (select max(updated_at) from {{ this }})
    {% endif %}
),

final as (
    select
        interaction_id,
        agent_id,
        customer_id,
        interaction_type,
        started_at,
        ended_at,
        duration_seconds,
        updated_at
    from interactions
)

select * from final
```

### Databricks-Specific Materializations

**Liquid clustering** (replaces partitioning on Databricks):

```sql
{{ config(
    materialized='table',
    liquid_clustered_by=['date_day', 'agent_id']
) }}
```

**File format:**

```sql
{{ config(
    materialized='table',
    file_format='delta'
) }}
```

## Source Configuration

Sources define the raw tables that dlt ingests into the Raw layer.

```yaml
# models/staging/nice/_stg_nice__sources.yml
version: 2

sources:
  - name: nice
    description: "Contact center data ingested by dlt from NICE CXone API"
    schema: "raw_nice"
    # Catalog is NOT hardcoded - resolved by dbt-databricks adapter
    # from profiles.yml / environment variables
    tables:
      - name: agents
        description: "Agent records from NICE CXone"
        columns:
          - name: agent_id
            description: "Unique agent identifier"
            data_tests:
              - unique
              - not_null
      - name: interactions
        description: "Customer interaction records"
        loaded_at_field: _dlt_load_id
        freshness:
          warn_after: {count: 24, period: hour}
          error_after: {count: 48, period: hour}
```

## Test Patterns

### Schema Tests (in YAML)

```yaml
# models/staging/nice/_stg_nice__models.yml
version: 2

models:
  - name: stg_nice__agents
    description: "Cleaned agent records from NICE CXone"
    columns:
      - name: agent_id
        description: "Primary key - unique agent identifier"
        data_tests:
          - unique
          - not_null
      - name: email
        data_tests:
          - not_null
      - name: is_active
        data_tests:
          - accepted_values:
              values: [true, false]
```

### Mart Model Tests

```yaml
models:
  - name: fct_daily_call_volume
    description: "Daily call volume aggregated by team and interaction type"
    columns:
      - name: daily_call_volume_id
        description: "Surrogate key: date + team_id + interaction_type"
        data_tests:
          - unique
          - not_null
      - name: team_id
        data_tests:
          - not_null
          - relationships:
              to: ref('dim_teams')
              field: team_id
    data_tests:
      - dbt_utils.expression_is_true:
          expression: "call_count >= 0"
```

### Unit Tests

Unit tests validate SQL logic on static mock data before materializing.
Use for complex transformations (window functions, case statements, date
math, regex).

```yaml
# models/marts/contact_center/_contact_center__models.yml
unit_tests:
  - name: test_interaction_duration_calculation
    description: >
      Verify duration_seconds is correctly computed as the difference
      between ended_at and started_at timestamps.
    model: fct_interactions
    given:
      - input: ref('stg_nice__interactions')
        rows:
          - {interaction_id: 1, started_at: "2024-01-01 10:00:00",
             ended_at: "2024-01-01 10:05:30", agent_id: 100,
             interaction_type: "voice"}
          - {interaction_id: 2, started_at: "2024-01-01 11:00:00",
             ended_at: "2024-01-01 11:00:45", agent_id: 100,
             interaction_type: "chat"}
    expect:
      rows:
        - {interaction_id: 1, duration_seconds: 330}
        - {interaction_id: 2, duration_seconds: 45}
```

**Unit test format choices:**

| Format | When to Use |
|--------|-------------|
| `dict` (default) | Most cases. Inline YAML, only include relevant columns. |
| `csv` | Fixture files with many rows. Store in `tests/fixtures/`. |
| `sql` | Models depending on ephemeral models, or complex data types. |

**Running unit tests:**

```bash
# Build + unit test + data test in DAG order
dbt build --select model_name

# Unit tests only
dbt test --select "model_name,test_type:unit"

# Specific unit test by name
dbt test --select test_interaction_duration_calculation

# Exclude unit tests from production (save compute)
dbt build --exclude-resource-type unit_test
```

### Custom Data Tests (SQL)

For complex assertions not expressible in YAML, create a SQL test file:

```sql
-- tests/assert_no_negative_durations.sql
select
    interaction_id,
    duration_seconds
from {{ ref('fct_interactions') }}
where duration_seconds < 0
```

A passing test returns zero rows.

## Jinja and ref()/source() Usage

### Always Use ref() and source()

```sql
-- CORRECT
select * from {{ ref('stg_nice__agents') }}
select * from {{ source('nice', 'agents') }}

-- WRONG: hardcoded table names
select * from prod_prep.stg_nice.agents
select * from dev_raw.nice.agents
```

### Common Jinja Patterns

**Surrogate keys:**

```sql
select
    {{ dbt_utils.generate_surrogate_key(['date_day', 'team_id', 'interaction_type']) }}
        as daily_call_volume_id,
    ...
```

**Conditional logic for incremental:**

```sql
{% if is_incremental() %}
where updated_at > (select max(updated_at) from {{ this }})
{% endif %}
```

**Environment-aware logic:**

```sql
{% if target.name == 'dev' %}
    -- Limit data in dev for faster iteration
    where created_at >= dateadd(day, -30, current_date())
{% endif %}
```

**Reusable macros:**

```sql
-- macros/cents_to_dollars.sql
{% macro cents_to_dollars(column_name) %}
    ({{ column_name }} / 100.0)
{% endmacro %}

-- Usage in model
select
    {{ cents_to_dollars('amount_cents') }} as amount_dollars
```

## dbt CLI Commands

### Essential Commands

```bash
# Build model + run tests (preferred over separate run/test)
dbt build --select model_name --quiet \
  --warn-error-options '{"error": ["NoNodesForSelectionCriteria"]}'

# Preview model output (iterate before committing)
dbt show --select model_name --limit 10

# Run inline SQL query against sources/models
dbt show --inline "select * from {{ ref('stg_nice__agents') }}" --limit 5

# Compile to see rendered SQL (no warehouse hit)
dbt compile --select model_name

# Parse project for YAML/config validation (fast, no warehouse)
dbt parse

# List models matching a selector
dbt list --select model_name+ --resource-type model
```

### Selector Patterns

```bash
--select model_name            # Single model
--select model_name+           # Model + all downstream
--select +model_name           # Model + all upstream
--select +model_name+          # Both directions
--select model_name+1          # Model + 1 level downstream
--select staging.*             # All models in staging path
--select tag:contact_center    # All models with tag
--select state:modified+       # Modified models + downstream
```

### Variables and Full Refresh

```bash
# Pass variables
dbt build --select model --vars '{"start_date": "2024-01-01"}'

# Full refresh for incremental models
dbt build --select model --full-refresh

# Defer to production artifacts (skip upstream rebuilds)
dbt build --select model --defer --state prod-artifacts
```

### Analyzing Run Results

```bash
# Check status of all models from last run
cat target/run_results.json | jq '.results[] | {node: .unique_id, status: .status}'

# Find failures
cat target/run_results.json | jq '.results[] | select(.status != "success")'
```

## Planning a New Model

Before writing SQL, follow this workflow:

1. **Mock the final output:** Create a markdown table with column names,
   sample data, grain, and primary key.

2. **Write pseudocode SQL:** Even if you do not know the source tables yet,
   sketch the transformations needed.

3. **Identify gaps:** What upstream models/sources are needed? Do they exist?

4. **Match with existing models:** In order of preference:
   - Exact match exists: use `ref()` directly
   - Partial match: extend the existing model
   - No match: create a new model (recurse the planning process)

5. **Write failing unit tests first:** Mock inputs from identified
   dependencies, define expected outputs. Tests should fail until the
   model is correctly implemented.

6. **Implement the model:** Build incrementally, validate with `dbt show`
   at each step.

## Data Discovery with dbt show

Before building models on unfamiliar sources, profile the data:

```bash
# Sample raw data
dbt show --inline "SELECT * FROM {{ source('source', 'table') }}" --limit 50

# Check grain (are IDs unique?)
dbt show --inline "
  SELECT id, COUNT(*) as cnt
  FROM {{ source('source', 'table') }}
  GROUP BY id HAVING COUNT(*) > 1
" --limit 10

# Profile nulls and cardinality
dbt show --inline "
  SELECT COUNT(*) as total, COUNT(col_a) as non_null_a
  FROM {{ source('source', 'table') }}
" --limit 1
```

Push `LIMIT` into CTEs early. Never add a trailing `LIMIT`; use `--limit`.

## Cost Management

- Always use `--select` to target specific models. Never run the full project.
- Use `--limit` with `dbt show` for data exploration.
- Use `--defer --state path/to/artifacts` to reuse production objects.
- Use `dbt clone` for zero-copy clones when testing.
- Prefer `view` materialization for staging models (no storage cost).
- Add `where` clauses to expensive tests on large tables.
- Exclude unit tests from production builds with `--exclude-resource-type unit_test`.

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Hardcoding catalog/table names | Use `ref()` and `source()` exclusively |
| Creating unnecessary models | Extend existing models when possible |
| Skipping data discovery | Always profile sources with `dbt show` first |
| Using `dbt test` after model changes | Use `dbt build` (test alone does not refresh the model) |
| Running without `--select` | Always specify what to run |
| Not reading existing model YAML | Read descriptions before modifying |
| Writing SQL without checking columns | Verify column names and types with `dbt show` |
| Testing built-in SQL functions | Only unit test complex custom logic |
| Mocking all columns in unit tests | Only include columns relevant to the test case |
