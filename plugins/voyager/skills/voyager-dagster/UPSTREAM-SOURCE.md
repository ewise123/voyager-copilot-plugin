# Upstream Source Tracking

## Dagster

- **Library source:** https://github.com/dagster-io/dagster
- **Skill source:** https://github.com/dagster-io/skills
  - Skill: `skills/dagster-expert/skills/dagster-expert/`
  - SKILL.md: asset definitions, automation, components, integrations, dg CLI
  - References: assets, automation (schedules, sensors, declarative), CLI
    (scaffold, launch, check, dev, list, plus/deploy), components, integrations
    (dagster-dbt, dagster-dlt, 40+ others), environment variables
- **Upstream version:** v0.0.12 (released 2026-03-12)
- **License:** Apache 2.0
- **Date curated:** 2026-03-17
- **Curated by:** Voyager platform team

## What was curated from upstream

### From dagster-expert SKILL.md
- Core concepts: assets, components, integration workflow, dg CLI usage
- UV compatibility patterns
- Reference index structure

### From references/assets.md
- Asset definition patterns (basic, multi-asset, graph_asset, factories)
- Asset dependencies (parameter-based, deps=, mixed)
- Asset metadata (definition and materialization)
- Asset groups, key prefixes, configuration, execution context
- Asset selection syntax (programmatic and CLI)
- Common anti-patterns

### From references/automation/
- Choosing automation approach decision tree (schedules vs sensors vs declarative)
- Schedule patterns (basic, partitioned, cron reference, timezone)
- Sensor patterns (basic with cursor, file watching, asset sensors, run status)
- Declarative automation (AutomationCondition)

### From references/cli/
- dg scaffold defs (assets, schedules, sensors, components)
- dg launch (assets, partitions, configuration)
- dg check (defs, yaml, toml)
- dg dev (local development server)
- dg list defs, dg list envs, dg list components
- create-dagster (project and workspace scaffolding)

### From references/cli/plus/
- dg plus login, config, deploy configure, deploy
- dg plus pull env, create ci-api-token
- dg plus integrations dbt manage-manifest

### From references/integrations/dagster-dbt/
- Pythonic integration (@dbt_assets decorator, DbtCliResource, DbtProject)
- DagsterDbtTranslator customization
- Incremental models and partitioning
- Metadata fetching (row counts, column metadata)
- Scheduling dbt assets
- Dependencies (ref, source, Jinja comments)
- Referencing dbt models in other assets

### From references/integrations/dagster-dlt/
- dagster-dlt integration overview

### From references/env-vars.md
- EnvVar resource configuration
- .env file patterns
- Environment-specific configuration

## What was changed during curation

- Focused deployment target on Dagster Cloud (Plus) only, removed OSS self-hosted
- Added Voyager deploy.yaml chain and ADO pipeline constraints
- Added branch deployment conventions
- Added dlt-Dagster bridge (asset_utils.py) integration patterns
- Added dbt-Dagster bridge patterns specific to Voyager (Raw->Prep->Prod lineage)
- Added Azure Key Vault environment variable convention
- Added uv as the required command runner
- Added Voyager asset naming conventions (noun-based)
- Removed references to self-hosted deployment (Docker, K8s, Helm for Dagster)
- Removed detailed component creation docs (kept summary relevant to Voyager)
- Condensed 30+ upstream reference files into 2 focused reference files
- Removed integration references for tools not used by Voyager

## Next curation check

- [ ] Check dagster-io/skills for new releases beyond v0.0.12
- [ ] Check for new dg CLI commands or changed syntax
- [ ] Check dagster-dbt integration for breaking changes
- [ ] Check dagster-dlt integration updates
- [ ] Check Dagster Plus deployment API changes
- [ ] Check component framework changes
- [ ] Verify dagster version pinned in voyager-data-platform-repo pyproject.toml
