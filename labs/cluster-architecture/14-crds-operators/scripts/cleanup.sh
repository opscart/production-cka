#!/bin/bash
# Lab 14: CRDs and Operators - Cleanup

set -e

echo "🧹 Lab 14: Cleanup"
echo "=================="
echo ""

GREEN='\033[0;32m'
NC='\033[0m'

NAMESPACE="lab14-crds"

# Delete namespace first (removes all custom resources)
kubectl delete namespace $NAMESPACE 2>/dev/null && \
  echo -e "${GREEN}✓ Namespace $NAMESPACE removed${NC}" || true

# Delete the CRD (also removes all instances cluster-wide)
kubectl delete crd backuppolicies.ops.example.com 2>/dev/null && \
  echo -e "${GREEN}✓ CRD backuppolicies.ops.example.com removed${NC}" || true

echo ""
echo "=================="
echo -e "${GREEN}✓ Cleanup complete!${NC}"