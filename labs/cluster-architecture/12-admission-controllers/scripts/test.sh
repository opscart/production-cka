#!/bin/bash
# Lab 12: Admission Controllers - Test Script

set -e

echo "🧪 Lab 12: Admission Controllers Tests"
echo "======================================="
echo ""

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="lab12-admission"
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
run_check "namespace lab12-admission exists" \
    "kubectl get namespace $NAMESPACE"

echo ""
echo -e "${BLUE}=== LimitRange ===${NC}"
echo ""

run_check "LimitRange exists" \
    "kubectl get limitrange default-limits -n $NAMESPACE"

run_check "LimitRange has container limits" \
    "kubectl get limitrange default-limits -n $NAMESPACE -o jsonpath='{.spec.limits[0].type}' | grep -q Container"

run_check "default CPU limit set" \
    "kubectl get limitrange default-limits -n $NAMESPACE -o jsonpath='{.spec.limits[0].default.cpu}' | grep -q 200m"

run_check "default memory limit set" \
    "kubectl get limitrange default-limits -n $NAMESPACE -o jsonpath='{.spec.limits[0].default.memory}' | grep -q 256Mi"

echo ""
echo -e "${BLUE}=== LimitRange Mutating Admission ===${NC}"
echo ""

run_check "no-limits-pod exists" \
    "kubectl get pod no-limits-pod -n $NAMESPACE"

run_check "LimitRange injected CPU limit into pod" \
    "kubectl get pod no-limits-pod -n $NAMESPACE -o jsonpath='{.spec.containers[0].resources.limits.cpu}' | grep -q ."

run_check "LimitRange injected memory limit into pod" \
    "kubectl get pod no-limits-pod -n $NAMESPACE -o jsonpath='{.spec.containers[0].resources.limits.memory}' | grep -q ."

run_check "injected CPU limit matches LimitRange default (200m)" \
    "kubectl get pod no-limits-pod -n $NAMESPACE -o jsonpath='{.spec.containers[0].resources.limits.cpu}' | grep -q 200m"

echo ""
echo -e "${BLUE}=== ResourceQuota ===${NC}"
echo ""

run_check "ResourceQuota exists" \
    "kubectl get resourcequota lab12-quota -n $NAMESPACE"

run_check "pod quota is 5" \
    "kubectl get resourcequota lab12-quota -n $NAMESPACE -o jsonpath='{.spec.hard.pods}' | grep -q 5"

run_check "CPU requests quota is 1" \
    "kubectl get resourcequota lab12-quota -n $NAMESPACE -o jsonpath='{.spec.hard.requests\.cpu}' | grep -q 1"

echo ""
echo -e "${BLUE}=== ResourceQuota Enforcement ===${NC}"
echo ""

# Try to exceed pod quota (5 max)
for i in 2 3 4 5; do
    kubectl run quota-test-$i --image=nginx -n $NAMESPACE 2>/dev/null || true
done

# Try to create 6th pod - should fail
QUOTA_RESULT=$(kubectl run quota-test-6 --image=nginx -n $NAMESPACE 2>&1 || true)

total=$((total + 1))
echo -ne "Checking quota rejects pod exceeding limit... "
if echo "$QUOTA_RESULT" | grep -qiE "exceeded quota|forbidden"; then
    echo -e "${GREEN}✓ PASS${NC} (Quota enforced!)"
    passed=$((passed + 1))
else
    echo -e "${RED}✗ FAIL${NC}"
    echo "  Output: $QUOTA_RESULT"
fi

echo ""
echo "======================================="
echo -e "Results: ${passed}/${total} checks passed"
echo ""

if [ $passed -eq $total ]; then
    echo -e "${GREEN}🎉 All checks passed! Lab 12 complete!${NC}"
    echo ""
    echo "Current quota usage:"
    kubectl describe resourcequota lab12-quota -n $NAMESPACE | \
      grep -A 20 "Resource"
else
    echo -e "${RED}Some checks failed${NC}"
    echo ""
    echo "Debug:"
    kubectl get limitrange,resourcequota -n $NAMESPACE
fi

echo ""
echo "Cleanup: ./scripts/cleanup.sh"