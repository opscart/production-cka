#!/bin/bash
# Lab 15: CNI Plugins - Cleanup

set -e

echo "🧹 Lab 15: Cleanup"
echo "=================="
echo ""

GREEN='\033[0;32m'
NC='\033[0m'

kubectl delete namespace lab15-cni 2>/dev/null && \
  echo -e "${GREEN}✓ Namespace lab15-cni removed${NC}" || true

echo ""
echo "=================="
echo -e "${GREEN}✓ Cleanup complete!${NC}"