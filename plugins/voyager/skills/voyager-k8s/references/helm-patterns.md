# Helm Chart Patterns Reference

## Chart Structure

A well-organized Helm chart follows this layout:

```
charts/{service-name}/
├── Chart.yaml              # Chart metadata
├── Chart.lock              # Dependency lock file (auto-generated)
├── values.yaml             # Default configuration values
├── templates/
│   ├── NOTES.txt           # Post-install usage notes
│   ├── _helpers.tpl        # Reusable template partials
│   ├── deployment.yaml     # Deployment resource
│   ├── service.yaml        # Service resource
│   ├── ingress.yaml        # Ingress resource (optional)
│   ├── configmap.yaml      # ConfigMap (optional)
│   ├── serviceaccount.yaml # ServiceAccount
│   ├── hpa.yaml            # HorizontalPodAutoscaler (optional)
│   ├── pdb.yaml            # PodDisruptionBudget (optional)
│   └── secret-provider.yaml # Azure Key Vault CSI SecretProviderClass
└── env/
    ├── dev-values.yaml     # Dev environment overrides
    ├── staging-values.yaml # Staging environment overrides
    └── prod-values.yaml    # Production environment overrides
```

## Chart.yaml

```yaml
apiVersion: v2
name: my-service
description: A Helm chart for the my-service API
type: application
version: 0.1.0          # Chart version (bump on chart changes)
appVersion: "1.0.0"     # Application version (matches container tag)

dependencies:            # Optional subchart dependencies
  - name: redis
    version: "18.x.x"
    repository: "https://charts.bitnami.com/bitnami"
    condition: redis.enabled
```

## values.yaml Patterns

Organize values with clear sections and documentation:

```yaml
# -- Number of replicas
replicaCount: 2

image:
  # -- Container image repository
  repository: myregistry.azurecr.io/my-service
  # -- Image pull policy
  pullPolicy: IfNotPresent
  # -- Image tag (overrides appVersion)
  tag: ""

# -- Image pull secrets for private registries
imagePullSecrets:
  - name: acr-pull-secret

serviceAccount:
  # -- Create a ServiceAccount
  create: true
  # -- Annotations for the ServiceAccount (e.g., Azure Workload Identity)
  annotations: {}
  name: ""

service:
  # -- Service type
  type: ClusterIP
  # -- Service port
  port: 80
  # -- Container target port
  targetPort: 8080

ingress:
  # -- Enable ingress
  enabled: false
  # -- Ingress class name
  className: nginx
  annotations: {}
  hosts:
    - host: my-service.example.com
      paths:
        - path: /
          pathType: Prefix
  tls: []

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 300m
    memory: 384Mi

autoscaling:
  # -- Enable HPA
  enabled: false
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 75

# -- Liveness probe configuration
livenessProbe:
  httpGet:
    path: /healthz
    port: http
  initialDelaySeconds: 10
  periodSeconds: 15
  timeoutSeconds: 3
  failureThreshold: 3

# -- Readiness probe configuration
readinessProbe:
  httpGet:
    path: /readyz
    port: http
  initialDelaySeconds: 5
  periodSeconds: 10
  timeoutSeconds: 3
  failureThreshold: 3

# -- Startup probe for slow-starting services
startupProbe:
  httpGet:
    path: /healthz
    port: http
  initialDelaySeconds: 5
  periodSeconds: 5
  failureThreshold: 30

# -- Security context for the pod
podSecurityContext:
  runAsNonRoot: true
  fsGroup: 65534

# -- Security context for the container
securityContext:
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  runAsUser: 65534
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL

# -- Pod disruption budget
podDisruptionBudget:
  enabled: true
  minAvailable: 1

# -- Node selector
nodeSelector: {}

# -- Tolerations
tolerations: []

# -- Affinity rules
affinity: {}

# -- Environment variables from values
env: []

# -- Environment variables from secrets/configmaps
envFrom: []

# -- Azure Key Vault secrets via CSI driver
keyVault:
  enabled: false
  vaultName: ""
  tenantId: ""
  secrets: []
```

## Template Helpers (_helpers.tpl)

```yaml
{{/*
Expand the name of the chart.
*/}}
{{- define "my-service.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "my-service.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "my-service.labels" -}}
helm.sh/chart: {{ include "my-service.chart" . }}
{{ include "my-service.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "my-service.selectorLabels" -}}
app.kubernetes.io/name: {{ include "my-service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Chart label
*/}}
{{- define "my-service.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}
```

