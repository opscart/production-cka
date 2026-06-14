#!/bin/bash
# Lab 17: CRI Container Runtimes - Setup Script

set -e

echo "🔧 Lab 17: CRI Runtimes Setup"
echo "=============================="
echo ""

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="lab17-cri"

echo -e "${BLUE}Step 1: Identifying container runtime...${NC}"
echo ""
echo "Runtime per node:"
kubectl get nodes -o \
  jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.nodeInfo.containerRuntimeVersion}{"\n"}{end}'
echo ""

echo -e "${BLUE}Step 2: Creating namespace...${NC}"
kubectl create namespace $NAMESPACE 2>/dev/null || echo "Already exists"
echo -e "${GREEN}✓ Namespace: $NAMESPACE${NC}"
echo ""

echo -e "${BLUE}Step 3: Creating test pod...${NC}"
kubectl run cri-test-pod \
  --image=nginx \
  -n $NAMESPACE 2>/dev/null || echo "Already exists"

kubectl wait --for=condition=ready pod/cri-test-pod \
  -n $NAMESPACE --timeout=60s
echo -e "${GREEN}✓ Pod: cri-test-pod${NC}"
echo ""

echo -e "${BLUE}Step 4: Finding pod location...${NC}"
NODE=$(kubectl get pod cri-test-pod -n $NAMESPACE \
  -o jsonpath='{.spec.nodeName}')
echo -e "${GREEN}✓ Pod running on node: $NODE${NC}"
echo ""

echo -e "${BLUE}Step 5: Showing containers via crictl...${NC}"
minikube ssh -n $NODE -- "sudo crictl ps 2>/dev/null | head -5" || true
echo ""

echo "=============================="
echo -e "${GREEN}✓ Setup complete!${NC}"
echo ""
echo "Container runtime info:"
kubectl get nodes -o wide
echo ""
echo "Run: ./scripts/test.sh"