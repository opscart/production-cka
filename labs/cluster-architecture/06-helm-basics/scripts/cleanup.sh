#!/bin/bash
# Lab 06: Helm Basics - Cleanup Script

set -e

echo "🧹 Lab 06: Cleanup"
echo "=================="
echo ""

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Removing Helm releases...${NC}"
echo ""

# List current releases
helm list

echo ""

# Uninstall demo release
if helm list | grep -q demo-nginx; then
    helm uninstall demo-nginx
    echo -e "${GREEN}✓ demo-nginx uninstalled${NC}"
fi

# Wait for cleanup
sleep 5

echo ""
echo "Remaining releases:"
helm list

echo ""
echo "=================="
echo -e "${GREEN}✓ Cleanup complete!${NC}"
