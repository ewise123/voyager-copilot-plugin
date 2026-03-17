# Upstream Source Tracking

## ODCS Data Product Expert

- **Source:** Tech lead's ODCS agent (internal)
- **Standard:** Open Data Contract Standard (ODCS) by Bitol
- **Date curated:** 2026-03-17

## What was changed during curation

- Converted from agent format (.agent.md) to skill format (SKILL.md)
- Added Voyager Platform Context preamble
- Added Voyager-specific constraints (Prod layer as contract surface,
  Databricks Unity Catalog, dbt tests for enforcement)
- Mapped ODCS concepts to Voyager implementation (dbt models, Dagster assets,
  dlt sources)
- Removed tool permissions (read, search, edit, execute, todo) — skills don't
  specify tools

## Next curation check

- [ ] Check ODCS spec for new version releases
- [ ] Review if contract patterns have evolved in working repos
- [ ] Verify dbt test patterns match current contract enforcement approach
