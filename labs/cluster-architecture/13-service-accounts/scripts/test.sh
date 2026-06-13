#!/bin/bash
# Lab 13: Service Accounts - Test Script

set -e

echo "🧪 Lab 13: Service Accounts Tests"
echo "=================================="
echo ""

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="lab13-sa"
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

echo -e "${BLUE}=== Namespace ===${NC}"
echo ""
run_check "namespace lab13-sa exists" \
    "kubectl get namespace $NAMESPACE"

echo ""
echo -e "${BLUE}=== Service Accounts ===${NC}"
echo ""

run_check "monitoring-sa exists" \
    "kubectl get serviceaccount monitoring-sa -n $NAMESPACE"

run_check "restricted-sa exists" \
    "kubectl get serviceaccount restricted-sa -n $NAMESPACE"

run_check "restricted-sa has automount disabled" \
    "kubectl get serviceaccount restricted-sa -n $NAMESPACE \
     -o jsonpath='{.automountServiceAccountToken}' | grep -q false"

run_check "default SA exists in namespace" \
    "kubectl get serviceaccount default -n $NAMESPACE"

echo ""
echo -e "${BLUE}=== RBAC ===${NC}"
echo ""

run_check "monitoring-role exists" \
    "kubectl get role monitoring-role -n $NAMESPACE"

run_check "monitoring-role has pod list permission" \
    "kubectl get role monitoring-role -n $NAMESPACE \
     -o jsonpath='{.rules[0].verbs}' | grep -q list"

run_check "monitoring-rolebinding exists" \
    "kubectl get rolebinding monitoring-rolebinding -n $NAMESPACE"

run_check "rolebinding references monitoring-sa" \
    "kubectl get rolebinding monitoring-rolebinding -n $NAMESPACE \
     -o jsonpath='{.subjects[0].name}' | grep -q monitoring-sa"

echo ""
echo -e "${BLUE}=== Pods ===${NC}"
echo ""

run_check "monitoring-pod exists" \
    "kubectl get pod monitoring-pod -n $NAMESPACE"

run_check "monitoring-pod uses monitoring-sa" \
    "kubectl get pod monitoring-pod -n $NAMESPACE \
     -o jsonpath='{.spec.serviceAccountName}' | grep -q monitoring-sa"

run_check "monitoring-pod has token mounted" \
    "kubectl exec monitoring-pod -n $NAMESPACE -- \
     ls /var/run/secrets/kubernetes.io/serviceaccount/token"

run_check "restricted-pod exists" \
    "kubectl get pod restricted-pod -n $NAMESPACE"

run_check "restricted-pod uses restricted-sa" \
    "kubectl get pod restricted-pod -n $NAMESPACE \
     -o jsonpath='{.spec.serviceAccountName}' | grep -q restricted-sa"

echo ""
echo -e "${BLUE}=== SA Permissions ===${NC}"
echo ""

run_check "monitoring-sa can list pods" \
    "kubectl auth can-i list pods \
     --as=system:serviceaccount:$NAMESPACE:monitoring-sa \
     -n $NAMESPACE"

run_check "monitoring-sa can list services" \
    "kubectl auth can-i list services \
     --as=system:serviceaccount:$NAMESPACE:monitoring-sa \
     -n $NAMESPACE"

run_check "monitoring-sa cannot delete pods" \
    "! kubectl auth can-i delete pods \
     --as=system:serviceaccount:$NAMESPACE:monitoring-sa \
     -n $NAMESPACE"

run_check "monitoring-sa cannot list secrets" \
    "! kubectl auth can-i list secrets \
     --as=system:serviceaccount:$NAMESPACE:monitoring-sa \
     -n $NAMESPACE"

echo ""
echo -e "${BLUE}=== Token Generation ===${NC}"
echo ""

run_check "can generate token for monitoring-sa" \
    "kubectl create token monitoring-sa -n $NAMESPACE"

echo ""
echo "=================================="
echo -e "Results: ${passed}/${total} checks passed"
echo ""

if [ $passed -eq $total ]; then
    echo -e "${GREEN}🎉 All checks passed! Lab 13 complete!${NC}"
    echo ""
    echo "Service accounts in $NAMESPACE:"
    kubectl get serviceaccount -n $NAMESPACE
else
    echo -e "${RED}Some checks failed${NC}"
    echo ""
    echo "Debug:"
    kubectl get sa,role,rolebinding,pod -n $NAMESPACE
fi

echo ""
echo "Cleanup: ./scripts/cleanup.sh"