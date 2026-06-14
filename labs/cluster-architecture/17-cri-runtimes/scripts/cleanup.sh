#!/bin/bash
# Lab 17: CRI Container Runtimes - Cleanup

set -e

echo "🧹 Lab 17: Cleanup"
echo "=================="
echo ""

GREEN='\033[0;32m'
NC='\033[0m'

kubectl delete namespace lab17-cri 2>/dev/null && \
  echo -e "${GREEN}✓ Namespace lab17-cri removed${NC}" || true

echo ""
echo "=================="
echo -e "${GREEN}✓ Cleanup complete!${NC}"