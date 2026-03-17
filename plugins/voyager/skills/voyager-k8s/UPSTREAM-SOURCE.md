# Upstream Sources

This skill was curated from the following upstream sources on 2026-03-17.

## Kubernetes Patterns and Best Practices

- **openclaw/skills - Kubernetes SKILL.md**
  https://github.com/openclaw/skills/blob/main/skills/kcns008/kubernetes/SKILL.md
  Multi-agent cluster operations system with Kubernetes expertise.
  Used for: general K8s operational patterns, deployment strategies.

- **github/awesome-copilot - kubernetes-manifests.instructions.md**
  https://github.com/github/awesome-copilot/blob/main/instructions/kubernetes-manifests.instructions.md
  Production-ready Kubernetes manifest best practices.
  Used for: labeling, security contexts, resource management, probes,
  deployment strategies, validation patterns.

## FluxCD GitOps Patterns

- **FluxCD Official Documentation**
  https://fluxcd.io/flux/concepts/
  https://fluxcd.io/flux/use-cases/helm/
  FluxCD concepts, architecture, and Helm integration patterns.
  Used for: controller architecture, HelmRelease CRDs, Kustomization
  overlays, image automation, multi-environment configuration,
  debugging workflows.

## Voyager-Specific Adaptations

All upstream content was adapted for the Voyager platform context:
- Azure Kubernetes Service (AKS) as the target cluster
- Azure Key Vault + CSI driver for secrets management
- Azure Container Registry (ACR) for container images
- FluxCD (not ArgoCD) as the GitOps operator
- Helm as the packaging standard
- Voyager namespace and labeling conventions
