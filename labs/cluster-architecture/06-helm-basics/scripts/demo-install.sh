#!/bin/bash
# Lab 06: Helm Basics - Demo Installation Script

set -e

echo "📦 Lab 06: Helm Demo Installation"
echo "=================================="
echo ""

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check Helm is installed
if ! command -v helm &> /dev/null; then
    echo -e "${YELLOW}Helm not found. Run ./install-helm.sh first${NC}"
    exit 1
fi

echo -e "${BLUE}Step 1: Add Bitnami repository${NC}"
helm repo add bitnami https://charts.bitnami.com/bitnami 2>/dev/null || echo "Repository already exists"
helm repo update

echo ""
echo -e "${GREEN}✓ Repository added${NC}"
echo ""

echo -e "${BLUE}Step 2: Install nginx chart${NC}"
helm install demo-nginx bitnami/nginx \
  --set replicaCount=2 \
  --set service.type=NodePort

echo ""
echo -e "${GREEN}✓ Chart installed${NC}"
echo ""

echo -e "${BLUE}Step 3: Verify installation${NC}"
echo ""

# Wait for deployment
kubectl wait --for=condition=available --timeout=60s deployment/demo-nginx

# Show resources
echo "Helm releases:"
helm list

echo ""
echo "Kubernetes resources:"
kubectl get all -l app.kubernetes.io/instance=demo-nginx

echo ""
echo "=================================="
echo -e "${GREEN}✓ Demo installation complete!${NC}"
echo ""
echo "Access the application:"
echo "  kubectl port-forward svc/demo-nginx 8080:80"
echo "  curl http://localhost:8080"
echo ""
echo "Or test with:"
echo "  kubectl run test --image=curlimages/curl --rm -it --restart=Never -- curl http://demo-nginx"
echo ""
echo "Cleanup:"
echo "  ./scripts/cleanup.sh"
