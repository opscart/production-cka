#!/bin/bash
# Lab 09: High Availability - Cleanup

set -e

echo "🧹 Lab 09: Cleanup"
echo "=================="
echo ""

GREEN='\033[0;32m'
NC='\033[0m'

kubectl delete deployment web-app web-app-ha 2>/dev/null && \
  echo -e "${GREEN}✓ Deployments removed${NC}" || true

kubectl delete pdb web-app-pdb 2>/dev/null && \
  echo -e "${GREEN}✓ PDB removed${NC}" || true

echo ""
echo "=================="
echo -e "${GREEN}✓ Cleanup complete!${NC}"
