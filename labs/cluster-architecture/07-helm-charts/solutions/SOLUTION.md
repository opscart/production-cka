# Lab 07: Helm Charts - Solution Guide

## Quick Solution (Exam Speed)

```bash
# 1. Create chart (30 sec)
helm create pharma-app

# 2. Edit Chart.yaml (30 sec)
vim pharma-app/Chart.yaml

# 3. Edit values.yaml (1 min)
vim pharma-app/values.yaml

# 4. Edit templates (3 min)
vim pharma-app/templates/deployment.yaml
vim pharma-app/templates/service.yaml

# 5. Lint and install (1 min)
helm lint pharma-app
helm install my-api ./pharma-app
```

---

## Complete Solution

### Step 1: Create Chart

```bash
helm create charts/pharma-app
```

Or use the script:

```bash
./scripts/create-chart.sh
```

---

### Step 2: Chart.yaml

```yaml
apiVersion: v2
name: pharma-app
description: A Helm chart for pharmaceutical microservices
type: application
version: 0.1.0
appVersion: "1.0.0"
maintainers:
  - name: Shamsher Khan
    email: shamsher@opscart.com
```

---

### Step 3: values.yaml

```yaml
appName: myapp
replicaCount: 2

image:
  repository: nginx
  tag: "latest"
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 80
  targetPort: 80

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi

healthCheck:
  enabled: true
  path: /
  initialDelaySeconds: 30
  periodSeconds: 10

config: {}
env: []
```

---

### Step 4: Templates

**_helpers.tpl:**

```yaml
{{- define "pharma-app.fullname" -}}
{{- printf "%s-%s" .Release.Name .Values.appName | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "pharma-app.labels" -}}
app.kubernetes.io/name: {{ .Values.appName }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "pharma-app.selectorLabels" -}}
app.kubernetes.io/name: {{ .Values.appName }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
```

**deployment.yaml:**

```yaml
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
        - name: {{ .Values.appName }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          ports:
            - containerPort: {{ .Values.service.targetPort }}
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
```

**service.yaml:**

```yaml
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
  selector:
    {{- include "pharma-app.selectorLabels" . | nindent 4 }}
```

---

### Step 5: Install and Verify

```bash
# Lint
helm lint charts/pharma-app

# Render templates (check output)
helm template my-api charts/pharma-app -f environments/values-dev.yaml

# Install
helm install my-api charts/pharma-app \
  -f environments/values-dev.yaml \
  --set appName=api

# Verify
kubectl get all -l app.kubernetes.io/instance=my-api
```

---

### Step 6: Multi-Service Deployment

```bash
# Deploy API, Frontend, Worker from same chart
helm install api charts/pharma-app \
  -f environments/values-dev.yaml \
  --set appName=api

helm install frontend charts/pharma-app \
  -f environments/values-dev.yaml \
  --set appName=frontend \
  --set service.port=3000 \
  --set service.targetPort=3000

helm install worker charts/pharma-app \
  -f environments/values-dev.yaml \
  --set appName=worker \
  --set replicaCount=1

# List all
helm list
kubectl get all
```

---

## Key Takeaways

✅ **helm create** scaffolds a complete chart  
✅ **values.yaml** defines all configurable options  
✅ **templates/** contain Go-templated Kubernetes YAML  
✅ **_helpers.tpl** defines reusable template snippets  
✅ **Environment files** enable environment-specific config  
✅ **helm lint** validates chart before install  
✅ **helm template** renders YAML without installing  

---

**Completed Lab 07?** ✅

Move to **[Lab 08: Kustomize Basics](../08-kustomize-basics/)**