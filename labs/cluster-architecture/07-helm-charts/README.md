# Lab 07: Helm Charts

## Objective
Create custom Helm charts from scratch, understand Go templating, manage chart dependencies, and package charts for distribution. Build a production-ready chart for a pharmaceutical application.

## CKA Exam Relevance
- **Domain:** Cluster Architecture, Installation & Configuration (25%)
- **Topic:** Use Helm to manage Kubernetes applications
- **Exam Weight:** Medium (chart creation less common than install/upgrade)
- **Typical Exam Time:** 5-8 minutes

## Time to Complete
50 minutes

## Scenario
Your pharmaceutical company needs a standardized way to deploy microservices across 8+ AKS clusters. Every team is writing duplicate YAML - the API team, frontend team, and data team all maintain their own nearly-identical manifests.

**Your task:** Create a reusable Helm chart called `pharma-app` that:
- Works for any microservice (configurable name, image, replicas)
- Supports multiple environments (dev, staging, prod)
- Includes health checks, resource limits, service configuration
- Can be versioned and shared across teams

---

## What is a Helm Chart?

A Helm chart is a **collection of Kubernetes YAML templates** with **variables** that get filled in at install time.

```
Without Helm:                    With Helm:
─────────────                    ──────────
api-deployment.yaml              pharma-app/
frontend-deployment.yaml    →      Chart.yaml
worker-deployment.yaml             values.yaml
api-service.yaml                   templates/
frontend-service.yaml                deployment.yaml  (one template!)
worker-service.yaml                  service.yaml
(6 files, lots of duplication)   (3 files, zero duplication)
```

### Go Templating

Helm uses Go templates to inject values into YAML:

```yaml
# templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-{{ .Values.appName }}
spec:
  replicas: {{ .Values.replicaCount }}
  template:
    spec:
      containers:
        - name: {{ .Values.appName }}
          image: {{ .Values.image.repository }}:{{ .Values.image.tag }}
          resources:
            limits:
              cpu: {{ .Values.resources.limits.cpu }}
              memory: {{ .Values.resources.limits.memory }}
```

**Template Variables:**
- `{{ .Release.Name }}` - Release name given at install
- `{{ .Values.xxx }}` - Values from values.yaml or --set
- `{{ .Chart.Name }}` - Chart name from Chart.yaml
- `{{ .Chart.Version }}` - Chart version

---

## Lab Structure

```
07-helm-charts/
├── README.md
├── QUICK-REFERENCE.md
├── charts/
│   └── pharma-app/              # Our custom chart
│       ├── Chart.yaml           # Chart metadata
│       ├── values.yaml          # Default values
│       └── templates/
│           ├── deployment.yaml
│           ├── service.yaml
│           ├── configmap.yaml
│           └── _helpers.tpl     # Template helpers
├── environments/
│   ├── values-dev.yaml          # Dev overrides
│   ├── values-staging.yaml      # Staging overrides
│   └── values-prod.yaml         # Prod overrides
├── scripts/
│   ├── create-chart.sh          # Scaffold chart
│   ├── test-chart.sh            # Lint and test
│   └── cleanup.sh
└── solutions/
    └── SOLUTION.md
```

---

## Tasks

### Task 1: Scaffold a New Chart (5 min)

**Objective:** Create a new chart using Helm's scaffolding command.

```bash
# Navigate to lab directory
cd labs/cluster-architecture/07-helm-charts

# Create chart scaffold
helm create charts/pharma-app

# View the structure
find charts/pharma-app -type f | sort
```

**What helm create generates:**
```
pharma-app/
├── Chart.yaml          # Metadata
├── values.yaml         # Default values
├── charts/             # Dependencies
└── templates/
    ├── deployment.yaml # Sample deployment
    ├── service.yaml    # Sample service
    ├── ingress.yaml    # Sample ingress
    ├── serviceaccount.yaml
    ├── hpa.yaml        # Horizontal Pod Autoscaler
    ├── NOTES.txt       # Post-install notes
    ├── _helpers.tpl    # Template helpers
    └── tests/
        └── test-connection.yaml
```

