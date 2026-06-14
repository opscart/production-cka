#!/bin/bash
# Lab 03: kubeadm Installation - Test Script
# Tests what we CAN verify on minikube about kubeadm-configured clusters

set -e

echo "🧪 Lab 03: kubeadm Installation Tests"
echo "======================================="
echo ""

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
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

echo -e "${YELLOW}NOTE: kubeadm install is conceptual on minikube.${NC}"
echo -e "${YELLOW}These tests verify kubeadm-configured cluster structure.${NC}"
echo ""

echo -e "${BLUE}=== Cluster Structure (kubeadm-style) ===${NC}"
echo ""

run_check "static pod manifests directory exists" \
    "minikube ssh 'sudo ls /etc/kubernetes/manifests/' 2>/dev/null | grep -q yaml"

run_check "etcd static pod manifest exists" \
    "minikube ssh 'sudo ls /etc/kubernetes/manifests/etcd.yaml' 2>/dev/null"

run_check "apiserver static pod manifest exists" \
    "minikube ssh 'sudo ls /etc/kubernetes/manifests/kube-apiserver.yaml' 2>/dev/null"

run_check "scheduler static pod manifest exists" \
    "minikube ssh 'sudo ls /etc/kubernetes/manifests/kube-scheduler.yaml' 2>/dev/null"

run_check "controller-manager manifest exists" \
    "minikube ssh 'sudo ls /etc/kubernetes/manifests/kube-controller-manager.yaml' 2>/dev/null"

echo ""
echo -e "${BLUE}=== PKI Certificates (kubeadm-style) ===${NC}"
echo ""

run_check "PKI directory exists" \
    "minikube ssh 'sudo ls /var/lib/minikube/certs/' 2>/dev/null | grep -q crt"

run_check "apiserver certificate exists" \
    "minikube ssh 'sudo ls /var/lib/minikube/certs/apiserver.crt' 2>/dev/null"

run_check "CA certificate exists" \
    "minikube ssh 'sudo ls /var/lib/minikube/certs/ca.crt' 2>/dev/null"

run_check "etcd certificates exist" \
    "minikube ssh 'sudo ls /var/lib/minikube/certs/etcd/' 2>/dev/null | grep -q crt"

echo ""
echo -e "${BLUE}=== Cluster Health ===${NC}"
echo ""

run_check "all nodes are Ready" \
    "kubectl get nodes --no-headers | grep -v NotReady | grep -q Ready"

run_check "control plane pods running" \
    "kubectl get pods -n kube-system --no-headers | \
     grep -E 'etcd|apiserver|scheduler|controller' | \
     grep -q Running"

run_check "kube-proxy daemonset exists" \
    "kubectl get daemonset kube-proxy -n kube-system"

run_check "CoreDNS deployment exists" \
    "kubectl get deployment coredns -n kube-system"

run_check "API server is healthy" \
    "kubectl get --raw='/healthz' | grep -q ok"

echo ""
echo -e "${BLUE}=== kubelet (runs on every node) ===${NC}"
echo ""

run_check "kubelet is running on control plane" \
    "minikube ssh 'sudo systemctl is-active kubelet' 2>/dev/null | grep -q active"

echo ""
echo "======================================="
echo -e "Results: ${passed}/${total} checks passed"
echo ""

if [ $passed -eq $total ]; then
    echo -e "${GREEN}🎉 All checks passed! Lab 03 complete!${NC}"
    echo ""
    echo "You verified kubeadm cluster structure on minikube."
    echo "For real kubeadm install practice, use VMs."
else
    echo -e "${RED}Some checks failed${NC}"
    echo ""
    kubectl get nodes
    kubectl get pods -n kube-system
fi
