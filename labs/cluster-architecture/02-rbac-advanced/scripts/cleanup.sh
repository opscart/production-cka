#!/bin/bash
# Lab 02: RBAC Advanced - Cleanup Script

set -e

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo ""
echo -e "${YELLOW}🧹 Lab 02: RBAC Advanced - Cleanup${NC}"
echo -e "${YELLOW}===================================${NC}"
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl not found${NC}"
    exit 1
fi

echo -e "${YELLOW}Deleting namespaces...${NC}"
kubectl delete namespace prod --ignore-not-found=true
kubectl delete namespace staging --ignore-not-found=true
echo -e "${GREEN}✅ Namespaces deleted${NC}"
echo ""

echo -e "${YELLOW}Deleting service accounts...${NC}"
kubectl delete sa platform-admin -n kube-system --ignore-not-found=true
kubectl delete sa security-viewer -n kube-system --ignore-not-found=true
kubectl delete sa monitoring-user -n kube-system --ignore-not-found=true
echo -e "${GREEN}✅ Service accounts deleted${NC}"
echo ""

echo -e "${YELLOW}Deleting ClusterRoles...${NC}"
kubectl delete clusterrole platform-admin --ignore-not-found=true
kubectl delete clusterrole security-viewer --ignore-not-found=true
kubectl delete clusterrole node-reader --ignore-not-found=true
kubectl delete clusterrole monitoring-aggregated --ignore-not-found=true
kubectl delete clusterrole monitoring-metrics --ignore-not-found=true
kubectl delete clusterrole monitoring-logs --ignore-not-found=true
kubectl delete clusterrole monitoring-events --ignore-not-found=true
echo -e "${GREEN}✅ ClusterRoles deleted${NC}"
echo ""

echo -e "${YELLOW}Deleting ClusterRoleBindings...${NC}"
kubectl delete clusterrolebinding platform-admin-binding --ignore-not-found=true
kubectl delete clusterrolebinding security-viewer-binding --ignore-not-found=true
kubectl delete clusterrolebinding monitoring-user-binding --ignore-not-found=true
echo -e "${GREEN}✅ ClusterRoleBindings deleted${NC}"
echo ""

echo -e "${GREEN}===================================${NC}"
echo -e "${GREEN}✅ Cleanup Complete!${NC}"
echo -e "${GREEN}===================================${NC}"
echo ""

echo "Verify cleanup:"
echo "  kubectl get clusterrole | grep -E 'platform|security|node-reader|monitoring'"
echo "  kubectl get clusterrolebinding | grep -E 'platform|security|monitoring'"
echo "  kubectl get namespace prod  # Should return 'not found'"
echo ""

echo "To re-run the lab:"
echo "  ./scripts/setup.sh"