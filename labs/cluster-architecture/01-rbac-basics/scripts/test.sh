#!/bin/bash
# Lab 01: RBAC Basics - Test Script
# This script validates the RBAC configuration

set -e

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo -e "${BLUE}🧪 Lab 01: RBAC Basics - Validation Tests${NC}"
echo -e "${BLUE}===========================================${NC}"
echo ""

# Test counter
total_tests=0
passed_tests=0

# Function to run test
run_test() {
    local test_name="$1"
    local command="$2"
    local expected="$3"
    
    total_tests=$((total_tests + 1))
    
    echo -ne "${YELLOW}Test $total_tests: $test_name... ${NC}"
    
    result=$(eval "$command" 2>&1 || echo "no")
    
    if [[ "$result" == *"$expected"* ]]; then
        echo -e "${GREEN}✅ PASS${NC}"
        passed_tests=$((passed_tests + 1))
    else
        echo -e "${RED}❌ FAIL${NC}"
        echo -e "  Expected: $expected"
        echo -e "  Got: $result"
    fi
}

echo -e "${BLUE}=== Positive Tests (Should Succeed) ===${NC}"
echo ""

run_test "Can get pods" \
    "kubectl auth can-i get pods --as=system:serviceaccount:dev:dev-user -n dev" \
    "yes"

run_test "Can create pods" \
    "kubectl auth can-i create pods --as=system:serviceaccount:dev:dev-user -n dev" \
    "yes"

run_test "Can list deployments" \
    "kubectl auth can-i list deployments --as=system:serviceaccount:dev:dev-user -n dev" \
    "yes"

run_test "Can create deployments" \
    "kubectl auth can-i create deployments --as=system:serviceaccount:dev:dev-user -n dev" \
    "yes"

run_test "Can update deployments" \
    "kubectl auth can-i update deployments --as=system:serviceaccount:dev:dev-user -n dev" \
    "yes"

run_test "Can get pod logs" \
    "kubectl auth can-i get pods/log --as=system:serviceaccount:dev:dev-user -n dev" \
    "yes"

echo ""
echo -e "${BLUE}=== Negative Tests (Should Fail) ===${NC}"
echo ""

run_test "Cannot delete deployments" \
    "kubectl auth can-i delete deployments --as=system:serviceaccount:dev:dev-user -n dev" \
    "no"

run_test "Cannot get secrets" \
    "kubectl auth can-i get secrets --as=system:serviceaccount:dev:dev-user -n dev" \
    "no"

run_test "Cannot create secrets" \
    "kubectl auth can-i create secrets --as=system:serviceaccount:dev:dev-user -n dev" \
    "no"

run_test "Cannot access nodes" \
    "kubectl auth can-i get nodes --as=system:serviceaccount:dev:dev-user" \
    "no"

run_test "Cannot access default namespace" \
    "kubectl auth can-i get pods --as=system:serviceaccount:dev:dev-user -n default" \
    "no"

echo ""
echo -e "${BLUE}=== Resource Verification ===${NC}"
echo ""

# Check if resources exist
if kubectl get namespace dev &> /dev/null; then
    echo -e "${GREEN}✅ Namespace 'dev' exists${NC}"
    passed_tests=$((passed_tests + 1))
else
    echo -e "${RED}❌ Namespace 'dev' not found${NC}"
fi
total_tests=$((total_tests + 1))

if kubectl get sa dev-user -n dev &> /dev/null; then
    echo -e "${GREEN}✅ ServiceAccount 'dev-user' exists${NC}"
    passed_tests=$((passed_tests + 1))
else
    echo -e "${RED}❌ ServiceAccount 'dev-user' not found${NC}"
fi
total_tests=$((total_tests + 1))

if kubectl get role dev-role -n dev &> /dev/null; then
    echo -e "${GREEN}✅ Role 'dev-role' exists${NC}"
    passed_tests=$((passed_tests + 1))
else
    echo -e "${RED}❌ Role 'dev-role' not found${NC}"
fi
total_tests=$((total_tests + 1))

if kubectl get rolebinding dev-rolebinding -n dev &> /dev/null; then
    echo -e "${GREEN}✅ RoleBinding 'dev-rolebinding' exists${NC}"
    passed_tests=$((passed_tests + 1))
else
    echo -e "${RED}❌ RoleBinding 'dev-rolebinding' not found${NC}"
fi
total_tests=$((total_tests + 1))

echo ""
echo -e "${BLUE}===========================================${NC}"
echo -e "${BLUE}Test Results: $passed_tests/$total_tests passed${NC}"
echo -e "${BLUE}===========================================${NC}"
echo ""

if [ $passed_tests -eq $total_tests ]; then
    echo -e "${GREEN}🎉 All tests passed! Lab 01 completed successfully!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Review the RBAC configuration: kubectl describe role dev-role -n dev"
    echo "  2. Try the real-world test in the README"
    echo "  3. Proceed to Lab 02: RBAC Advanced"
    exit 0
else
    echo -e "${RED}❌ Some tests failed. Please review the setup.${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check if all resources exist: kubectl get all -n dev"
    echo "  2. Review role permissions: kubectl describe role dev-role -n dev"
    echo "  3. Check rolebinding: kubectl describe rolebinding dev-rolebinding -n dev"
    echo "  4. Re-run setup: ./setup.sh"
    exit 1
fi