#!/bin/bash
# Lab 04: Cluster Upgrade - Version Check Script

set -e

echo "🔍 Lab 04: Cluster Version Check"
echo "=================================="
echo ""

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Current Cluster Versions ===${NC}"
echo ""

# kubectl version
echo "kubectl version:"
kubectl version --short 2>/dev/null || kubectl version --client

echo ""
echo "Server version:"
kubectl version -o json 2>/dev/null | grep gitVersion | head -1 || echo "Check manually"

echo ""
echo -e "${BLUE}=== Node Versions ===${NC}"
echo ""
kubectl get nodes -o custom-columns=NAME:.metadata.name,VERSION:.status.nodeInfo.kubeletVersion,OS:.status.nodeInfo.osImage

echo ""
echo -e "${BLUE}=== Control Plane Component Versions ===${NC}"
echo ""

# Get control plane pod images
echo "Control plane components:"
kubectl get pods -n kube-system -l tier=control-plane -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image --no-headers 2>/dev/null || echo "Unable to fetch"

echo ""
echo -e "${BLUE}=== Addon Versions ===${NC}"
echo ""

# CoreDNS
echo -n "CoreDNS: "
kubectl get deployment -n kube-system coredns -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "N/A"

echo ""
echo -n "kube-proxy: "
kubectl get daemonset -n kube-system kube-proxy -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "N/A"

echo ""
echo ""
echo -e "${BLUE}=== kubeadm Version (Control Plane) ===${NC}"
echo ""
minikube ssh "kubeadm version -o short" 2>/dev/null || echo "Not accessible in minikube"

echo ""
echo "=================================="
echo -e "${GREEN}Version check complete!${NC}"
echo ""
echo "Note: Your minikube cluster is running v1.35.1 (latest)"
echo ""
echo "In a production cluster, you would:"
echo "  1. Check if upgrade is available"
echo "  2. Run: sudo kubeadm upgrade plan"
echo "  3. Review upgrade path"
echo "  4. Proceed with upgrade if safe"
echo ""
echo "Next: Learn upgrade simulation"
echo "  cat ../QUICK-REFERENCE.md"