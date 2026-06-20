#!/bin/bash
# Networking Lab 02: LoadBalancer & Headless Services - Cleanup

set -e

echo "🧹 Networking Lab 02: Cleanup"
echo "==============================="
echo ""

GREEN='\033[0;32m'
NC='\033[0m'

# StatefulSets sometimes need PVC cleanup too, though this lab uses no PVCs
kubectl delete namespace lab02-services 2>/dev/null && \
  echo -e "${GREEN}✓ Namespace lab02-services removed${NC}" || true

echo ""
echo "==============================="
echo -e "${GREEN}✓ Cleanup complete!${NC}"