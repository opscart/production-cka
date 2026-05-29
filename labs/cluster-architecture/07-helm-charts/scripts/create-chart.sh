#!/bin/bash
# Lab 07: Helm Charts - Create and Configure Chart Script

set -e

echo "📦 Lab 07: Create pharma-app Helm Chart"
echo "========================================"
echo ""

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

CHART_DIR="./charts/pharma-app"
ENV_DIR="./environments"

# Create directories
mkdir -p $ENV_DIR
mkdir -p ./charts

# Step 1: Scaffold chart
echo -e "${BLUE}Step 1: Scaffolding chart...${NC}"
echo ""

if [ -d "$CHART_DIR" ]; then
    echo -e "${YELLOW}Chart already exists at $CHART_DIR, recreating...${NC}"
    rm -rf $CHART_DIR
fi

helm create $CHART_DIR
echo -e "${GREEN}✓ Chart scaffolded${NC}"
echo ""

# Step 2: Update Chart.yaml
echo -e "${BLUE}Step 2: Updating Chart.yaml...${NC}"

cat > $CHART_DIR/Chart.yaml << 'EOF'
apiVersion: v2
name: pharma-app
description: A Helm chart for pharmaceutical microservices
type: application
version: 0.1.0
appVersion: "1.0.0"
keywords:
  - pharmaceutical
  - microservice
maintainers:
  - name: Shamsher Khan
    email: shamsher@opscart.com
    url: https://opscart.com
EOF

echo -e "${GREEN}✓ Chart.yaml updated${NC}"
echo ""

# Step 3: Update values.yaml
echo -e "${BLUE}Step 3: Creating values.yaml...${NC}"

cat > $CHART_DIR/values.yaml << 'EOF'
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

env: []
config: {}

autoscaling:
  enabled: false
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80

nodeSelector: {}
tolerations: []
affinity: {}
EOF

echo -e "${GREEN}✓ values.yaml created${NC}"
echo ""

# Step 4: Clear default templates
echo -e "${BLUE}Step 4: Creating templates...${NC}"

# Remove default templates
rm -f $CHART_DIR/templates/*.yaml
rm -f $CHART_DIR/templates/*.txt
rm -f $CHART_DIR/templates/tests/*.yaml

# Create _helpers.tpl
cat > $CHART_DIR/templates/_helpers.tpl << 'EOF'
{{- define "pharma-app.name" -}}
{{- .Values.appName | default .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "pharma-app.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "pharma-app.name" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "pharma-app.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/name: {{ include "pharma-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "pharma-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "pharma-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
EOF

# Create deployment.yaml
cat > $CHART_DIR/templates/deployment.yaml << 'EOF'
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

# Create service.yaml
cat > $CHART_DIR/templates/service.yaml << 'EOF'
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

# Create configmap.yaml
cat > $CHART_DIR/templates/configmap.yaml << 'EOF'
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

echo -e "${GREEN}✓ Templates created${NC}"
echo ""

# Step 5: Create environment values files
echo -e "${BLUE}Step 5: Creating environment values files...${NC}"

cat > $ENV_DIR/values-dev.yaml << 'EOF'
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
EOF

cat > $ENV_DIR/values-staging.yaml << 'EOF'
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
EOF

cat > $ENV_DIR/values-prod.yaml << 'EOF'
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
EOF

echo -e "${GREEN}✓ Environment files created${NC}"
echo ""

# Step 6: Lint the chart
echo -e "${BLUE}Step 6: Linting chart...${NC}"
echo ""
helm lint $CHART_DIR
echo ""

# Step 7: Show rendered templates
echo -e "${BLUE}Step 7: Rendering templates (dev)...${NC}"
echo ""
helm template my-api $CHART_DIR \
  -f $ENV_DIR/values-dev.yaml \
  --set appName=api

echo ""
echo "========================================"
echo -e "${GREEN}✓ Chart created successfully!${NC}"
echo ""
echo "Chart location: $CHART_DIR"
echo ""
echo "Next steps:"
echo "  Test install:   ./scripts/test-chart.sh"
echo "  Install:        helm install my-api ./charts/pharma-app -f environments/values-dev.yaml"
echo "  Cleanup:        ./scripts/cleanup.sh"