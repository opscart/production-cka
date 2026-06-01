#!/bin/bash
# Lab 12: Admission Controllers - Cleanup

set -e

echo "🧹 Lab 12: Cleanup"
echo "=================="
echo ""

GREEN='\033[0;32m'
NC='\033[0m'

NAMESPACE="lab12-admission"

kubectl delete namespace $NAMESPACE 2>/dev/null && \
  echo -e "${GREEN}✓ Namespace $NAMESPACE removed${NC}" || true

# Clean up ValidatingAdmissionPolicy if created
kubectl delete validatingadmissionpolicy require-resource-limits 2>/dev/null && \
  echo -e "${GREEN}✓ ValidatingAdmissionPolicy removed${NC}" || true

kubectl delete validatingadmissionpolicybinding require-resource-limits-binding 2>/dev/null && \
  echo -e "${GREEN}✓ ValidatingAdmissionPolicyBinding removed${NC}" || true

echo ""
echo "=================="
echo -e "${GREEN}✓ Cleanup complete!${NC}"