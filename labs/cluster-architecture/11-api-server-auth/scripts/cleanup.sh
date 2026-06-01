#!/bin/bash
# Lab 11: API Server Authentication - Cleanup

set -e

echo "🧹 Lab 11: Cleanup"
echo "=================="
echo ""

GREEN='\033[0;32m'
NC='\033[0m'

NAMESPACE="lab11-auth"

kubectl delete csr dev-user 2>/dev/null && echo -e "${GREEN}✓ CSR removed${NC}" || true
kubectl delete namespace $NAMESPACE 2>/dev/null && echo -e "${GREEN}✓ Namespace $NAMESPACE removed${NC}" || true
rm -rf certs/ && echo -e "${GREEN}✓ Cert files removed${NC}" || true

echo ""
echo "=================="
echo -e "${GREEN}✓ Cleanup complete!${NC}"