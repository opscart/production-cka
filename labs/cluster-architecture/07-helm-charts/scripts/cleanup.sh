#!/bin/bash
# Lab 07: Helm Charts - Cleanup Script

set -e

echo "🧹 Lab 07: Cleanup"
echo "=================="
echo ""

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Removing Helm releases...${NC}"
echo ""

# Uninstall all lab releases
for release in my-api my-frontend my-worker; do
    if helm list | grep -q "^$release"; then
        helm uninstall $release
        echo -e "${GREEN}✓ $release uninstalled${NC}"
    fi
done

echo ""
echo "Remaining releases:"
helm list

echo ""
echo "=================="
echo -e "${GREEN}✓ Cleanup complete!${NC}"