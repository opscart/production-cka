#!/bin/bash
# Lab 03: kubeadm Installation - Inspect Cluster Script

set -e

echo "🔍 Lab 03: Inspect Cluster Components"
echo "======================================"
echo ""

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Control Plane Components ===${NC}"
echo ""

# List control plane pods
echo "Control plane pods in kube-system namespace:"
kubectl get pods -n kube-system -l tier=control-plane -o wide

echo ""
echo -e "${BLUE}=== Static Pod Manifests ===${NC}"
echo ""
echo "These files define control plane components:"
echo "(Located in /etc/kubernetes/manifests/ on control plane node)"
echo ""

# List static pod manifests
echo "Checking static pod manifests..."
minikube ssh "ls -lh /etc/kubernetes/manifests/" 2>/dev/null || echo "Unable to access (permissions)"

echo ""
echo -e "${BLUE}=== etcd ===${NC}"
echo "Database that stores all cluster state"
echo ""
kubectl get pod -n kube-system -l component=etcd --no-headers | awk '{print "Pod:", $1, "Status:", $3}'

echo ""
echo -e "${BLUE}=== kube-apiserver ===${NC}"
echo "The cluster's REST API - all communication goes through here"
echo ""
kubectl get pod -n kube-system -l component=kube-apiserver --no-headers | awk '{print "Pod:", $1, "Status:", $3}'

echo ""
echo -e "${BLUE}=== kube-controller-manager ===${NC}"
echo "Runs controller loops (deployments, replicasets, nodes, etc.)"
echo ""
kubectl get pod -n kube-system -l component=kube-controller-manager --no-headers | awk '{print "Pod:", $1, "Status:", $3}'

echo ""
echo -e "${BLUE}=== kube-scheduler ===${NC}"
echo "Decides which node to place pods on"
echo ""
kubectl get pod -n kube-system -l component=kube-scheduler --no-headers | awk '{print "Pod:", $1, "Status:", $3}'

echo ""
echo -e "${BLUE}=== Node Components ===${NC}"
echo ""

# kube-proxy
echo "kube-proxy (runs on all nodes):"
kubectl get pods -n kube-system -l k8s-app=kube-proxy --no-headers | wc -l | awk '{print $1, "instances running"}'

# CNI
echo ""
echo "CNI Plugin:"
kubectl get pods -n kube-system -l k8s-app=kindnet --no-headers 2>/dev/null && echo "kindnet (minikube default)" || echo "Other CNI"

echo ""
echo -e "${BLUE}=== Cluster Info ===${NC}"
echo ""
kubectl cluster-info

echo ""
echo -e "${BLUE}=== Nodes ===${NC}"
echo ""
kubectl get nodes -o wide

echo ""
echo "======================================"
echo -e "${GREEN}Cluster inspection complete!${NC}"
echo ""
echo "To see detailed component info:"
echo "  kubectl describe pod -n kube-system <pod-name>"
echo ""
echo "To check component health:"
echo "  kubectl get --raw='/healthz?verbose'"
echo ""
echo "Next: Verify cluster functionality"
echo "  ./scripts/verify-components.sh"