**View the generated Chart.yaml:**

```bash
cat charts/pharma-app/Chart.yaml
```

---

### Task 2: Customize Chart.yaml (5 min)

**Objective:** Update chart metadata for our pharmaceutical app.

**Edit Chart.yaml:**

```bash
cat > charts/pharma-app/Chart.yaml << 'EOF'
apiVersion: v2
name: pharma-app
description: A Helm chart for pharmaceutical microservices

# Chart type: application or library
type: application

# Chart version (increment when chart changes)
version: 0.1.0

# App version (the application being deployed)
appVersion: "1.0.0"

# Chart metadata
keywords:
  - pharmaceutical
  - microservice
  - api

maintainers:
  - name: Shamsher Khan
    email: shamsher@opscart.com
    url: https://opscart.com
EOF
```

---

### Task 3: Define Default Values (10 min)

**Objective:** Create a flexible values.yaml for any microservice.

```bash
cat > charts/pharma-app/values.yaml << 'EOF'
# Application configuration
appName: myapp
replicaCount: 2

# Container image
image:
  repository: nginx
  tag: "latest"
  pullPolicy: IfNotPresent

# Service configuration
service:
  type: ClusterIP
  port: 80
  targetPort: 80

# Resource limits (production-grade)
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi

# Health checks
healthCheck:
  enabled: true
  path: /
  initialDelaySeconds: 30
  periodSeconds: 10

# Environment variables
env: []
# - name: ENV_NAME
#   value: "value"

# ConfigMap data
config: {}
# KEY: value

# Autoscaling
autoscaling:
  enabled: false
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80

# Node selector
nodeSelector: {}

# Tolerations
tolerations: []

# Affinity
affinity: {}
EOF
```

---

### Task 4: Create Templates (20 min)

**Objective:** Write the Kubernetes YAML templates.

#### 4.1: Template Helpers (_helpers.tpl)

```bash
cat > charts/pharma-app/templates/_helpers.tpl << 'EOF'
{{/*
Expand the name of the chart.
*/}}
{{- define "pharma-app.name" -}}
{{- .Values.appName | default .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "pharma-app.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "pharma-app.name" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "pharma-app.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/name: {{ include "pharma-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "pharma-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "pharma-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
EOF
```

#### 4.2: Deployment Template

```bash
cat > charts/pharma-app/templates/deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "pharma-app.fullname" . }}
  labels:
    {{- include "pharma-app.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "pharma-app.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "pharma-app.labels" . | nindent 8 }}
    spec:
      containers:
        - name: {{ include "pharma-app.name" . }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - containerPort: {{ .Values.service.targetPort }}
          {{- if .Values.healthCheck.enabled }}
          livenessProbe:
            httpGet:
              path: {{ .Values.healthCheck.path }}
              port: {{ .Values.service.targetPort }}
            initialDelaySeconds: {{ .Values.healthCheck.initialDelaySeconds }}
            periodSeconds: {{ .Values.healthCheck.periodSeconds }}
          readinessProbe:
            httpGet:
              path: {{ .Values.healthCheck.path }}
              port: {{ .Values.service.targetPort }}
            initialDelaySeconds: 5
            periodSeconds: 5
          {{- end }}
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          {{- if .Values.env }}
          env:
            {{- toYaml .Values.env | nindent 12 }}
          {{- end }}
          {{- if .Values.config }}
          envFrom:
            - configMapRef:
                name: {{ include "pharma-app.fullname" . }}-config
          {{- end }}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
EOF
```

#### 4.3: Service Template

