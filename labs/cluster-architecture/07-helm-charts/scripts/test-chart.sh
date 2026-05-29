#!/bin/bash
# Lab 07: Helm Charts - Test and Install Chart Script

set -e

echo "🧪 Lab 07: Test and Install pharma-app Chart"
echo "============================================="
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

CHART_DIR="./charts/pharma-app"
ENV_DIR="./environments"

# Check chart exists
if [ ! -d "$CHART_DIR" ]; then
    echo -e "${RED}Chart not found. Run ./scripts/create-chart.sh first${NC}"
    exit 1
fi

# Step 1: Lint
echo -e "${BLUE}Step 1: Linting chart...${NC}"
helm lint $CHART_DIR
echo -e "${GREEN}✓ Lint passed${NC}"
echo ""

# Step 2: Render templates
echo -e "${BLUE}Step 2: Rendering templates...${NC}"
echo ""
echo "--- Dev environment ---"
helm template my-api $CHART_DIR -f $ENV_DIR/values-dev.yaml --set appName=api
echo ""
echo -e "${GREEN}✓ Templates render successfully${NC}"
echo ""

# Step 3: Install
echo -e "${BLUE}Step 3: Installing chart (dev environment)...${NC}"
echo ""

helm install my-api $CHART_DIR \
  -f $ENV_DIR/values-dev.yaml \
  --set appName=api \
  --set image.repository=nginx

echo ""
echo -e "${GREEN}✓ Chart installed${NC}"
echo ""

# Wait for deployment
echo "Waiting for pods to be ready..."
kubectl wait --for=condition=available --timeout=60s \
  deployment/$(kubectl get deploy -l app.kubernetes.io/instance=my-api -o jsonpath='{.items[0].metadata.name}')

echo ""

# Step 4: Verify
echo -e "${BLUE}Step 4: Verifying installation...${NC}"
echo ""

echo "Helm releases:"
helm list

echo ""
echo "Kubernetes resources:"
kubectl get all -l app.kubernetes.io/instance=my-api

echo ""
echo "ConfigMap (env config):"
kubectl get configmap -l app.kubernetes.io/instance=my-api

echo ""
echo "============================================="
echo -e "${GREEN}✓ Chart installed and verified!${NC}"
echo ""
echo "Test with:"
echo "  kubectl port-forward svc/my-api-api 8080:80"
echo "  curl http://localhost:8080"
echo ""
echo "Upgrade:"
echo "  helm upgrade my-api ./charts/pharma-app -f environments/values-staging.yaml --set appName=api"
echo ""
echo "Cleanup:"
echo "  ./scripts/cleanup.sh"