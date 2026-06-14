#!/bin/bash
# Lab 04: Cluster Upgrade - Cleanup

set -e

echo "🧹 Lab 04: Cleanup"
echo "=================="
echo ""

GREEN='\033[0;32m'
NC='\033[0m'

NODE="opscart-m02"

# Safety: uncordon if still cordoned
NODE_STATUS=$(kubectl get node $NODE \
  -o jsonpath='{.spec.unschedulable}' 2>/dev/null || echo "")
if [ "$NODE_STATUS" = "true" ]; then
    kubectl uncordon $NODE
    echo -e "${GREEN}✓ Node $NODE uncordoned${NC}"
fi

kubectl delete namespace lab04-upgrade 2>/dev/null && \
  echo -e "${GREEN}✓ Namespace lab04-upgrade removed${NC}" || true

echo ""
echo "=================="
echo -e "${GREEN}✓ Cleanup complete!${NC}"
