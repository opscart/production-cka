#!/bin/bash
# Lab 02: RBAC Advanced - Setup Script

set -e

echo "🚀 Lab 02: RBAC Advanced - Setup"
echo "=================================="
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl not found${NC}"
    exit 1
fi

# Check cluster
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}❌ Kubernetes cluster not accessible${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 1: Creating namespaces${NC}"
kubectl create namespace prod 2>/dev/null || echo "Namespace 'prod' already exists"
kubectl create namespace staging 2>/dev/null || echo "Namespace 'staging' already exists"
echo -e "${GREEN}✅ Namespaces created${NC}"
echo ""

echo -e "${YELLOW}Step 2: Creating service accounts${NC}"
kubectl create serviceaccount platform-admin -n kube-system 2>/dev/null || echo "SA 'platform-admin' already exists"
kubectl create serviceaccount security-viewer -n kube-system 2>/dev/null || echo "SA 'security-viewer' already exists"
kubectl create serviceaccount monitoring-user -n kube-system 2>/dev/null || echo "SA 'monitoring-user' already exists"
kubectl create serviceaccount developer -n prod 2>/dev/null || echo "SA 'developer' already exists"
echo -e "${GREEN}✅ Service accounts created${NC}"
echo ""

echo -e "${YELLOW}Step 3: Applying ClusterRoles and Bindings${NC}"
kubectl apply -f manifests/cluster-admin-role.yaml
kubectl apply -f manifests/cluster-admin-binding.yaml
echo -e "${GREEN}✅ Platform admin role applied${NC}"
echo ""

kubectl apply -f manifests/cluster-viewer-role.yaml
kubectl apply -f manifests/cluster-viewer-binding.yaml
echo -e "${GREEN}✅ Security viewer role applied${NC}"
echo ""

kubectl apply -f manifests/node-reader-role.yaml
kubectl apply -f manifests/node-reader-binding.yaml
echo -e "${GREEN}✅ Node reader role applied${NC}"
echo ""

kubectl apply -f manifests/aggregated-monitoring-role.yaml
echo -e "${GREEN}✅ Monitoring aggregated role applied${NC}"
echo ""

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}✅ Lab 02 Setup Complete!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""

echo "Verify the setup:"
echo "  kubectl get clusterrole | grep -E 'platform|security|node-reader|monitoring'"
echo "  kubectl get clusterrolebinding | grep -E 'platform|security|monitoring'"
echo "  kubectl get sa -n kube-system | grep -E 'platform|security|monitoring'"
echo "  kubectl get sa -n prod"
echo ""
echo "Run the test script:"
echo "  ./scripts/test.sh"