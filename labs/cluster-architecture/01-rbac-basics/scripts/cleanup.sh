#!/bin/bash
# Lab 01: RBAC Basics - Cleanup Script
# This script removes all resources created in the lab

set -e

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo ""
echo -e "${YELLOW}🧹 Lab 01: RBAC Basics - Cleanup${NC}"
echo -e "${YELLOW}================================${NC}"
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl not found${NC}"
    exit 1
fi

echo -e "${YELLOW}Deleting namespace 'dev' and all resources...${NC}"

if kubectl get namespace dev &> /dev/null; then
    kubectl delete namespace dev
    echo -e "${GREEN}✅ Namespace 'dev' deleted${NC}"
else
    echo -e "${YELLOW}⚠️  Namespace 'dev' not found (already cleaned up?)${NC}"
fi

echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}✅ Cleanup Complete!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""

echo "Verify cleanup:"
echo "  kubectl get namespace dev  # Should return 'not found'"
echo ""

echo "To re-run the lab:"
echo "  ./setup.sh"