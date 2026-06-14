#!/bin/bash
# Lab 17: CRI Container Runtimes - Test Script

set -e

echo "🧪 Lab 17: CRI Runtimes Tests"
echo "=============================="
echo ""

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="lab17-cri"
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

echo -e "${BLUE}=== Runtime Identification ===${NC}"
echo ""

run_check "nodes have container runtime info" \
    "kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.containerRuntimeVersion}' | grep -q ."

run_check "runtime version is detectable" \
    "kubectl get nodes -o wide --no-headers | grep -qE 'docker|containerd|crio'"

echo ""
echo "Runtime versions:"
kubectl get nodes -o \
  jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.nodeInfo.containerRuntimeVersion}{"\n"}{end}'
echo ""

echo -e "${BLUE}=== Node Runtime Info ===${NC}"
echo ""

run_check "kernel version available" \
    "kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.kernelVersion}' | grep -q ."

run_check "OS image available" \
    "kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.osImage}' | grep -q ."

run_check "container runtime version available" \
    "kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.containerRuntimeVersion}' | grep -q ."

echo ""
echo -e "${BLUE}=== CRI Runtime on Node ===${NC}"
echo ""

run_check "crictl available on node" \
    "minikube ssh -- 'which crictl || sudo crictl --version' 2>/dev/null"

run_check "crictl can list containers" \
    "minikube ssh -- 'sudo crictl ps' 2>/dev/null | grep -q ."

run_check "crictl can list images" \
    "minikube ssh -- 'sudo crictl images' 2>/dev/null | grep -q ."

run_check "crictl can list pods" \
    "minikube ssh -- 'sudo crictl pods' 2>/dev/null | grep -q ."

echo ""
echo -e "${BLUE}=== Test Pod ===${NC}"
echo ""

run_check "namespace lab17-cri exists" \
    "kubectl get namespace $NAMESPACE"

run_check "cri-test-pod exists" \
    "kubectl get pod cri-test-pod -n $NAMESPACE"

run_check "cri-test-pod is Running" \
    "kubectl get pod cri-test-pod -n $NAMESPACE \
     -o jsonpath='{.status.phase}' | grep -q Running"

run_check "pod has container runtime assigned" \
    "kubectl get pod cri-test-pod -n $NAMESPACE \
     -o jsonpath='{.spec.nodeName}' | grep -q ."

echo ""
echo -e "${BLUE}=== Container Visible via crictl ===${NC}"
echo ""

NODE=$(kubectl get pod cri-test-pod -n $NAMESPACE \
  -o jsonpath='{.spec.nodeName}' 2>/dev/null)

run_check "nginx container visible via crictl on node" \
    "minikube ssh -n $NODE -- 'sudo crictl ps' 2>/dev/null | grep -q nginx"

echo ""
echo "=============================="
echo -e "Results: ${passed}/${total} checks passed"
echo ""

if [ $passed -eq $total ]; then
    echo -e "${GREEN}🎉 All checks passed! Lab 17 complete!${NC}"
    echo ""
    echo "Runtime summary:"
    kubectl get nodes -o custom-columns=\
"NAME:.metadata.name,RUNTIME:.status.nodeInfo.containerRuntimeVersion,OS:.status.nodeInfo.osImage"
else
    echo -e "${RED}Some checks failed${NC}"
    echo ""
    echo "Debug:"
    kubectl get nodes -o wide
fi

echo ""
echo "Cleanup: ./scripts/cleanup.sh"