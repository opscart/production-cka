# Lab 07: Helm Charts - Quick Reference

## Chart Commands

```bash
# Create chart scaffold
helm create mychart

# Lint chart (check for errors)
helm lint ./mychart

# Render templates (no install)
helm template my-release ./mychart

# Render with values
helm template my-release ./mychart -f values-dev.yaml

# Dry run
helm install my-release ./mychart --dry-run --debug

# Install local chart
helm install my-release ./mychart

# Install with values file
helm install my-release ./mychart -f values-prod.yaml

# Package chart
helm package ./mychart
```

---

## Chart Structure

```
mychart/
├── Chart.yaml          # Metadata
├── values.yaml         # Default values
├── charts/             # Dependencies
└── templates/
    ├── _helpers.tpl    # Template helpers
    ├── deployment.yaml
    ├── service.yaml
    ├── configmap.yaml
    └── NOTES.txt       # Post-install notes
```

---

## Chart.yaml Fields

```yaml
apiVersion: v2
name: mychart
description: My chart description
type: application         # application or library
version: 0.1.0           # Chart version
appVersion: "1.0.0"      # App version
```

---

## Template Syntax

### Variables

```yaml
# Release info
{{ .Release.Name }}       # Release name
{{ .Release.Namespace }}  # Namespace
{{ .Release.Service }}    # Helm

# Chart info
{{ .Chart.Name }}         # Chart name
{{ .Chart.Version }}      # Chart version
{{ .Chart.AppVersion }}   # App version

# Values
{{ .Values.key }}         # From values.yaml
{{ .Values.nested.key }}  # Nested value
```

### Control Structures

```yaml
# If/else
{{- if .Values.enabled }}
key: value
{{- else }}
key: other
{{- end }}

# With (scope change)
{{- with .Values.config }}
data:
  key: {{ .value }}
{{- end }}

# Range (loop)
{{- range .Values.items }}
- {{ . }}
{{- end }}

# Range with key/value
{{- range $key, $value := .Values.config }}
{{ $key }}: {{ $value | quote }}
{{- end }}
```

### Pipelines

```yaml
# String functions
{{ .Values.name | upper }}           # UPPERCASE
{{ .Values.name | lower }}           # lowercase
{{ .Values.name | title }}           # Title Case
{{ .Values.name | trunc 63 }}        # Truncate
{{ .Values.name | trimSuffix "-" }}  # Trim suffix
{{ .Values.name | quote }}           # "quoted"

# Type conversions
{{ .Values.port | toString }}
{{ .Values.replicas | int }}

# YAML
{{- toYaml .Values.resources | nindent 12 }}  # Indent YAML block

# Default values
{{ .Values.name | default "myapp" }}
```

### Named Templates (_helpers.tpl)

```yaml
# Define
{{- define "mychart.fullname" -}}
{{- printf "%s-%s" .Release.Name .Values.appName }}
{{- end }}

# Use
name: {{ include "mychart.fullname" . }}
```

---

## values.yaml Patterns

### Nested values

```yaml
image:
  repository: nginx
  tag: "latest"
  pullPolicy: IfNotPresent
```

### Optional sections

```yaml
# Empty = disabled
config: {}

# With data = enabled
config:
  KEY: value
```

### Lists

```yaml
env:
  - name: ENV_VAR
    value: "value"
  - name: ANOTHER_VAR
    value: "other"
```

---

## Environment Values Files

```
environments/
├── values-dev.yaml      # Low resources, debug logging
├── values-staging.yaml  # Medium resources
└── values-prod.yaml     # Full resources, autoscaling
```

**Usage:**
```bash
# Deploy to different environments
helm install app ./chart -f environments/values-dev.yaml
helm install app ./chart -f environments/values-prod.yaml
```

---

## Exam Scenarios

### Scenario 1: Create a Chart

```bash
# Create scaffold
helm create webapp

# Edit Chart.yaml, values.yaml, templates/
# Then install
helm install my-app ./webapp
```

### Scenario 2: Add ConfigMap Template

```yaml
# templates/configmap.yaml
{{- if .Values.config }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-config
data:
  {{- range $k, $v := .Values.config }}
  {{ $k }}: {{ $v | quote }}
  {{- end }}
{{- end }}
```

### Scenario 3: Package Chart

```bash
# Package into .tgz
helm package ./webapp

# Install from package
helm install my-app webapp-0.1.0.tgz
```

---

## Troubleshooting

### Lint Errors

```bash
# Check chart syntax
helm lint ./mychart

# Common errors:
# - Missing required fields in Chart.yaml
# - Invalid YAML syntax in templates
# - Missing closing {{ end }}
```

### Template Rendering Errors

```bash
# Debug rendering
helm template my-app ./mychart --debug

# Common errors:
# - Wrong value path ({{ .Values.wrong.path }})
# - Missing default for optional values
```

### Installation Errors

```bash
# Check rendered manifest
helm template my-app ./mychart

# Dry run to validate
helm install my-app ./mychart --dry-run

# Check events after install
kubectl get events --sort-by='.lastTimestamp'
```

---

## Time Budget (Exam)

- Create chart scaffold: **1 minute**
- Edit templates: **3-4 minutes**
- Lint and verify: **1 minute**
- Install: **1 minute**
- **Total: ~6-7 minutes**