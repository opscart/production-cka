#!/bin/bash
# Lab 10: Cluster Components - Cleanup

set -e

echo "🧹 Lab 10: Cleanup"
echo "=================="
echo ""

GREEN='\033[0;32m'
NC='\033[0m'

kubectl delete deployment ctrl-test 2>/dev/null && echo "✓ ctrl-test removed" || true
kubectl delete pod sched-test 2>/dev/null && echo "✓ sched-test removed" || true

echo ""
echo "=================="
echo -e "${GREEN}✓ Cleanup complete!${NC}"
