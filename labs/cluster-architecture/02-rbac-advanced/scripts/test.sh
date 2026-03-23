#!/bin/bash
# Lab 02: RBAC Advanced - Test Script

set -e

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo -e "${BLUE}🧪 Lab 02: RBAC Advanced - Validation Tests${NC}"
echo -e "${BLUE}=============================================${NC}"
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

echo -e "${BLUE}=== Platform Admin Tests ===${NC}"
echo ""

run_test "Platform admin can get nodes" \
    "kubectl auth can-i get nodes --as=system:serviceaccount:kube-system:platform-admin" \
    "yes"

run_test "Platform admin can delete namespaces" \
    "kubectl auth can-i delete namespaces --as=system:serviceaccount:kube-system:platform-admin" \
    "yes"

run_test "Platform admin has wildcard permissions" \
    "kubectl auth can-i '*' '*' --as=system:serviceaccount:kube-system:platform-admin" \
    "yes"

echo ""
echo -e "${BLUE}=== Security Viewer Tests ===${NC}"
echo ""

run_test "Security viewer can get pods cluster-wide" \
    "kubectl auth can-i get pods --all-namespaces --as=system:serviceaccount:kube-system:security-viewer" \
    "yes"

run_test "Security viewer can get secrets" \
    "kubectl auth can-i get secrets -n prod --as=system:serviceaccount:kube-system:security-viewer" \
    "yes"

run_test "Security viewer can get nodes" \
    "kubectl auth can-i get nodes --as=system:serviceaccount:kube-system:security-viewer" \
    "yes"

run_test "Security viewer cannot create pods" \
    "kubectl auth can-i create pods --as=system:serviceaccount:kube-system:security-viewer" \
    "no"

run_test "Security viewer cannot delete deployments" \
    "kubectl auth can-i delete deployments -n prod --as=system:serviceaccount:kube-system:security-viewer" \
    "no"

echo ""
echo -e "${BLUE}=== Node Reader Tests ===${NC}"
echo ""

run_test "Developer can get nodes" \
    "kubectl auth can-i get nodes --as=system:serviceaccount:prod:developer" \
    "yes"

run_test "Developer cannot get pods in prod" \
    "kubectl auth can-i get pods -n prod --as=system:serviceaccount:prod:developer" \
    "no"

run_test "Developer cannot get namespaces" \
    "kubectl auth can-i get namespaces --as=system:serviceaccount:prod:developer" \
    "no"

echo ""
echo -e "${BLUE}=== Monitoring Aggregated Tests ===${NC}"
echo ""

run_test "Monitoring user can get pods" \
    "kubectl auth can-i get pods --all-namespaces --as=system:serviceaccount:kube-system:monitoring-user" \
    "yes"

run_test "Monitoring user can get pod logs" \
    "kubectl auth can-i get pods/log --all-namespaces --as=system:serviceaccount:kube-system:monitoring-user" \
    "yes"

run_test "Monitoring user can get events" \
    "kubectl auth can-i get events --all-namespaces --as=system:serviceaccount:kube-system:monitoring-user" \
    "yes"

run_test "Monitoring user cannot create pods" \
    "kubectl auth can-i create pods --as=system:serviceaccount:kube-system:monitoring-user" \
    "no"

echo ""
echo -e "${BLUE}=== Resource Verification ===${NC}"
echo ""

# Check ClusterRoles
if kubectl get clusterrole platform-admin &> /dev/null; then
    echo -e "${GREEN}✅ ClusterRole 'platform-admin' exists${NC}"
    passed_tests=$((passed_tests + 1))
else
    echo -e "${RED}❌ ClusterRole 'platform-admin' not found${NC}"
fi
total_tests=$((total_tests + 1))

if kubectl get clusterrole security-viewer &> /dev/null; then
    echo -e "${GREEN}✅ ClusterRole 'security-viewer' exists${NC}"
    passed_tests=$((passed_tests + 1))
else
    echo -e "${RED}❌ ClusterRole 'security-viewer' not found${NC}"
fi
total_tests=$((total_tests + 1))

if kubectl get clusterrole node-reader &> /dev/null; then
    echo -e "${GREEN}✅ ClusterRole 'node-reader' exists${NC}"
    passed_tests=$((passed_tests + 1))
else
    echo -e "${RED}❌ ClusterRole 'node-reader' not found${NC}"
fi
total_tests=$((total_tests + 1))

if kubectl get clusterrole monitoring-aggregated &> /dev/null; then
    echo -e "${GREEN}✅ ClusterRole 'monitoring-aggregated' exists${NC}"
    passed_tests=$((passed_tests + 1))
else
    echo -e "${RED}❌ ClusterRole 'monitoring-aggregated' not found${NC}"
fi
total_tests=$((total_tests + 1))

# Check ClusterRoleBindings
if kubectl get clusterrolebinding platform-admin-binding &> /dev/null; then
    echo -e "${GREEN}✅ ClusterRoleBinding 'platform-admin-binding' exists${NC}"
    passed_tests=$((passed_tests + 1))
else
    echo -e "${RED}❌ ClusterRoleBinding 'platform-admin-binding' not found${NC}"
fi
total_tests=$((total_tests + 1))

if kubectl get clusterrolebinding security-viewer-binding &> /dev/null; then
    echo -e "${GREEN}✅ ClusterRoleBinding 'security-viewer-binding' exists${NC}"
    passed_tests=$((passed_tests + 1))
else
    echo -e "${RED}❌ ClusterRoleBinding 'security-viewer-binding' not found${NC}"
fi
total_tests=$((total_tests + 1))

# Check ClusterRoleBinding (node-reader uses ClusterRoleBinding!)
if kubectl get clusterrolebinding developer-node-reader &> /dev/null; then
    echo -e "${GREEN}✅ ClusterRoleBinding 'developer-node-reader' exists${NC}"
    passed_tests=$((passed_tests + 1))
else
    echo -e "${RED}❌ ClusterRoleBinding 'developer-node-reader' not found${NC}"
fi
total_tests=$((total_tests + 1))

# Check Service Accounts
if kubectl get sa platform-admin -n kube-system &> /dev/null; then
    echo -e "${GREEN}✅ ServiceAccount 'platform-admin' exists${NC}"
    passed_tests=$((passed_tests + 1))
else
    echo -e "${RED}❌ ServiceAccount 'platform-admin' not found${NC}"
fi
total_tests=$((total_tests + 1))

if kubectl get sa developer -n prod &> /dev/null; then
    echo -e "${GREEN}✅ ServiceAccount 'developer' exists${NC}"
    passed_tests=$((passed_tests + 1))
else
    echo -e "${RED}❌ ServiceAccount 'developer' not found${NC}"
fi
total_tests=$((total_tests + 1))

echo ""
echo -e "${BLUE}=============================================${NC}"
echo -e "${BLUE}Test Results: $passed_tests/$total_tests passed${NC}"
echo -e "${BLUE}=============================================${NC}"
echo ""

if [ $passed_tests -eq $total_tests ]; then
    echo -e "${GREEN}🎉 All tests passed! Lab 02 completed successfully!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Review aggregated ClusterRole: kubectl describe clusterrole monitoring-aggregated"
    echo "  2. Compare with Lab 01 namespace-scoped RBAC"
    echo "  3. Proceed to Lab 03: kubeadm Cluster Installation"
    exit 0
else
    echo -e "${RED}❌ Some tests failed. Please review the setup.${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check ClusterRoles: kubectl get clusterrole"
    echo "  2. Check ClusterRoleBindings: kubectl get clusterrolebinding"
    echo "  3. Re-run setup: ./scripts/setup.sh"
    exit 1
fi