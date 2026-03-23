#!/bin/bash
# Lab 01: RBAC Basics - Setup Script
# This script sets up the lab environment

set -e

echo "🚀 Lab 01: RBAC Basics - Setup"
echo "================================"
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl not found. Please install kubectl first.${NC}"
    exit 1
fi

# Check if cluster is running
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}❌ Kubernetes cluster not accessible. Is minikube running?${NC}"
    echo "Run: minikube start --nodes=3"
    exit 1
fi

echo -e "${YELLOW}Step 1: Creating namespace 'dev'${NC}"
kubectl create namespace dev 2>/dev/null || echo "Namespace 'dev' already exists"
echo -e "${GREEN}✅ Namespace created${NC}"
echo ""

echo -e "${YELLOW}Step 2: Creating service account 'dev-user'${NC}"
kubectl create serviceaccount dev-user -n dev 2>/dev/null || echo "ServiceAccount 'dev-user' already exists"
echo -e "${GREEN}✅ Service account created${NC}"
echo ""

echo -e "${YELLOW}Step 3: Applying Role${NC}"
kubectl apply -f manifests/dev-role.yaml
echo -e "${GREEN}✅ Role applied${NC}"
echo ""

echo -e "${YELLOW}Step 4: Applying RoleBinding${NC}"
kubectl apply -f manifests/dev-rolebinding.yaml
echo -e "${GREEN}✅ RoleBinding applied${NC}"
echo ""

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}✅ Lab 01 Setup Complete!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""

echo "Verify the setup:"
echo "  kubectl get namespace dev"
echo "  kubectl get sa -n dev"
echo "  kubectl get role -n dev"
echo "  kubectl get rolebinding -n dev"
echo ""
echo "Run the test script:"
echo "  ./test.sh"