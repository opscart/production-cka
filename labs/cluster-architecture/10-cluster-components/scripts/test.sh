#!/bin/bash
# Lab 10: Cluster Components - Test Script

set -e

echo "🧪 Lab 10: Cluster Components Tests"
echo "===================================="
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

echo -e "${BLUE}=== Control Plane ===${NC}"
echo ""

run_check "kube-apiserver running" \
    "kubectl get pod -n kube-system -l component=kube-apiserver --no-headers | grep -q Running"

run_check "kube-scheduler running" \
    "kubectl get pod -n kube-system -l component=kube-scheduler --no-headers | grep -q Running"

run_check "kube-controller-manager running" \
    "kubectl get pod -n kube-system -l component=kube-controller-manager --no-headers | grep -q Running"

run_check "etcd running" \
    "kubectl get pod -n kube-system -l component=etcd --no-headers | grep -q Running"

echo ""
echo -e "${BLUE}=== Worker Node Components ===${NC}"
echo ""

run_check "kube-proxy daemonset exists" \
    "kubectl get daemonset kube-proxy -n kube-system"

run_check "kube-proxy pods running" \
    "kubectl get pods -n kube-system -l k8s-app=kube-proxy --no-headers | grep -q Running"

echo ""
echo -e "${BLUE}=== API Server ===${NC}"
echo ""

run_check "API server health" \
    "kubectl get --raw='/healthz' | grep -q ok"

run_check "API versions available" \
    "kubectl api-versions | grep -q apps"

run_check "API resources available" \
    "kubectl api-resources | grep -q deployments"

echo ""
echo -e "${BLUE}=== Scheduling ===${NC}"
echo ""

# Test scheduler by creating a pod
kubectl run sched-test --image=nginx --restart=Never 2>/dev/null || true
sleep 5

run_check "scheduler assigns pods" \
    "kubectl get pod sched-test -o jsonpath='{.spec.nodeName}' | grep -q opscart"

kubectl delete pod sched-test 2>/dev/null || true

echo ""
echo -e "${BLUE}=== Controllers ===${NC}"
echo ""

kubectl create deployment ctrl-test --image=nginx --replicas=2 2>/dev/null || true
sleep 5

run_check "deployment controller creates replicaset" \
    "kubectl get replicaset -l app=ctrl-test --no-headers | grep -q ctrl-test"

run_check "replicaset controller creates pods" \
    "kubectl get pods -l app=ctrl-test --no-headers | grep -q Running"

kubectl delete deployment ctrl-test 2>/dev/null || true

echo ""
echo "===================================="
echo -e "Results: ${passed}/${total} checks passed"
echo ""

if [ $passed -eq $total ]; then
    echo -e "${GREEN}🎉 All checks passed! Lab 10 complete!${NC}"
else
    echo -e "${RED}Some checks failed${NC}"
fi
