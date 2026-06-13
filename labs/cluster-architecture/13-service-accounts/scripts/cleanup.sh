#!/bin/bash
# Lab 13: Service Accounts - Cleanup

set -e

echo "🧹 Lab 13: Cleanup"
echo "=================="
echo ""

GREEN='\033[0;32m'
NC='\033[0m'

NAMESPACE="lab13-sa"

kubectl delete namespace $NAMESPACE 2>/dev/null && \
  echo -e "${GREEN}✓ Namespace $NAMESPACE removed${NC}" || true

echo ""
echo "=================="
echo -e "${GREEN}✓ Cleanup complete!${NC}"