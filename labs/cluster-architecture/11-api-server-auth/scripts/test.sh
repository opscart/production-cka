#!/bin/bash
# Lab 11: API Server Authentication - Test Script

set -e

echo "🧪 Lab 11: Authentication Tests"
echo "================================"
echo ""

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="lab11-auth"
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

echo -e "${BLUE}=== Certificate Files ===${NC}"
echo ""

run_check "private key exists" "test -f certs/dev-user.key"
run_check "CSR file exists" "test -f certs/dev-user.csr"
run_check "signed certificate exists" "test -f certs/dev-user.crt"
run_check "CA certificate exists and non-empty" "test -s certs/ca.crt"
run_check "kubeconfig exists" "test -f certs/dev-user.kubeconfig"

echo ""
echo -e "${BLUE}=== Certificate Validity ===${NC}"
echo ""

run_check "private key is valid RSA" \
    "openssl rsa -in certs/dev-user.key -check -noout 2>/dev/null"

run_check "certificate is valid" \
    "openssl x509 -in certs/dev-user.crt -noout 2>/dev/null"

run_check "certificate CN is dev-user" \
    "openssl x509 -in certs/dev-user.crt -noout -subject | grep -q 'CN.*dev-user'"

run_check "certificate O is dev-team" \
    "openssl x509 -in certs/dev-user.crt -noout -subject | grep -q 'dev-team'"

echo ""
echo -e "${BLUE}=== Kubernetes CSR ===${NC}"
echo ""

run_check "CSR approved" \
    "kubectl get csr dev-user -o jsonpath='{.status.conditions[0].type}' | grep -q Approved"

run_check "certificate issued" \
    "kubectl get csr dev-user -o jsonpath='{.status.certificate}' | grep -q ."

echo ""
echo -e "${BLUE}=== Namespace & Service Account ===${NC}"
echo ""

run_check "namespace $NAMESPACE exists" \
    "kubectl get namespace $NAMESPACE"

run_check "service account auth-demo-sa exists" \
    "kubectl get serviceaccount auth-demo-sa -n $NAMESPACE"

run_check "auth-demo-pod exists" \
    "kubectl get pod auth-demo-pod -n $NAMESPACE"

run_check "pod uses correct service account" \
    "kubectl get pod auth-demo-pod -n $NAMESPACE -o jsonpath='{.spec.serviceAccountName}' | grep -q auth-demo-sa"

run_check "service account token mounted in pod" \
    "kubectl exec auth-demo-pod -n $NAMESPACE -- ls /var/run/secrets/kubernetes.io/serviceaccount/token"

echo ""
echo -e "${BLUE}=== Authentication Test ===${NC}"
echo ""

# Test: dev-user can connect but gets Forbidden (not connection error)
AUTH_RESULT=$(kubectl get pods --kubeconfig=certs/dev-user.kubeconfig -n $NAMESPACE 2>&1 || true)

total=$((total + 1))
echo -ne "Checking dev-user authenticates successfully... "
if echo "$AUTH_RESULT" | grep -qiE "forbidden|cannot|pods is forbidden"; then
    echo -e "${GREEN}✓ PASS${NC} (Forbidden = authenticated!)"
    passed=$((passed + 1))
elif echo "$AUTH_RESULT" | grep -qiE "no such host|connection refused|tls|timeout"; then
    echo -e "${RED}✗ FAIL${NC} (Connection error - kubeconfig issue)"
    echo "  Error: $AUTH_RESULT" | head -2
else
    echo -e "${RED}✗ FAIL${NC}"
    echo "  Output: $AUTH_RESULT" | head -2
fi

echo ""
echo "================================"
echo -e "Results: ${passed}/${total} checks passed"
echo ""

if [ $passed -eq $total ]; then
    echo -e "${GREEN}🎉 All checks passed! Lab 11 complete!${NC}"
    echo ""
    echo "Certificate details:"
    openssl x509 -in certs/dev-user.crt -noout -subject -dates
else
    echo -e "${RED}Some checks failed${NC}"
    echo ""
    echo "Debug:"
    echo "CA cert size: $(wc -c < certs/ca.crt 2>/dev/null || echo 'missing') bytes"
    echo "Server: $(kubectl config view -o jsonpath='{.clusters[?(@.name==\"opscart\")].cluster.server}')"
fi

echo ""
echo "Cleanup: ./scripts/cleanup.sh"