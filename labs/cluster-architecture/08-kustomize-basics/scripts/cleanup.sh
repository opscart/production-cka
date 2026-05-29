#!/bin/bash
# Lab 08: Kustomize Basics - Cleanup Script

set -e

echo "🧹 Lab 08: Cleanup"
echo "=================="
echo ""

GREEN='\033[0;32m'
NC='\033[0m'

DEMO_DIR="./kustomize-demo"

for ENV in dev staging prod; do
    if kubectl get deployment ${ENV}-pharma-api &>/dev/null 2>&1; then
        kubectl delete -k $DEMO_DIR/overlays/$ENV/ 2>/dev/null || true
        echo -e "${GREEN}✓ $ENV removed${NC}"
    fi
done

echo ""
echo "Remaining resources:"
kubectl get deployments 2>/dev/null | grep pharma || echo "None"

echo ""
echo "=================="
echo -e "${GREEN}✓ Cleanup complete!${NC}"
