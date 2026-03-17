# Upstream Source Tracking

## HashiCorp Agent Skills (Terraform)

- **Source:** https://github.com/hashicorp/agent-skills
- **Skills used:**
  - `terraform/code-generation/skills/terraform-style-guide/SKILL.md`
  - `terraform/code-generation/skills/terraform-test/SKILL.md`
  - `terraform/code-generation/skills/azure-verified-modules/SKILL.md`
  - `terraform/module-generation/skills/refactor-module/SKILL.md`
- **Date fetched:** 2026-03-17
- **License:** MPL-2.0

## Anton Babenko Terraform Skill

- **Source:** https://github.com/antonbabenko/terraform-skill
- **Skill used:** `SKILL.md` (v1.6.0)
- **Date fetched:** 2026-03-17
- **License:** Apache-2.0

## Terragrunt Skill (jfr992)

- **Source:** https://github.com/jfr992/terragrunt-skill
- **Skill used:** `SKILL.md`
- **Date fetched:** 2026-03-17
- **License:** Not specified

## What was changed during curation

- Replaced all AWS references with Azure equivalents (azurerm, Azure Storage, AKS, Key Vault)
- Removed multi-cloud patterns; Voyager is Azure-only
- Replaced Terraform CLI references with Terragrunt commands (OpenTofu backend)
- Added dp-service-catalog as the module registry pattern
- Added Voyager directory conventions (stacks/, units/, catalog/)
- Added Voyager naming conventions for Azure resources
- Added Azure Storage Account remote state backend (replacing S3)
- Added mock_outputs patterns required for Terragrunt dependency isolation
- Removed Terraform Cloud / HCP references
- Added env.hcl configuration hierarchy pattern
- Added Voyager-specific tagging requirements
- Added Databricks workspace patterns for data platform lane

## Next curation check

- [ ] Check hashicorp/agent-skills for updates to Azure Verified Module requirements
- [ ] Check antonbabenko/terraform-skill for new version (currently v1.6.0)
- [ ] Check jfr992/terragrunt-skill for updates to stack/unit patterns
- [ ] Verify azurerm provider 4.x compatibility with latest OpenTofu release
- [ ] Check if Terragrunt 0.68.x introduces breaking changes to stack config
- [ ] Review dp-service-catalog module versions against tracked versions
