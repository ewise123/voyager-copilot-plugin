# Terragrunt Patterns for Voyager

Reference material for Terragrunt configuration patterns used in Voyager
infrastructure repositories. Curated from upstream Terragrunt skill and
HashiCorp agent skills, adapted for Azure + OpenTofu.

---

## Directory Structure

Voyager infrastructure repos follow a three-tier structure:

```
infra-repo/
├── terragrunt.hcl              # Root config: remote state, provider generation
├── env.hcl                     # Environment-level locals (subscription, region)
├── stacks/                     # Stack definitions (compose units)
│   ├── networking/
│   │   └── terragrunt.stack.hcl
│   ├── data-platform/
│   │   └── terragrunt.stack.hcl
│   └── services/
│       └── terragrunt.stack.hcl
├── units/                      # Individual Terragrunt units
│   ├── resource-group/
│   │   └── terragrunt.hcl
│   ├── vnet/
│   │   └── terragrunt.hcl
│   ├── aks/
│   │   └── terragrunt.hcl
│   ├── keyvault/
│   │   └── terragrunt.hcl
│   ├── storage-account/
│   │   └── terragrunt.hcl
│   └── databricks-workspace/
│       └── terragrunt.hcl
└── catalog/                    # References to dp-service-catalog modules
    └── README.md
```

### Three Repository Types

1. **Infrastructure Catalog (dp-service-catalog):** Units and stacks
   referencing external OpenTofu modules. This is the internal module
   registry for Voyager.
2. **Infrastructure Live:** Environment-specific deployments using the
   catalog. Each environment (dev, staging, prod) has its own directory
   or branch configuration.
3. **Module Repos:** Individual repositories per OpenTofu module with
   independent versioning and testing.

---

## Root terragrunt.hcl

The root configuration defines shared settings inherited by all units:

```hcl
# Root terragrunt.hcl

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  env      = local.env_vars.locals.environment
  region   = local.env_vars.locals.region
  sub_id   = local.env_vars.locals.subscription_id
}

# Remote state in Azure Storage Account
remote_state {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-${local.env}-tfstate"
    storage_account_name = "st${local.env}tfstate"
    container_name       = "tfstate"
    key                  = "${path_relative_to_include()}/terraform.tfstate"
    subscription_id      = local.sub_id
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# Generate provider configuration
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "azurerm" {
      features {}
      subscription_id = "${local.sub_id}"
    }
  EOF
}

# Generate OpenTofu version constraints
generate "versions" {
  path      = "versions.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      required_version = ">= 1.9.0"
      required_providers {
        azurerm = {
          source  = "hashicorp/azurerm"
          version = "~> 4.0"
        }
      }
    }
  EOF
}
```

---

## Environment Configuration (env.hcl)

Each environment defines its specific values:

```hcl
# env.hcl
locals {
  environment     = "dev"
  region          = "westeurope"
  subscription_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  resource_prefix = "voyager-dev"
  tags = {
    Environment = "dev"
    Platform    = "Voyager"
    ManagedBy   = "Terragrunt/OpenTofu"
  }
}
```

---

## Unit Configuration

A unit wraps a single OpenTofu module with Terragrunt configuration:

```hcl
# units/vnet/terragrunt.hcl

include "root" {
  path = find_in_parent_folders("terragrunt.hcl")
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  env      = local.env_vars.locals.environment
  prefix   = local.env_vars.locals.resource_prefix
  tags     = local.env_vars.locals.tags
}

# Module source from dp-service-catalog
terraform {
  source = "git::https://dev.azure.com/org/project/_git/dp-service-catalog//modules/vnet?ref=v1.2.0"
}

# Dependencies on other units
dependency "resource_group" {
  config_path = "../resource-group"

  mock_outputs = {
    resource_group_name = "mock-rg-name"
    location            = "westeurope"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

# Inputs passed to the OpenTofu module
inputs = {
  name                = "${local.prefix}-vnet"
  resource_group_name = dependency.resource_group.outputs.resource_group_name
  location            = dependency.resource_group.outputs.location
  address_space       = ["10.0.0.0/16"]

  subnets = {
    aks = {
      address_prefixes = ["10.0.1.0/24"]
    }
    data = {
      address_prefixes = ["10.0.2.0/24"]
    }
    services = {
      address_prefixes = ["10.0.3.0/24"]
    }
  }

  tags = local.tags
}
```

---

## Stack Configuration

Stacks compose multiple units into a deployable group:

```hcl
# stacks/networking/terragrunt.stack.hcl

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  env      = local.env_vars.locals.environment
}

unit "resource_group" {
  source = "../../units/resource-group"
  values = {
    version = "v1.0.0"
  }
}

unit "vnet" {
  source = "../../units/vnet"
  values = {
    version = "v1.2.0"
  }
}

unit "nsg" {
  source = "../../units/nsg"
  values = {
    version = "v1.1.0"
  }
}
```

---

## Module Sourcing and Versioning

### Source URL Format

Modules in dp-service-catalog are referenced via Git URL:

```hcl
terraform {
  # Correct: path before ref
  source = "git::https://dev.azure.com/org/project/_git/dp-service-catalog//modules/vnet?ref=v1.2.0"
}
```

