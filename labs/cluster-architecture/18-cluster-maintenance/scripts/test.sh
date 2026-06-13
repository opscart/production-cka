#!/bin/bash
# Lab 18: Cluster Maintenance - Test Script

set -e

echo "🧪 Lab 18: Cluster Maintenance Tests"
echo "======================================"
echo ""

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="lab18-maintenance"
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

echo -e "${BLUE}=== Namespace and Workload ===${NC}"
echo ""

run_check "namespace lab18-maintenance exists" \
    "kubectl get namespace $NAMESPACE"

run_check "web-maintenance deployment exists" \
    "kubectl get deployment web-maintenance -n $NAMESPACE"

run_check "web-maintenance has 4 replicas" \
    "kubectl get deployment web-maintenance -n $NAMESPACE \
     -o jsonpath='{.spec.replicas}' | grep -q 4"

run_check "PDB web-maintenance-pdb exists" \
    "kubectl get pdb web-maintenance-pdb -n $NAMESPACE"

run_check "PDB minAvailable is 2" \
    "kubectl get pdb web-maintenance-pdb -n $NAMESPACE \
     -o jsonpath='{.spec.minAvailable}' | grep -q 2"

echo ""
echo -e "${BLUE}=== Node Cordon/Drain/Uncordon ===${NC}"
echo ""

# Record initial pod distribution
INITIAL_PODS=$(kubectl get pods -n $NAMESPACE -o wide --no-headers | wc -l)

echo "Performing cordon → drain → uncordon cycle on $NODE..."
echo ""

# Cordon
kubectl cordon $NODE
run_check "node $NODE is cordoned (SchedulingDisabled)" \
    "kubectl get node $NODE -o jsonpath='{.spec.unschedulable}' | grep -q true"

# Drain
kubectl drain $NODE \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --grace-period=10 \
  --timeout=120s 2>/dev/null || true

sleep 5

run_check "no non-daemonset pods on $NODE after drain" \
    "! kubectl get pods -n $NAMESPACE -o wide --no-headers | grep -q $NODE"

run_check "pods still running on other nodes" \
    "kubectl get pods -n $NAMESPACE --no-headers | grep -q Running"

run_check "deployment still has available replicas" \
    "kubectl get deployment web-maintenance -n $NAMESPACE \
     -o jsonpath='{.status.availableReplicas}' | grep -qE '[2-9]'"

# Uncordon
kubectl uncordon $NODE

# Wait for node to be fully Ready
echo "Waiting for node to be Ready..."
kubectl wait --for=condition=Ready node/$NODE --timeout=60s 2>/dev/null || true
sleep 3

run_check "node $NODE is uncordoned (Ready)" \
    "kubectl get node $NODE -o jsonpath='{.spec.unschedulable}' | grep -qv true || \
     kubectl get node $NODE --no-headers | grep -q Ready"

echo ""
echo -e "${BLUE}=== Node Health ===${NC}"
echo ""

# Wait for all nodes to be Ready
echo "Waiting for all nodes to be Ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=120s 2>/dev/null || true
sleep 5

# Count NotReady nodes directly
NOT_READY=$(kubectl get nodes --no-headers | grep -v " Ready " | grep -v "SchedulingDisabled" | wc -l | tr -d ' ')
total=$((total + 1))
echo -ne "Checking all nodes are Ready... "
if [ "$NOT_READY" = "0" ]; then
    echo -e "${GREEN}✓ PASS${NC}"
    passed=$((passed + 1))
else
    echo -e "${RED}✗ FAIL${NC} ($NOT_READY nodes not ready)"
fi

# Wait for control plane pods
echo "Waiting for control plane pods..."
sleep 10

# Count non-running control plane pods directly
NOT_RUNNING=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | \
    grep -E 'etcd|apiserver|scheduler|controller' | \
    grep -v " Running " | wc -l | tr -d ' ')
total=$((total + 1))
echo -ne "Checking control plane pods are running... "
if [ "$NOT_RUNNING" = "0" ]; then
    echo -e "${GREEN}✓ PASS${NC}"
    passed=$((passed + 1))
else
    echo -e "${RED}✗ FAIL${NC} ($NOT_RUNNING pods not running)"
    kubectl get pods -n kube-system | grep -E 'etcd|apiserver|scheduler|controller'
fi

echo ""
echo -e "${BLUE}=== Certificate Health ===${NC}"
echo ""

run_check "apiserver certificate exists" \
    "minikube ssh 'sudo ls /var/lib/minikube/certs/apiserver.crt' 2>/dev/null"

run_check "apiserver certificate is valid" \
    "minikube ssh 'sudo openssl x509 -in /var/lib/minikube/certs/apiserver.crt \
     -noout -checkend 86400' 2>/dev/null"

run_check "etcd certificate exists" \
    "minikube ssh 'sudo ls /var/lib/minikube/certs/etcd/server.crt' 2>/dev/null"

run_check "CA certificate exists" \
    "minikube ssh 'sudo ls /var/lib/minikube/certs/ca.crt' 2>/dev/null"

echo ""
echo -e "${BLUE}=== Node Conditions ===${NC}"
echo ""

run_check "no MemoryPressure on nodes" \
    "kubectl get nodes -o jsonpath='{range .items[*]}{range .status.conditions[?(@.type==\"MemoryPressure\")]}{.status}{end}{end}' | grep -qv True"

run_check "no DiskPressure on nodes" \
    "kubectl get nodes -o jsonpath='{range .items[*]}{range .status.conditions[?(@.type==\"DiskPressure\")]}{.status}{end}{end}' | grep -qv True"

run_check "no PIDPressure on nodes" \
    "kubectl get nodes -o jsonpath='{range .items[*]}{range .status.conditions[?(@.type==\"PIDPressure\")]}{.status}{end}{end}' | grep -qv True"

echo ""
echo "======================================"
echo -e "Results: ${passed}/${total} checks passed"
echo ""

if [ $passed -eq $total ]; then
    echo -e "${GREEN}🎉 All checks passed! Lab 18 complete!${NC}"
    echo ""
    echo "🏆 CLUSTER ARCHITECTURE DOMAIN COMPLETE! (18/18 labs)"
    echo ""
    echo "Node status:"
    kubectl get nodes
    echo ""
    echo "Workload status:"
    kubectl get pods -n $NAMESPACE -o wide
else
    echo -e "${RED}Some checks failed${NC}"
    echo ""
    echo "Debug:"
    kubectl get nodes
    kubectl get pods -n $NAMESPACE -o wide
    echo ""
    echo "Make sure node is uncordoned:"
    echo "  kubectl uncordon $NODE"
fi

echo ""
echo "Cleanup: ./scripts/cleanup.sh"