## Deployment Template

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "my-service.fullname" . }}
  labels:
    {{- include "my-service.labels" . | nindent 4 }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "my-service.selectorLabels" . | nindent 6 }}
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 1
  template:
    metadata:
      labels:
        {{- include "my-service.selectorLabels" . | nindent 8 }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "my-service.fullname" . }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      containers:
        - name: {{ .Chart.Name }}
          securityContext:
            {{- toYaml .Values.securityContext | nindent 12 }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ .Values.service.targetPort }}
              protocol: TCP
          livenessProbe:
            {{- toYaml .Values.livenessProbe | nindent 12 }}
          readinessProbe:
            {{- toYaml .Values.readinessProbe | nindent 12 }}
          {{- if .Values.startupProbe }}
          startupProbe:
            {{- toYaml .Values.startupProbe | nindent 12 }}
          {{- end }}
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          {{- with .Values.env }}
          env:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.envFrom }}
          envFrom:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- if .Values.keyVault.enabled }}
          volumeMounts:
            - name: secrets-store
              mountPath: "/mnt/secrets-store"
              readOnly: true
          {{- end }}
      {{- if .Values.keyVault.enabled }}
      volumes:
        - name: secrets-store
          csi:
            driver: secrets-store.csi.k8s.io
            readOnly: true
            volumeAttributes:
              secretProviderClass: {{ include "my-service.fullname" . }}
      {{- end }}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
```

## Service Template

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "my-service.fullname" . }}
  labels:
    {{- include "my-service.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: {{ .Values.service.targetPort }}
      protocol: TCP
      name: http
  selector:
    {{- include "my-service.selectorLabels" . | nindent 4 }}
```

## Ingress Template

```yaml
{{- if .Values.ingress.enabled -}}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "my-service.fullname" . }}
  labels:
    {{- include "my-service.labels" . | nindent 4 }}
  {{- with .Values.ingress.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  ingressClassName: {{ .Values.ingress.className }}
  {{- if .Values.ingress.tls }}
  tls:
    {{- range .Values.ingress.tls }}
    - hosts:
        {{- range .hosts }}
        - {{ . | quote }}
        {{- end }}
      secretName: {{ .secretName }}
    {{- end }}
  {{- end }}
  rules:
    {{- range .Values.ingress.hosts }}
    - host: {{ .host | quote }}
      http:
        paths:
          {{- range .paths }}
          - path: {{ .path }}
            pathType: {{ .pathType }}
            backend:
              service:
                name: {{ include "my-service.fullname" $ }}
                port:
                  name: http
          {{- end }}
    {{- end }}
{{- end }}
```

## Azure Key Vault CSI SecretProviderClass

```yaml
{{- if .Values.keyVault.enabled -}}
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: {{ include "my-service.fullname" . }}
  labels:
    {{- include "my-service.labels" . | nindent 4 }}
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "true"
    keyvaultName: {{ .Values.keyVault.vaultName | quote }}
    tenantId: {{ .Values.keyVault.tenantId | quote }}
    objects: |
      array:
        {{- range .Values.keyVault.secrets }}
        - |
          objectName: {{ .name }}
          objectType: secret
        {{- end }}
{{- end }}
```

## HPA Template

```yaml
{{- if .Values.autoscaling.enabled -}}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "my-service.fullname" . }}
  labels:
    {{- include "my-service.labels" . | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "my-service.fullname" . }}
  minReplicas: {{ .Values.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas }}
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}
{{- end }}
```

## Environment-Specific Values

Override values per environment. Key differences between environments:

| Setting | Dev | Prod |
|---------|-----|------|
| replicaCount | 1 | 3+ |
| autoscaling | disabled | enabled (min 3, max 10) |
| resources.requests.cpu | 50m | 200m |
| resources.requests.memory | 64Mi | 256Mi |
| PDB | disabled | enabled (minAvailable: 2) |
| keyVault.vaultName | kv-voyager-dev | kv-voyager-prod |

## Helm CLI Quick Reference

```bash
# Render templates locally (validate without deploying)
helm template my-release charts/my-service/ -f charts/my-service/env/dev-values.yaml

# Lint the chart for errors
helm lint charts/my-service/

# Dry-run install to see what would be created
helm install my-release charts/my-service/ --dry-run --debug

# Show computed values
helm get values my-release -n my-namespace

# Show release history
helm history my-release -n my-namespace

# Rollback to previous revision
helm rollback my-release 1 -n my-namespace

# List all releases
helm list -n my-namespace

# Update dependencies
helm dependency update charts/my-service/
```

## Best Practices Checklist

- [ ] Chart.yaml has correct apiVersion, name, version, appVersion
- [ ] values.yaml documents every value with comments
- [ ] All templates use helper functions for names and labels
- [ ] Standard labels applied: name, instance, version, managed-by
- [ ] Resource requests and limits set on all containers
- [ ] Liveness and readiness probes configured
- [ ] Security context: runAsNonRoot, readOnlyRootFilesystem, drop ALL caps
- [ ] Image uses immutable tag (semver or digest), never `:latest`
- [ ] Secrets sourced from Key Vault CSI, never in values or configmaps
- [ ] Rolling update strategy with maxUnavailable: 0
- [ ] Environment-specific values files for dev/staging/prod
- [ ] `helm template` and `helm lint` pass cleanly
