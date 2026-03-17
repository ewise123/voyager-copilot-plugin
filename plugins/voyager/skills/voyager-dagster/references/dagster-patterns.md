# Dagster Patterns Reference

Curated from dagster-io/skills v0.0.12 (dagster-expert skill). Adapted for
Voyager platform conventions.

## Asset Patterns Summary

| Pattern                    | When to Use                                       |
| -------------------------- | ------------------------------------------------- |
| Basic `@dg.asset`          | Simple one-to-one transformation                  |
| `@multi_asset`             | Single operation produces multiple related assets |
| `@graph_asset`             | Multiple steps needed to produce one asset        |
| Parameter-based dependency | Asset depends on another managed asset            |
| `deps=` dependency         | Asset depends on external or non-Python asset     |
| Asset with metadata        | Track runtime metrics (row counts, timestamps)    |
| Asset groups               | Organize related assets visually                  |
| Partitioned assets         | Time-series or categorical data splits            |

---

## Basic Asset Definition

```python
import dagster as dg

@dg.asset
def my_asset() -> None:
    """Docstring becomes the asset description in the UI."""
    pass
```

- Function name becomes the asset key (use nouns: `customers`, not `load_customers`)
- Docstring becomes the description
- Return type annotation is recommended

## Asset Dependencies

### Parameter-Based (managed assets)

```python
@dg.asset
def upstream_asset() -> dict:
    return {"data": [1, 2, 3]}

@dg.asset
def downstream_asset(upstream_asset: dict) -> list:
    return upstream_asset["data"]
```

### External Dependencies with `deps=`

```python
@dg.asset(deps=["external_table", "raw_file"])
def processed_data() -> None:
    # Read from external sources directly
    pass
```

Use `deps=` when the upstream asset doesn't return a value, is external, or
you need loose coupling.

### Mixed Dependencies

```python
@dg.asset(deps=["raw_file"])
def enriched_data(reference_table: dict) -> dict:
    return {"enriched": reference_table}
```

---

## Asset Metadata

### Definition Metadata (Static)

```python
@dg.asset(
    description="Detailed description for the UI",
    group_name="analytics",
    key_prefix=["warehouse", "staging"],
    owners=["team:data-engineering"],
    tags={"priority": "high", "domain": "sales"},
    code_version="1.2.0",
)
def my_asset() -> None:
    pass
```

### Materialization Metadata (Dynamic)

```python
@dg.asset
def my_asset() -> dg.MaterializeResult:
    data = [...]
    return dg.MaterializeResult(
        metadata={
            "row_count": dg.MetadataValue.int(len(data)),
            "last_updated": dg.MetadataValue.text(str(datetime.now())),
        }
    )
```

MetadataValue types: `int`, `float`, `text`, `json`, `md`, `url`, `path`, `table`.

---

## Asset Groups and Key Prefixes

```python
@dg.asset(group_name="raw_data")
def raw_orders() -> None: ...

@dg.asset(key_prefix=["warehouse", "staging"])
def orders_cleaned() -> None:
    """Asset key becomes: warehouse/staging/orders_cleaned"""
```

Voyager convention: group by data layer (`raw`, `staging`, `analytics`, `mart`)
or by domain (`sales`, `marketing`, `finance`).

---

## Asset with Execution Context

```python
@dg.asset
def context_aware_asset(context: dg.AssetExecutionContext) -> None:
    context.log.info("Starting materialization")
    if context.has_partition_key:
        context.log.info(f"Partition: {context.partition_key}")
```

---

## Asset with Configuration

```python
class MyAssetConfig(dg.Config):
    limit: int = 100
    include_archived: bool = False
    source_path: str

@dg.asset
def configurable_asset(config: MyAssetConfig) -> None:
    data = load_data(path=config.source_path, limit=config.limit)
```

---

## Multi-Asset Pattern

```python
@dg.multi_asset(
    outs={
        "users": dg.AssetOut(),
        "orders": dg.AssetOut(),
    }
)
def load_data():
    yield dg.Output(fetch_users(), output_name="users")
    yield dg.Output(fetch_orders(), output_name="orders")
```

---

## Asset Factories

```python
def create_table_asset(table_name: str, schema: str):
    @dg.asset(name=f"{schema}_{table_name}", group_name=schema)
    def _asset() -> None:
        load_table(schema, table_name)
    return _asset

customers = create_table_asset("customers", "sales")
```

---

## Asset Selection Syntax

```python
# By name
dg.AssetSelection.assets("asset_a", "asset_b")

# By group
dg.AssetSelection.groups("analytics", "raw_data")

# By key prefix
dg.AssetSelection.key_prefixes(["warehouse", "staging"])

# By tag
dg.AssetSelection.tag("priority", "high")

# Dependency-based
dg.AssetSelection.assets("final_report").upstream()
dg.AssetSelection.assets("raw_data").downstream()

# Combining: union, intersection, difference
selection_a | selection_b
selection_a & selection_b
selection_a - selection_b
```

