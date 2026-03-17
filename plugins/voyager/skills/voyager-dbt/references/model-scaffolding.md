# Model Scaffolding Templates

Ready-to-use templates for creating dbt models in the Voyager platform.
All templates follow Raw -> Prep -> Prod datalake layering with
Databricks Unity Catalog conventions.

## Directory Layout

```
data-transformation/
├── dbt_project.yml
├── profiles.yml                      # Databricks connection (env vars)
├── packages.yml                      # dbt packages (dbt_utils, etc.)
├── macros/
│   └── {shared_macros}.sql
├── models/
│   ├── staging/
│   │   └── {source_name}/
│   │       ├── _stg_{source}__sources.yml
│   │       ├── _stg_{source}__models.yml
│   │       └── stg_{source}__{entity}.sql
│   ├── intermediate/
│   │   └── {domain}/
│   │       ├── _int_{domain}__models.yml
│   │       └── int_{description}.sql
│   └── marts/
│       └── {domain}/
│           ├── _{domain}__models.yml
│           ├── fct_{entity}.sql
│           └── dim_{entity}.sql
├── seeds/
│   └── {reference_data}.csv
├── tests/
│   ├── fixtures/                     # Unit test fixture files
│   └── {custom_data_tests}.sql
└── target/                           # Build artifacts (gitignored)
```

## dbt_project.yml Structure

```yaml
name: data_transformation
version: '1.0.0'

profile: databricks

model-paths: ["models"]
test-paths: ["tests"]
seed-paths: ["seeds"]
macro-paths: ["macros"]
target-path: "target"
clean-targets: ["target", "dbt_packages"]

models:
  data_transformation:
    staging:
      +materialized: view
      +schema: "prep_staging"
    intermediate:
      +materialized: view
      +schema: "prep_intermediate"
    marts:
      +materialized: table
      +schema: "prod"

vars:
  # Environment-aware variables
  # Catalogs are resolved from profiles.yml / env vars, not hardcoded here
  dbt_utils_dispatch_list: [spark_utils]
```

## Staging Model Template

Staging models live in the Prep layer and read from Raw (dlt-ingested)
sources. They perform 1:1 transformations: renaming, casting, cleaning.

### SQL File

```sql
-- models/staging/{source}/stg_{source}__{entity}.sql

{{ config(materialized='view') }}

with source as (

    select * from {{ source('{source_name}', '{table_name}') }}

),

renamed as (

    select
        -- Primary key
        cast({raw_id_column} as string) as {entity}_id,

        -- Foreign keys
        cast({raw_fk_column} as string) as {related_entity}_id,

        -- Attributes
        cast({raw_name_column} as string) as {entity}_name,
        cast({raw_status_column} as string) as status,

        -- Dates and timestamps
        cast({raw_created_column} as timestamp) as created_at,
        cast({raw_updated_column} as timestamp) as updated_at,

        -- Booleans
        cast({raw_active_column} as boolean) as is_active,

        -- dlt metadata (keep for lineage)
        _dlt_load_id,
        _dlt_id

    from source

)

select * from renamed
```

### Source YAML

```yaml
# models/staging/{source}/_stg_{source}__sources.yml

version: 2

sources:
  - name: {source_name}
    description: "Data ingested by dlt from {api_name} API"
    schema: "raw_{source_name}"
    # Catalog resolved from environment - never hardcode
    tables:
      - name: {table_name}
        description: "{Entity} records from {api_name}"
        columns:
          - name: {raw_id_column}
            description: "Primary key in source system"
        loaded_at_field: _dlt_load_id
        freshness:
          warn_after: {count: 24, period: hour}
          error_after: {count: 48, period: hour}

      - name: {another_table}
        description: "{Another entity} records from {api_name}"
```

### Schema YAML

```yaml
# models/staging/{source}/_stg_{source}__models.yml

version: 2

models:
  - name: stg_{source}__{entity}
    description: >
      Cleaned and renamed {entity} records from the {source_name} source.
      One row per {entity}. Materialized as a view in the Prep layer.
    columns:
      - name: {entity}_id
        description: "Primary key - unique {entity} identifier"
        data_tests:
          - unique
          - not_null

      - name: {related_entity}_id
        description: "Foreign key to {related_entity}"
        data_tests:
          - not_null
          - relationships:
              to: ref('stg_{source}__{related_entity}')
              field: {related_entity}_id

      - name: status
        description: "Current status of the {entity}"
        data_tests:
          - accepted_values:
              values: ['active', 'inactive', 'pending']

      - name: created_at
        description: "Timestamp when the {entity} was created in the source system"

      - name: is_active
        description: "Whether the {entity} is currently active"
```

## Intermediate Model Template

Intermediate models live in the Prep layer. They join, reshape, or
aggregate staging models to prepare data for mart consumption.

### SQL File

```sql
-- models/intermediate/{domain}/int_{description}.sql

{{ config(materialized='view') }}

with {entity_a} as (

    select * from {{ ref('stg_{source}__{entity_a}') }}

),

{entity_b} as (

    select * from {{ ref('stg_{source}__{entity_b}') }}

),

joined as (

    select
        {entity_a}.{entity_a}_id,
        {entity_a}.{attribute},
        {entity_b}.{attribute},
        {entity_a}.created_at
    from {entity_a}
    left join {entity_b}
        on {entity_a}.{fk_column} = {entity_b}.{pk_column}

)

select * from joined
```

### Schema YAML

```yaml
# models/intermediate/{domain}/_int_{domain}__models.yml
version: 2

models:
  - name: int_{description}
    description: "{Entity A} joined with {Entity B}. One row per {grain}."
    columns:
      - name: {entity_a}_id
        description: "Primary key"
        data_tests:
          - unique
          - not_null
```

