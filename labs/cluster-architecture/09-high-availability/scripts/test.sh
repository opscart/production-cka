#!/bin/bash
# Lab 09: High Availability - Test Script

set -e

echo "🧪 Lab 09: High Availability Tests"
echo "==================================="
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

echo -e "${BLUE}=== Control Plane Components ===${NC}"
echo ""

run_check "etcd pod running" \
    "kubectl get pod -n kube-system -l component=etcd --no-headers | grep -q Running"

run_check "kube-apiserver running" \
    "kubectl get pod -n kube-system -l component=kube-apiserver --no-headers | grep -q Running"

run_check "kube-scheduler running" \
    "kubectl get pod -n kube-system -l component=kube-scheduler --no-headers | grep -q Running"

run_check "kube-controller-manager running" \
    "kubectl get pod -n kube-system -l component=kube-controller-manager --no-headers | grep -q Running"

echo ""
echo -e "${BLUE}=== Leader Election ===${NC}"
echo ""

run_check "kube-system leases exist" \
    "kubectl get lease -n kube-system --no-headers | grep -q ."

run_check "apiserver lease exists" \
    "kubectl get lease -n kube-system --no-headers | grep -q apiserver"

echo ""
echo -e "${BLUE}=== Workload HA ===${NC}"
echo ""

run_check "web-app deployment exists" \
    "kubectl get deployment web-app"

run_check "web-app has 3 replicas" \
    "kubectl get deployment web-app -o jsonpath='{.spec.replicas}' | grep -q 3"

run_check "PDB exists" \
    "kubectl get pdb web-app-pdb"

run_check "PDB minAvailable is 2" \
    "kubectl get pdb web-app-pdb -o jsonpath='{.spec.minAvailable}' | grep -q 2"

run_check "HA deployment exists" \
    "kubectl get deployment web-app-ha"

run_check "anti-affinity configured" \
    "kubectl get deployment web-app-ha -o jsonpath='{.spec.template.spec.affinity}' | grep -q podAntiAffinity"

echo ""
echo -e "${BLUE}=== API Health ===${NC}"
echo ""

run_check "API server healthy" \
    "kubectl get --raw='/healthz' | grep -q ok"

echo ""
echo "==================================="
echo -e "Results: ${passed}/${total} checks passed"
echo ""

if [ $passed -eq $total ]; then
    echo -e "${GREEN}🎉 All checks passed! Lab 09 complete!${NC}"
else
    echo -e "${RED}Some checks failed${NC}"
    echo ""
    echo "Debug:"
    kubectl get pods -n kube-system | grep -E "etcd|apiserver|scheduler|controller"
fi

echo ""
echo "Cleanup: ./scripts/cleanup.sh"