CLI asset selection:
```bash
dg launch --assets asset_a,asset_b
dg launch --assets "*"
```

---

## Jobs

```python
analytics_job = dg.define_asset_job(
    name="analytics_job",
    selection=dg.AssetSelection.groups("analytics").downstream(),
)
```

---

## Schedules

### Basic Schedule

```python
daily_job = dg.define_asset_job("daily_job", selection="*")

daily_schedule = dg.ScheduleDefinition(
    job=daily_job,
    cron_schedule="0 0 * * *",  # Midnight UTC
    execution_timezone="UTC",
    default_status=dg.DefaultScheduleStatus.RUNNING,
    description="Daily data refresh",
)
```

### From Partitioned Jobs

```python
@dg.asset(partitions_def=dg.DailyPartitionsDefinition(start_date="2024-01-01"))
def daily_asset(context: dg.AssetExecutionContext):
    partition_date = context.partition_key

partitioned_job = dg.define_asset_job("daily_job", selection=[daily_asset])
schedule = dg.build_schedule_from_partitioned_job(partitioned_job)
```

### Cron Reference

| Expression       | Description                 |
| ---------------- | --------------------------- |
| `0 * * * *`      | Every hour                  |
| `0 0 * * *`      | Daily at midnight           |
| `0 9 * * *`      | Daily at 9 AM               |
| `0 0 * * 1`      | Weekly on Monday            |
| `0 0 1 * *`      | Monthly on the 1st          |
| `*/15 * * * *`   | Every 15 minutes            |
| `0 9-17 * * 1-5` | Hourly, 9 AM-5 PM, weekdays |

---

## Sensors

### Basic Sensor

```python
@dg.sensor(job=my_job, minimum_interval_seconds=30)
def file_sensor(context: dg.SensorEvaluationContext):
    processed = json.loads(context.cursor) if context.cursor else {}
    runs = []
    for f in os.listdir("/data/incoming"):
        mtime = os.path.getmtime(f"/data/incoming/{f}")
        if f not in processed or processed[f] != mtime:
            runs.append(dg.RunRequest(run_key=f"{f}_{mtime}"))
            processed[f] = mtime
    return dg.SensorResult(run_requests=runs, cursor=json.dumps(processed))
```

### Asset Sensor

```python
@dg.asset_sensor(asset_key=dg.AssetKey("daily_sales"), job=downstream_job)
def sales_sensor(context: dg.SensorEvaluationContext, asset_event):
    yield dg.RunRequest(run_key=context.cursor)
```

### Run Status Sensor

Reacts to run success, failure, or other status changes. Useful for
notifications or cleanup actions.

### Sensor Best Practices

- Use JSON for cursor state with `json.dumps()` / `json.loads()`
- Always handle `context.cursor is None` (first evaluation)
- Keep cursors small (stored in database)
- Set `default_status=dg.DefaultSensorStatus.RUNNING` for auto-enable

---

## Choosing Automation

- Simple fixed time-based execution: **Schedules**
- Custom polling logic: **Basic Sensors**
- React to asset materialization: **Asset Sensors**
- React to run success/failure: **Run Status Sensors**
- Partition-aware, asset-graph-aware: **Declarative Automation**

### Declarative Automation

Set conditions directly on assets for asset-centric workflows:

```python
@dg.asset(automation_condition=dg.AutomationCondition.eager())
def auto_asset() -> None:
    pass
```

---

## Resources and Environment Variables

### Configurable Resource with EnvVar

```python
class DatabaseResource(dg.ConfigurableResource):
    connection_string: str = dg.EnvVar("DATABASE_URL")
    timeout: int = dg.EnvVar.int("DB_TIMEOUT")
```

### .env Files

The `dg` CLI automatically loads `.env` files from the project root.
Never commit `.env` files. Use `.env.example` as a template.

```bash
# List all EnvVar references in the project
dg list envs
```

Voyager convention: all secrets come from Azure Key Vault via environment
variables. In local dev, use `.env` (gitignored).

---

## Common Anti-Patterns

| Anti-Pattern                       | Better Approach                                |
| ---------------------------------- | ---------------------------------------------- |
| `load_customers` (verb name)       | `customers` (noun describing output)           |
| Giant asset doing everything       | Split into focused, composable assets          |
| No type annotations                | Add return type: `-> dict`, `-> None`          |
| No docstring                       | Add description in docstring or `description=` |
| Ignoring `MaterializeResult`       | Return metadata for observability              |
| Hardcoded paths or credentials     | Use configuration or EnvVar                    |
