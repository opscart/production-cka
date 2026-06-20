#!/bin/bash
# Networking Lab 01: ClusterIP & NodePort - Cleanup

set -e

echo "🧹 Networking Lab 01: Cleanup"
echo "=============================="
echo ""

GREEN='\033[0;32m'
NC='\033[0m'

kubectl delete namespace lab01-services 2>/dev/null && \
  echo -e "${GREEN}✓ Namespace lab01-services removed${NC}" || true

echo ""
echo "=============================="
echo -e "${GREEN}✓ Cleanup complete!${NC}"