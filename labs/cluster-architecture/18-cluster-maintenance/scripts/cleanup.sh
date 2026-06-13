#!/bin/bash
# Lab 18: Cluster Maintenance - Cleanup

set -e

echo "🧹 Lab 18: Cleanup"
echo "=================="
echo ""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

NODE="opscart-m02"

# Safety: Make sure node is uncordoned
NODE_STATUS=$(kubectl get node $NODE \
  -o jsonpath='{.spec.unschedulable}' 2>/dev/null || echo "")

if [ "$NODE_STATUS" = "true" ]; then
    echo -e "${YELLOW}⚠️  Node $NODE is still cordoned - uncordoning...${NC}"
    kubectl uncordon $NODE
    echo -e "${GREEN}✓ Node uncordoned${NC}"
fi

# Delete namespace
kubectl delete namespace lab18-maintenance 2>/dev/null && \
  echo -e "${GREEN}✓ Namespace lab18-maintenance removed${NC}" || true

echo ""
echo "Node status:"
kubectl get nodes

echo ""
echo "=================="
echo -e "${GREEN}✓ Cleanup complete!${NC}"