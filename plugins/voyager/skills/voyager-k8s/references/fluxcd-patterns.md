# FluxCD Patterns Reference

## Architecture Overview

FluxCD is a GitOps toolkit that keeps Kubernetes clusters in sync with
configuration sources (Git repos, Helm repos, OCI registries). It consists
of specialized controllers that each handle a specific reconciliation domain.

### Controllers

- **Source Controller:** Watches GitRepository, HelmRepository, OCIRepository,
  and Bucket sources. Fetches artifacts and produces versioned snapshots.
- **Helm Controller:** Reconciles HelmRelease resources. Installs, upgrades,
  and rolls back Helm charts to match the declared desired state.
- **Kustomize Controller:** Reconciles Kustomization resources from Git or
  OCI sources. Applies Kubernetes manifests with optional Kustomize overlays.
- **Notification Controller:** Sends alerts to external systems (Slack, Teams,
  webhooks) and receives incoming webhooks to trigger reconciliation.
- **Image Automation Controllers:** Scans container registries for new tags
  and updates Git sources automatically (ImagePolicy, ImageUpdateAutomation).

### Reconciliation Model

FluxCD continuously reconciles desired state (in Git) with actual state
(in the cluster). Each resource has a configurable `interval` that determines
how often the controller checks for drift. When drift is detected, the
controller applies the desired state automatically.

## Source Resources

### GitRepository

Defines a Git repository as a source of Kubernetes manifests or Helm charts.

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: voyager-services
  namespace: flux-system
spec:
  interval: 5m
  url: https://dev.azure.com/org/project/_git/voyager-services
  ref:
    branch: main
  secretRef:
    name: git-credentials
```

### HelmRepository

Defines a Helm chart repository as a source.

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: voyager-charts
  namespace: flux-system
spec:
  interval: 10m
  url: https://myregistry.azurecr.io/helm/v1/repo
  type: oci
  secretRef:
    name: helm-registry-credentials
```

### OCIRepository

Defines an OCI-compliant registry as a source (alternative to Git).

```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: OCIRepository
metadata:
  name: my-service-manifests
  namespace: flux-system
spec:
  interval: 5m
  url: oci://myregistry.azurecr.io/manifests/my-service
  ref:
    tag: latest
```

## HelmRelease

The core resource for deploying Helm charts via FluxCD. Declares which
chart to install, what values to use, and how to handle upgrades and
rollbacks.

### Basic HelmRelease

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: my-service
  namespace: my-service
spec:
  interval: 5m
  chart:
    spec:
      chart: my-service
      version: "1.2.x"          # SemVer range for auto-upgrades
      sourceRef:
        kind: HelmRepository
        name: voyager-charts
        namespace: flux-system
  values:
    replicaCount: 2
    image:
      repository: myregistry.azurecr.io/my-service
      tag: "1.2.3"
```

### HelmRelease with Values From External Sources

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: my-service
  namespace: my-service
spec:
  interval: 5m
  chart:
    spec:
      chart: my-service
      version: "1.2.x"
      sourceRef:
        kind: HelmRepository
        name: voyager-charts
        namespace: flux-system
  valuesFrom:
    - kind: ConfigMap
      name: my-service-values
      valuesKey: values.yaml
    - kind: Secret
      name: my-service-secrets
      valuesKey: secret-values.yaml
  values:
    # Inline values override valuesFrom
    replicaCount: 3
```

### HelmRelease with Chart from Git

When the Helm chart lives in the same Git repository:

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: my-service
  namespace: my-service
spec:
  interval: 5m
  chart:
    spec:
      chart: ./charts/my-service
      sourceRef:
        kind: GitRepository
        name: voyager-services
        namespace: flux-system
```

### Upgrade and Rollback Configuration

```yaml
spec:
  install:
    createNamespace: true
    remediation:
      retries: 3
  upgrade:
    cleanupOnFail: true
    remediation:
      retries: 3
      strategy: rollback       # Automatically rollback on failure
  rollback:
    timeout: 5m
    cleanupOnFail: true
  uninstall:
    keepHistory: false
  timeout: 10m
```

### Health Checks and Readiness

```yaml
spec:
  # Wait for these resources to become ready after install/upgrade
  healthChecks:
    - apiVersion: apps/v1
      kind: Deployment
      name: my-service
      namespace: my-service
  # Suspend reconciliation (useful during maintenance)
  suspend: false
```

## Kustomization

Applies Kubernetes manifests from a source with optional Kustomize overlays.
Used for non-Helm resources or for organizing FluxCD configuration itself.

### Basic Kustomization

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: my-service-config
  namespace: flux-system
spec:
  interval: 10m
  sourceRef:
    kind: GitRepository
    name: voyager-services
  path: ./clusters/prod/my-service
  prune: true                    # Remove resources not in source
  targetNamespace: my-service
```