## Mart Model Template - Dimension

Dimension models live in the Prod layer. They describe business entities
(who, what, where) and are typically `table` materialized.

### SQL File

```sql
-- models/marts/{domain}/dim_{entity}.sql

{{ config(materialized='table') }}

with {entity} as (

    select * from {{ ref('stg_{source}__{entity}') }}

),

{enrichment} as (

    select * from {{ ref('int_{enrichment_description}') }}

),

final as (

    select
        -- Primary key
        {entity}.{entity}_id,

        -- Descriptive attributes
        {entity}.{entity}_name,
        {entity}.{attribute_1},
        {entity}.{attribute_2},

        -- Enriched attributes from joins
        {enrichment}.{enriched_attribute},

        -- Status and flags
        {entity}.is_active,

        -- Timestamps
        {entity}.created_at,
        {entity}.updated_at

    from {entity}
    left join {enrichment}
        on {entity}.{entity}_id = {enrichment}.{entity}_id

)

select * from final
```

## Mart Model Template - Fact (Table)

Fact models live in the Prod layer. They capture events or transactions
(what happened, when, how much) and are `table` or `incremental`.

### SQL File

```sql
-- models/marts/{domain}/fct_{entity}.sql

{{ config(materialized='table') }}

with {events} as (

    select * from {{ ref('stg_{source}__{events}') }}

),

{dimension} as (

    select * from {{ ref('dim_{dimension}') }}

),

final as (

    select
        -- Surrogate key
        {{ dbt_utils.generate_surrogate_key(['{natural_key_1}', '{natural_key_2}']) }}
            as {entity}_id,

        -- Foreign keys
        {events}.{dimension}_id,

        -- Degenerate dimensions
        {events}.{event_type},

        -- Measures
        {events}.{quantity},
        {events}.{amount},

        -- Timestamps
        {events}.{event_at},
        {events}.created_at

    from {events}
    left join {dimension}
        on {events}.{dimension}_id = {dimension}.{dimension}_id

)

select * from final
```

## Mart Model Template - Fact (Incremental)

For large fact tables where full rebuilds are too expensive.

### SQL File

```sql
-- models/marts/{domain}/fct_{entity}.sql

{{ config(
    materialized='incremental',
    unique_key='{entity}_id',
    incremental_strategy='merge',
    on_schema_change='append_new_columns'
) }}

with {events} as (

    select * from {{ ref('stg_{source}__{events}') }}

    {% if is_incremental() %}
    where updated_at > (select max(updated_at) from {{ this }})
    {% endif %}

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['{key_1}', '{key_2}']) }}
            as {entity}_id,
        {events}.*
    from {events}

)

select * from final
```

### Schema YAML for Mart Models

```yaml
# models/marts/{domain}/_{domain}__models.yml

version: 2

models:
  - name: fct_{entity}
    description: >
      {Description of what this fact table captures}. One row per
      {grain description}. Materialized in the Prod layer.
    columns:
      - name: {entity}_id
        description: "Surrogate primary key"
        data_tests:
          - unique
          - not_null

      - name: {dimension}_id
        description: "Foreign key to dim_{dimension}"
        data_tests:
          - not_null
          - relationships:
              to: ref('dim_{dimension}')
              field: {dimension}_id

      - name: {measure}
        description: "{Business meaning of this measure}"
        data_tests:
          - not_null

    data_tests:
      - dbt_utils.expression_is_true:
          expression: "{measure} >= 0"

  - name: dim_{entity}
    description: >
      {Description of what this dimension represents}. One row per
      {entity}. Materialized in the Prod layer.
    columns:
      - name: {entity}_id
        description: "Primary key"
        data_tests:
          - unique
          - not_null
```

## Unit Test Template

```yaml
# Add to the relevant __{domain}__models.yml file

unit_tests:
  - name: test_{model_name}_{scenario_description}
    description: >
      Scenario: {human readable scenario}
        When the {model_name} model is built
        Given {precondition description}
        Then {expected outcome}

    model: {model_name}

    given:
      - input: ref('{upstream_model_1}')
        rows:
          - {col_a: value_1, col_b: value_2}
          - {col_a: value_3, col_b: value_4}
      - input: ref('{upstream_model_2}')
        rows:
          - {col_x: value_5}

    expect:
      rows:
        - {expected_col_a: expected_value_1, expected_col_b: expected_value_2}
```

## Seed Template

Seeds are CSV files for small, static reference data. Not for large datasets.
Place in `seeds/` directory. Configure column types in `dbt_project.yml`.

## Custom Macro Template

```sql
-- macros/{macro_name}.sql
{% macro {macro_name}({param_1}, {param_2}) %}
    {{ return(param_1 ~ ' / ' ~ param_2) }}
{% endmacro %}
```

## Checklist: New Model

Before submitting a PR for a new model:

- [ ] SQL file follows naming convention (`stg_`, `int_`, `fct_`, `dim_`)
- [ ] Uses `ref()` and `source()` exclusively (no hardcoded table names)
- [ ] Uses CTEs, not subqueries
- [ ] Schema YAML with description for model and all columns
- [ ] `unique` + `not_null` tests on primary key
- [ ] `relationships` tests on foreign keys
- [ ] `accepted_values` on enum columns (if values confirmed)
- [ ] Unit tests for complex SQL logic
- [ ] Validated output with `dbt show`
- [ ] `dbt build --select model_name` passes
- [ ] No catalog names hardcoded anywhere
- [ ] Materialization appropriate for layer (view for staging, table/incremental for marts)
