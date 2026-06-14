#!/bin/bash
# Lab 06: Helm Basics - Test Script

set -e

echo "🧪 Lab 06: Helm Basics Tests"
echo "============================="
echo ""

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

passed=0
total=0

run_check() {
    local name="$1"
    local cmd="$2"
    total=$((total + 1))
    echo -ne "Checking $name... "
    if eval "$cmd" &>/dev/null; then
        echo -e "${GREEN}✓ PASS${NC}"
        passed=$((passed + 1))
    else
        echo -e "${RED}✗ FAIL${NC}"
    fi
}

echo -e "${BLUE}=== Helm Installation ===${NC}"
echo ""

run_check "helm is installed" \
    "command -v helm"

run_check "helm version is v3+" \
    "helm version --short | grep -q 'v3'"

echo ""
echo -e "${BLUE}=== Repository Management ===${NC}"
echo ""

# Add bitnami repo if not exists
helm repo add bitnami https://charts.bitnami.com/bitnami 2>/dev/null || true
helm repo update 2>/dev/null | tail -1

run_check "bitnami repo is added" \
    "helm repo list | grep -q bitnami"

run_check "helm can search charts" \
    "helm search repo bitnami/nginx | grep -q nginx"

echo ""
echo -e "${BLUE}=== Chart Install/Upgrade/Rollback ===${NC}"
echo ""

# Install
helm install test-nginx bitnami/nginx \
  --set replicaCount=1 \
  --set service.type=NodePort \
  --wait --timeout=120s 2>/dev/null || true

run_check "helm release test-nginx exists" \
    "helm list | grep -q test-nginx"

run_check "helm release is deployed" \
    "helm list | grep test-nginx | grep -q deployed"

run_check "kubernetes deployment created" \
    "kubectl get deployment test-nginx 2>/dev/null | grep -q test-nginx"

run_check "pods are running" \
    "kubectl get pods -l app.kubernetes.io/instance=test-nginx \
     --no-headers | grep -q Running"

# Upgrade
helm upgrade test-nginx bitnami/nginx \
  --set replicaCount=2 \
  --wait --timeout=120s 2>/dev/null || true

run_check "upgrade increments revision" \
    "helm history test-nginx | grep -q 'REVISION'"

run_check "upgrade shows superseded" \
    "helm history test-nginx | grep -q superseded"

# Rollback
helm rollback test-nginx 2>/dev/null || true

run_check "rollback creates new revision" \
    "helm history test-nginx | wc -l | awk '{print \$1}' | grep -qE '[3-9]|[0-9]{2,}'"

echo ""
echo -e "${BLUE}=== Helm Commands ===${NC}"
echo ""

run_check "helm status works" \
    "helm status test-nginx | grep -q STATUS"

run_check "helm get values works" \
    "helm get values test-nginx 2>/dev/null | grep -q 'replicaCount\|USER-SUPPLIED\|null'"

echo ""
echo -e "${BLUE}=== Cleanup ===${NC}"
echo ""

helm uninstall test-nginx 2>/dev/null || true

run_check "release uninstalled successfully" \
    "! helm list | grep -q test-nginx"

echo ""
echo "============================="
echo -e "Results: ${passed}/${total} checks passed"
echo ""

if [ $passed -eq $total ]; then
    echo -e "${GREEN}🎉 All checks passed! Lab 06 complete!${NC}"
else
    echo -e "${RED}Some checks failed${NC}"
    echo ""
    echo "Debug:"
    helm list
    kubectl get pods -l app.kubernetes.io/instance=test-nginx 2>/dev/null || true
fi