### Kustomization with Variable Substitution

```yaml
spec:
  postBuild:
    substitute:
      ENVIRONMENT: "prod"
      CLUSTER_NAME: "aks-voyager-prod"
    substituteFrom:
      - kind: ConfigMap
        name: cluster-settings
```

### Kustomization Dependencies

```yaml
spec:
  dependsOn:
    - name: infrastructure       # Wait for infra before deploying apps
    - name: cert-manager         # Wait for cert-manager CRDs
```

## Multi-Environment Configuration

### Directory Structure

```
clusters/
├── base/                        # Shared configuration
│   ├── kustomization.yaml
│   └── my-service/
│       ├── namespace.yaml
│       ├── helmrelease.yaml
│       └── kustomization.yaml
├── dev/
│   ├── kustomization.yaml       # Patches for dev
│   └── my-service/
│       └── patch-values.yaml
├── staging/
│   ├── kustomization.yaml
│   └── my-service/
│       └── patch-values.yaml
└── prod/
    ├── kustomization.yaml
    └── my-service/
        └── patch-values.yaml
```

### Base Kustomization

```yaml
# clusters/base/my-service/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespace.yaml
  - helmrelease.yaml
```

### Environment Overlay

```yaml
# clusters/prod/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../base/my-service
patches:
  - path: my-service/patch-values.yaml
    target:
      kind: HelmRelease
      name: my-service
```

### Environment Patch

```yaml
# clusters/prod/my-service/patch-values.yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: my-service
spec:
  values:
    replicaCount: 3
    resources:
      requests:
        cpu: 200m
        memory: 256Mi
```

## Image Update Automation

Automatically update image tags in Git when new container images are pushed.

### ImageRepository

```yaml
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImageRepository
metadata:
  name: my-service
  namespace: flux-system
spec:
  image: myregistry.azurecr.io/my-service
  interval: 5m
  secretRef:
    name: acr-credentials
```

### ImagePolicy

```yaml
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImagePolicy
metadata:
  name: my-service
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: my-service
  policy:
    semver:
      range: ">=1.0.0"          # Only promote semver-tagged images
```

### ImageUpdateAutomation

```yaml
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImageUpdateAutomation
metadata:
  name: my-service
  namespace: flux-system
spec:
  interval: 5m
  sourceRef:
    kind: GitRepository
    name: voyager-services
  git:
    checkout:
      ref:
        branch: main
    commit:
      author:
        name: fluxcd
        email: fluxcd@voyager.io
      messageTemplate: "chore: update {{.AutomationObject}} images"
    push:
      branch: main
  update:
    path: ./clusters
    strategy: Setters
```

Mark images for automation in HelmRelease values:

```yaml
spec:
  values:
    image:
      tag: "1.2.3"  # {"$imagepolicy": "flux-system:my-service:tag"}
```

## Namespace Isolation and Multi-Tenancy

### Per-Service Namespace Pattern

Each Voyager service gets its own namespace with FluxCD managing all
resources within it:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: my-service
  labels:
    app.kubernetes.io/managed-by: flux
    voyager.io/team: platform
```

## Debugging FluxCD

### CLI Commands

```bash
# Check all HelmRelease statuses
flux get helmreleases --all-namespaces

# Check a specific HelmRelease
flux get helmrelease my-service -n my-service

# Check source statuses
flux get sources all

# Force reconciliation
flux reconcile helmrelease my-service -n my-service
flux reconcile source git voyager-services

# View controller logs
flux logs --kind=HelmRelease --name=my-service

# Check Kustomization status
flux get kustomizations

# Suspend/resume reconciliation
flux suspend helmrelease my-service -n my-service
flux resume helmrelease my-service -n my-service

# Export resources for inspection
flux export helmrelease my-service -n my-service

# Trace a resource to find its FluxCD owner
flux trace deployment my-service -n my-service
```

### Common Issues

1. **HelmRelease stuck in "not ready":**
   - Check `flux get helmrelease` for the condition message
   - Check `flux logs --kind=HelmRelease` for controller errors
   - Verify the source (GitRepository/HelmRepository) is accessible

2. **Source not updating:**
   - Check credentials and network connectivity
   - Force reconciliation: `flux reconcile source git {name}`
   - Verify the ref (branch/tag) exists

3. **Kustomization failing:**
   - Check for YAML syntax errors in manifests
   - Verify all referenced resources exist
   - Check `flux get kustomization` for error details

4. **Drift detected but not corrected:**
   - Ensure `prune: true` is set on Kustomization
   - Check if the resource is excluded from reconciliation
   - Verify the controller has RBAC permissions

5. **Image automation not working:**
   - Verify ImageRepository can access the registry
   - Check ImagePolicy matches the expected tag format
   - Ensure the setter comment syntax is correct in manifests
