#!/bin/bash
# Lab 16: CSI Storage - Cleanup

set -e

echo "🧹 Lab 16: Cleanup"
echo "=================="
echo ""

GREEN='\033[0;32m'
NC='\033[0m'

NAMESPACE="lab16-storage"

# Delete namespace (removes PVCs and pods)
kubectl delete namespace $NAMESPACE 2>/dev/null && \
  echo -e "${GREEN}✓ Namespace $NAMESPACE removed${NC}" || true

# Delete PV manually (not namespace-scoped)
kubectl delete pv lab16-static-pv 2>/dev/null && \
  echo -e "${GREEN}✓ PV lab16-static-pv removed${NC}" || true

# Delete any dynamic PVs that were created
kubectl get pv --no-headers 2>/dev/null | \
  grep -v lab16-static-pv | \
  grep Released | \
  awk '{print $1}' | \
  xargs -r kubectl delete pv && \
  echo -e "${GREEN}✓ Released PVs removed${NC}" || true

echo ""
echo "Remaining PVs:"
kubectl get pv 2>/dev/null || true

echo ""
echo "=================="
echo -e "${GREEN}✓ Cleanup complete!${NC}"