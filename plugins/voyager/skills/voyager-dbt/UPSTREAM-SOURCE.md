# Upstream Source Tracking

## dbt (dbt-labs)

- **Source:** https://github.com/dbt-labs/dbt-agent-skills
- **Version curated from:** dbt-agent-skills (latest as of 2026-03-17)
- **Date curated:** 2026-03-17

### Skills consumed

| Upstream Skill | Used In |
|----------------|---------|
| `using-dbt-for-analytics-engineering` | SKILL.md, references/dbt-patterns.md |
| `adding-dbt-unit-test` | references/dbt-patterns.md (unit test section) |
| `running-dbt-commands` | references/dbt-patterns.md (CLI commands section) |

### Reference files consumed

| Upstream Reference | Used In |
|-------------------|---------|
| `planning-dbt-models.md` | references/dbt-patterns.md (planning section) |
| `writing-data-tests.md` | references/dbt-patterns.md (test patterns section) |
| `debugging-dbt-errors.md` | SKILL.md (debugging approach) |
| `discovering-data.md` | references/dbt-patterns.md (data discovery section) |
| `evaluating-impact-of-a-dbt-model-change.md` | SKILL.md (evaluating impact approach) |

## What was changed during curation

- Added Voyager-specific conventions (Raw -> Prep -> Prod layers, Unity Catalog naming)
- Filtered for Databricks adapter patterns (merge strategy, liquid clustering, Delta format)
- Added staging/mart model templates following Voyager directory structure
- Removed content not relevant to Voyager's dbt usage:
  - Semantic layer / MetricFlow skills (not currently used)
  - dbt Cloud CLI / Fusion CLI flavors (Voyager uses dbt Core)
  - MCP server configuration skill
  - dbt docs fetching skill
  - Job troubleshooting skill (Dagster handles orchestration)
  - Migration skills (not applicable)
  - BigQuery, Snowflake, Redshift, Postgres warehouse-specific content
- Added dlt metadata column conventions (`_dlt_load_id`, `_dlt_id`)
- Added source freshness patterns tied to dlt ingestion
- Added Voyager-specific model scaffolding templates

## Next curation check

- [ ] Check dbt-labs/dbt-agent-skills for new skills or updated patterns
- [ ] Check dbt-databricks adapter for breaking changes
- [ ] Verify model patterns match current data-transformation repo conventions
- [ ] Check if Voyager adopts semantic layer (would need building-dbt-semantic-layer skill)