```bash
cat > charts/pharma-app/templates/service.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: {{ include "pharma-app.fullname" . }}
  labels:
    {{- include "pharma-app.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: {{ .Values.service.targetPort }}
      protocol: TCP
      name: http
  selector:
    {{- include "pharma-app.selectorLabels" . | nindent 4 }}
EOF
```

#### 4.4: ConfigMap Template (conditional)

```bash
cat > charts/pharma-app/templates/configmap.yaml << 'EOF'
{{- if .Values.config }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "pharma-app.fullname" . }}-config
  labels:
    {{- include "pharma-app.labels" . | nindent 4 }}
data:
  {{- range $key, $value := .Values.config }}
  {{ $key }}: {{ $value | quote }}
  {{- end }}
{{- end }}
EOF
```

---

### Task 5: Create Environment Values Files (5 min)

**Objective:** Create environment-specific values.

```bash
mkdir -p environments

# Development
cat > environments/values-dev.yaml << 'EOF'
replicaCount: 1

image:
  tag: "latest"

resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi

healthCheck:
  initialDelaySeconds: 10

config:
  ENVIRONMENT: "development"
  LOG_LEVEL: "debug"
  DB_HOST: "dev-db.internal"
EOF

# Staging
cat > environments/values-staging.yaml << 'EOF'
replicaCount: 2

image:
  tag: "1.0.0"

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi

config:
  ENVIRONMENT: "staging"
  LOG_LEVEL: "info"
  DB_HOST: "staging-db.internal"
EOF

# Production
cat > environments/values-prod.yaml << 'EOF'
replicaCount: 3

image:
  tag: "1.0.0"

resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 500m
    memory: 512Mi

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70

config:
  ENVIRONMENT: "production"
  LOG_LEVEL: "warn"
  DB_HOST: "prod-db.internal"
EOF
```

---

### Task 6: Test and Install the Chart (5 min)

**Objective:** Validate and deploy the custom chart.

```bash
# Lint the chart (check for errors)
helm lint charts/pharma-app

# Render templates (see output without installing)
helm template my-api charts/pharma-app

# Dry run (validate against cluster)
helm install my-api charts/pharma-app --dry-run --debug

# Install to dev
helm install my-api charts/pharma-app \
  -f environments/values-dev.yaml \
  --set appName=api \
  --set image.repository=nginx

# Verify
helm list
kubectl get all -l app.kubernetes.io/instance=my-api
```

**Install for different services:**

```bash
# Frontend
helm install my-frontend charts/pharma-app \
  -f environments/values-dev.yaml \
  --set appName=frontend \
  --set service.port=3000 \
  --set service.targetPort=3000

# Worker service
helm install my-worker charts/pharma-app \
  -f environments/values-dev.yaml \
  --set appName=worker \
  --set replicaCount=1
```

---

## Validation

```bash
# 1. Lint passes
helm lint charts/pharma-app

# 2. Templates render correctly
helm template my-api charts/pharma-app -f environments/values-dev.yaml

# 3. Install succeeds
helm install my-api charts/pharma-app -f environments/values-dev.yaml

# 4. All pods running
kubectl get pods -l app.kubernetes.io/instance=my-api

# 5. Service created
kubectl get svc -l app.kubernetes.io/instance=my-api
```

---

## Exam Tips

⏱️ **Time Management:**
- Chart creation: 3 minutes
- Template editing: 3 minutes
- Install and verify: 2 minutes
- **Total: ~8 minutes**

🎯 **Exam Question Patterns:**

> *"Create a Helm chart called 'webapp' with a Deployment and Service"*

> *"Package and install a local Helm chart"*

> *"Add a ConfigMap template to an existing chart"*

📖 **Documentation Reference:**
- https://helm.sh/docs/chart_template_guide/
- Search: "helm create", "helm template"

---

## Next Lab

Ready to continue? Move to **[Lab 08: Kustomize Basics](../08-kustomize-basics/README.md)**

---

**Author:** Shamsher Khan | **Blog:** opscart.com | **Course:** Production CKA 2026