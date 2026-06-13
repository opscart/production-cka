#!/bin/bash
# Lab 15: CNI Plugins - Test Script

set -e

echo "🧪 Lab 15: CNI Plugins Tests"
echo "=============================="
echo ""

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="lab15-cni"
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

echo -e "${BLUE}=== CNI Plugin ===${NC}"
echo ""

run_check "CNI plugin is running" \
    "kubectl get pods -n kube-system --no-headers | \
     grep -qE 'calico|flannel|weave|cilium|kindnet'"

run_check "CNI config exists on node" \
    "minikube ssh 'ls /etc/cni/net.d/' 2>/dev/null | grep -q '.conf'"

run_check "CNI binaries exist on node" \
    "minikube ssh 'ls /opt/cni/bin/' 2>/dev/null | grep -q ."

echo ""
echo -e "${BLUE}=== Node Network ===${NC}"
echo ""

run_check "nodes have pod CIDRs assigned" \
    "kubectl get nodes -o jsonpath='{.items[0].spec.podCIDR}' | grep -q ."

run_check "pod CIDRs are different per node" \
    "[ \$(kubectl get nodes -o jsonpath='{range .items[*]}{.spec.podCIDR}{\"\\n\"}{end}' | sort -u | wc -l) -gt 1 ]"

echo ""
echo -e "${BLUE}=== Pod Networking ===${NC}"
echo ""

run_check "pod-node1 exists" \
    "kubectl get pod pod-node1 -n $NAMESPACE"

run_check "pod-node2 exists" \
    "kubectl get pod pod-node2 -n $NAMESPACE"

run_check "pod-node1 has IP address" \
    "kubectl get pod pod-node1 -n $NAMESPACE \
     -o jsonpath='{.status.podIP}' | grep -q ."

run_check "pod-node2 has IP address" \
    "kubectl get pod pod-node2 -n $NAMESPACE \
     -o jsonpath='{.status.podIP}' | grep -q ."

run_check "pods are on different nodes" \
    "[ \$(kubectl get pods -n $NAMESPACE \
     -o jsonpath='{range .items[*]}{.spec.nodeName}{\"\\n\"}{end}' | \
     sort -u | wc -l) -gt 1 ]"

echo ""
echo -e "${BLUE}=== Pod-to-Pod Connectivity ===${NC}"
echo ""

POD2_IP=$(kubectl get pod pod-node2 -n $NAMESPACE \
  -o jsonpath='{.status.podIP}' 2>/dev/null)
POD1_IP=$(kubectl get pod pod-node1 -n $NAMESPACE \
  -o jsonpath='{.status.podIP}' 2>/dev/null)

run_check "pod-node1 can ping pod-node2 ($POD2_IP)" \
    "kubectl exec pod-node1 -n $NAMESPACE -- ping -c 2 -W 2 $POD2_IP"

run_check "pod-node2 can ping pod-node1 ($POD1_IP)" \
    "kubectl exec pod-node2 -n $NAMESPACE -- ping -c 2 -W 2 $POD1_IP"

echo ""
echo -e "${BLUE}=== DNS Resolution ===${NC}"
echo ""

run_check "DNS resolves kubernetes.default" \
    "kubectl exec pod-node1 -n $NAMESPACE -- \
     nslookup kubernetes.default.svc.cluster.local"

run_check "web-app service exists" \
    "kubectl get service web-app -n $NAMESPACE"

run_check "DNS resolves web-app service" \
    "kubectl exec pod-node1 -n $NAMESPACE -- \
     nslookup web-app.$NAMESPACE.svc.cluster.local"

run_check "pod can reach web-app via service DNS" \
    "kubectl exec pod-node1 -n $NAMESPACE -- \
     wget -q -O /dev/null --timeout=5 \
     http://web-app.$NAMESPACE.svc.cluster.local"

echo ""
echo "=============================="
echo -e "Results: ${passed}/${total} checks passed"
echo ""

if [ $passed -eq $total ]; then
    echo -e "${GREEN}🎉 All checks passed! Lab 15 complete!${NC}"
    echo ""
    echo "Pod network summary:"
    kubectl get pods -n $NAMESPACE -o wide
    echo ""
    echo "Node pod CIDRs:"
    kubectl get nodes -o \
      jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.podCIDR}{"\n"}{end}'
else
    echo -e "${RED}Some checks failed${NC}"
    echo ""
    echo "Debug:"
    kubectl get pods -n $NAMESPACE -o wide
    echo ""
    echo "CNI pods:"
    kubectl get pods -n kube-system | grep -E "calico|flannel|weave|cilium|kindnet"
fi

echo ""
echo "Cleanup: ./scripts/cleanup.sh"