**Common mistake:** placing `?ref=` before the `//` path separator:
```hcl
# WRONG: ref before path
source = "git::https://dev.azure.com/org/project/_git/dp-service-catalog?ref=v1.2.0//modules/vnet"
```

### Version Strategy

| Environment | Strategy         | Example              |
|-------------|-----------------|----------------------|
| Development | Branch reference | `?ref=feature/xyz`   |
| Testing     | RC tags          | `?ref=v1.2.0-rc1`   |
| Production  | Stable tags      | `?ref=v1.2.0`       |

### Values-Based Versioning

Units can receive version from stack values:

```hcl
# In the unit
terraform {
  source = "git::https://dev.azure.com/org/project/_git/dp-service-catalog//modules/vnet?ref=${values.version}"
}
```

---

## Dependency Management

### Declaring Dependencies

```hcl
dependency "keyvault" {
  config_path = "../keyvault"

  mock_outputs = {
    key_vault_id   = "/subscriptions/xxx/resourceGroups/xxx/providers/Microsoft.KeyVault/vaults/mock"
    key_vault_name = "mock-kv"
    key_vault_uri  = "https://mock-kv.vault.azure.net/"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}
```

### Reference Resolution Pattern

For units that resolve symbolic references to dependency outputs:

```hcl
locals {
  # If input is a relative path like "../keyvault", resolve to dependency output
  # Otherwise use the literal value
  resolved_keyvault_id = (
    local.keyvault_ref == "../keyvault"
    ? dependency.keyvault.outputs.key_vault_id
    : local.keyvault_ref
  )
}
```

### Mock Outputs

Every dependency must define mock outputs for isolated validation:

```hcl
mock_outputs = {
  resource_group_name = "mock-rg"
  location            = "westeurope"
  id                  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg"
}
mock_outputs_allowed_terraform_commands = ["validate", "plan"]
```

**Why:** Terragrunt needs outputs from dependencies even when running
`plan` on a single unit. Without mocks, you must apply dependencies first.

---

## Remote State Configuration for Azure

### Storage Account Backend

```hcl
remote_state {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-${local.env}-tfstate"
    storage_account_name = "st${local.env}tfstate"
    container_name       = "tfstate"
    key                  = "${path_relative_to_include()}/terraform.tfstate"
    subscription_id      = local.sub_id
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}
```

### State Isolation

Each unit gets its own state file keyed by its relative path:
- `units/resource-group/terraform.tfstate`
- `units/vnet/terraform.tfstate`
- `units/aks/terraform.tfstate`

This ensures units can be planned and applied independently without
locking other units' state files.

---

## Environment-Specific Overrides

### Pattern: Layered Configuration

```
environments/
├── dev/
│   ├── env.hcl
│   └── terragrunt.hcl -> ../../terragrunt.hcl (symlink or include)
├── staging/
│   ├── env.hcl
│   └── terragrunt.hcl
└── prod/
    ├── env.hcl
    └── terragrunt.hcl
```

Each `env.hcl` provides environment-specific values that units consume
via `read_terragrunt_config(find_in_parent_folders("env.hcl"))`.

### Pattern: Conditional Resources

Use `try()` with feature detection in units:

```hcl
locals {
  enable_diagnostics = try(local.env_vars.locals.enable_diagnostics, false)
}

inputs = {
  enable_diagnostics = local.enable_diagnostics
  diagnostic_settings = local.enable_diagnostics ? {
    log_analytics_workspace_id = dependency.log_analytics.outputs.workspace_id
  } : {}
}
```

---

## Common Pitfalls

### 1. Git Refspec Syntax

```hcl
# CORRECT: //path?ref=version
source = "git::https://example.com/repo//modules/vnet?ref=v1.0.0"

# WRONG: ?ref=version//path
source = "git::https://example.com/repo?ref=v1.0.0//modules/vnet"
```

### 2. Heredoc in Ternary Operators

Heredocs inside ternary expressions require parenthesis wrapping:

```hcl
# CORRECT
content = var.custom ? (<<-EOF
  custom content
EOF
) : "default"
```

### 3. Missing Mock Outputs

Without mock outputs, running `terragrunt plan` on a unit with
unapplied dependencies will fail. Always define mock outputs.

### 4. Local Paths in Source

Never use local filesystem paths for module sources in production.
Always use versioned Git URLs from dp-service-catalog.

### 5. Forgetting to Run init After Source Change

After changing a module source URL or version, run `terragrunt init`
before `terragrunt plan`. Terragrunt does not auto-detect source changes.

---

## Terragrunt Commands Reference

| Command                        | Purpose                                    |
|-------------------------------|--------------------------------------------|
| `terragrunt init`             | Initialize module and providers            |
| `terragrunt validate`         | Syntax and configuration validation        |
| `terragrunt plan`             | Preview changes for a single unit          |
| `terragrunt apply`            | Apply changes for a single unit            |
| `terragrunt run-all plan`     | Plan all units in dependency order         |
| `terragrunt run-all apply`    | Apply all units in dependency order        |
| `terragrunt output`           | Show outputs of an applied unit            |
| `terragrunt graph-dependencies` | Visualize unit dependency graph          |
