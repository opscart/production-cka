#!/bin/bash
# Lab 14: CRDs and Operators - Test Script

set -e

echo "🧪 Lab 14: CRDs and Operators Tests"
echo "====================================="
echo ""

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="lab14-crds"
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
run_check "namespace lab14-crds exists" \
    "kubectl get namespace $NAMESPACE"

echo ""
echo -e "${BLUE}=== CRD Registration ===${NC}"
echo ""

run_check "BackupPolicy CRD exists" \
    "kubectl get crd backuppolicies.ops.example.com"

run_check "CRD is established" \
    "kubectl get crd backuppolicies.ops.example.com \
     -o jsonpath='{.status.conditions[?(@.type==\"Established\")].status}' \
     | grep -q True"

run_check "CRD group is ops.example.com" \
    "kubectl get crd backuppolicies.ops.example.com \
     -o jsonpath='{.spec.group}' | grep -q ops.example.com"

run_check "CRD is Namespaced" \
    "kubectl get crd backuppolicies.ops.example.com \
     -o jsonpath='{.spec.scope}' | grep -q Namespaced"

run_check "CRD has short name 'bp'" \
    "kubectl get crd backuppolicies.ops.example.com \
     -o jsonpath='{.spec.names.shortNames[0]}' | grep -q bp"

run_check "CRD accessible via api-resources" \
    "kubectl api-resources | grep -q backuppolic"

echo ""
echo -e "${BLUE}=== Custom Resources ===${NC}"
echo ""

run_check "database-backup exists" \
    "kubectl get backuppolicy database-backup -n $NAMESPACE"

run_check "database-backup has correct schedule" \
    "kubectl get backuppolicy database-backup -n $NAMESPACE \
     -o jsonpath='{.spec.schedule}' | grep -q '0 2'"

run_check "database-backup retentionDays is 30" \
    "kubectl get backuppolicy database-backup -n $NAMESPACE \
     -o jsonpath='{.spec.retentionDays}' | grep -q 30"

run_check "config-backup exists" \
    "kubectl get backuppolicy config-backup -n $NAMESPACE"

run_check "short name 'bp' works" \
    "kubectl get bp -n $NAMESPACE --no-headers | grep -q backup"

echo ""
echo -e "${BLUE}=== CRD Validation ===${NC}"
echo ""

# Test schema validation - invalid retentionDays should fail
INVALID_RESULT=$(kubectl apply -f - 2>&1 << 'EOF' || true
apiVersion: ops.example.com/v1
kind: BackupPolicy
metadata:
  name: invalid-backup
  namespace: lab14-crds
spec:
  schedule: "0 2 * * *"
  retentionDays: -1
  target: "test"
EOF
)

total=$((total + 1))
echo -ne "Checking CRD validates retentionDays minimum... "
if echo "$INVALID_RESULT" | grep -qiE "invalid|minimum|validation"; then
    echo -e "${GREEN}✓ PASS${NC} (Schema validation works!)"
    passed=$((passed + 1))
else
    echo -e "${RED}✗ FAIL${NC}"
    echo "  Output: $INVALID_RESULT"
fi

# Test missing required field should fail
MISSING_RESULT=$(kubectl apply -f - 2>&1 << 'EOF' || true
apiVersion: ops.example.com/v1
kind: BackupPolicy
metadata:
  name: missing-fields
  namespace: lab14-crds
spec:
  target: "test"
EOF
)

total=$((total + 1))
echo -ne "Checking CRD validates required fields... "
if echo "$MISSING_RESULT" | grep -qiE "required|invalid|validation"; then
    echo -e "${GREEN}✓ PASS${NC} (Required field validation works!)"
    passed=$((passed + 1))
else
    echo -e "${RED}✗ FAIL${NC}"
fi

echo ""
echo "====================================="
echo -e "Results: ${passed}/${total} checks passed"
echo ""

if [ $passed -eq $total ]; then
    echo -e "${GREEN}🎉 All checks passed! Lab 14 complete!${NC}"
    echo ""
    echo "Custom resources:"
    kubectl get bp -n $NAMESPACE
else
    echo -e "${RED}Some checks failed${NC}"
    echo ""
    echo "Debug:"
    kubectl get crd | grep example
    kubectl get bp -n $NAMESPACE 2>/dev/null || true
fi

echo ""
echo "Cleanup: ./scripts/cleanup.sh"