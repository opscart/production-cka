#!/bin/bash
# Lab 04: Cluster Upgrade - Test Script
# Tests drain/uncordon workflow (upgrade simulation)

set -e

echo "🧪 Lab 04: Cluster Upgrade Tests"
echo "=================================="
echo ""

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="lab04-upgrade"
NODE="opscart-m02"
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

echo -e "${YELLOW}NOTE: Version upgrade is conceptual on minikube.${NC}"
echo -e "${YELLOW}Testing drain/uncordon workflow (same on all clusters).${NC}"
echo ""

echo -e "${BLUE}=== Pre-Upgrade Checks ===${NC}"
echo ""

run_check "namespace lab04-upgrade exists" \
    "kubectl get namespace $NAMESPACE"

run_check "upgrade-test deployment exists" \
    "kubectl get deployment upgrade-test -n $NAMESPACE"

run_check "all 6 pods are running" \
    "kubectl get deployment upgrade-test -n $NAMESPACE \
     -o jsonpath='{.status.readyReplicas}' | grep -q 6"

run_check "all nodes are Ready" \
    "kubectl get nodes --no-headers | grep -c Ready | grep -q 3"

echo ""
echo -e "${BLUE}=== Upgrade Simulation (Drain/Uncordon) ===${NC}"
echo ""

echo "Simulating upgrade of worker node: $NODE"
echo ""

# Cordon
kubectl cordon $NODE
run_check "worker node cordoned" \
    "kubectl get node $NODE -o jsonpath='{.spec.unschedulable}' | grep -q true"

# Drain
kubectl drain $NODE \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --grace-period=10 \
  --timeout=60s 2>/dev/null || true

sleep 5

run_check "pods evicted from $NODE" \
    "! kubectl get pods -n $NAMESPACE -o wide --no-headers | grep -q $NODE"

run_check "deployment still available during drain" \
    "kubectl get deployment upgrade-test -n $NAMESPACE \
     -o jsonpath='{.status.availableReplicas}' | grep -qE '[1-9]'"

echo ""
echo "Simulating node upgrade complete..."
echo "(On real cluster: kubeadm upgrade node + kubelet restart here)"
sleep 2

# Uncordon
kubectl uncordon $NODE

echo "Waiting for node to be Ready..."
kubectl wait --for=condition=Ready node/$NODE --timeout=60s 2>/dev/null || true
sleep 5

NOT_READY=$(kubectl get nodes --no-headers | grep -v " Ready" | wc -l | tr -d ' ')
total=$((total + 1))
echo -ne "Checking all nodes Ready after uncordon... "
if [ "$NOT_READY" = "0" ]; then
    echo -e "${GREEN}✓ PASS${NC}"
    passed=$((passed + 1))
else
    echo -e "${RED}✗ FAIL${NC}"
fi

echo ""
echo "Waiting for pods to reschedule..."
kubectl wait --for=condition=available \
  deployment/upgrade-test \
  -n $NAMESPACE --timeout=60s 2>/dev/null || true

run_check "all pods running after uncordon" \
    "kubectl get deployment upgrade-test -n $NAMESPACE \
     -o jsonpath='{.status.readyReplicas}' | grep -q 6"

echo ""
echo -e "${BLUE}=== Version Check (conceptual) ===${NC}"
echo ""

run_check "kubelet version accessible" \
    "kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.kubeletVersion}' | grep -q v"

run_check "API server version accessible" \
    "kubectl version --short 2>/dev/null | grep -q 'Server Version' || \
     kubectl version 2>/dev/null | grep -q 'Server Version'"

echo ""
echo "=================================="
echo -e "Results: ${passed}/${total} checks passed"
echo ""

if [ $passed -eq $total ]; then
    echo -e "${GREEN}🎉 All checks passed! Lab 04 complete!${NC}"
    echo ""
    echo "Node versions:"
    kubectl get nodes -o custom-columns=\
"NAME:.metadata.name,VERSION:.status.nodeInfo.kubeletVersion"
    echo ""
    echo "For real upgrade on kubeadm:"
    echo "  kubeadm upgrade plan"
    echo "  kubeadm upgrade apply v1.XX.0"
else
    echo -e "${RED}Some checks failed${NC}"
    kubectl get nodes
    kubectl get pods -n $NAMESPACE -o wide
    echo ""
    echo "Ensure node is uncordoned: kubectl uncordon $NODE"
fi

echo ""
echo "Cleanup: ./scripts/cleanup.sh"
