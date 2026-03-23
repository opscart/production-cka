#!/bin/bash
# Lab 03: kubeadm Installation - Prerequisites Check Script

set -e

echo "🔍 Lab 03: Prerequisites Check"
echo "==============================="
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Note: This script checks your existing minikube cluster${NC}"
echo -e "${YELLOW}In a real kubeadm setup, you'd install these components${NC}"
echo ""

# Check kubectl
echo -n "Checking kubectl... "
if command -v kubectl &> /dev/null; then
    VERSION=$(kubectl version --client -o json | grep gitVersion | head -1 | cut -d'"' -f4)
    echo -e "${GREEN}✓ Installed ($VERSION)${NC}"
else
    echo -e "${RED}✗ Not found${NC}"
fi

# Check kubeadm
echo -n "Checking kubeadm... "
if minikube ssh "which kubeadm" &> /dev/null; then
    VERSION=$(minikube ssh "kubeadm version -o short" 2>/dev/null)
    echo -e "${GREEN}✓ Installed ($VERSION)${NC}"
else
    echo -e "${YELLOW}⚠ Not accessible (minikube uses internal kubeadm)${NC}"
fi

# Check kubelet
echo -n "Checking kubelet... "
if minikube ssh "systemctl is-active kubelet" &> /dev/null; then
    echo -e "${GREEN}✓ Running${NC}"
else
    echo -e "${RED}✗ Not running${NC}"
fi

# Check container runtime
echo -n "Checking container runtime... "
RUNTIME=$(kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.containerRuntimeVersion}')
echo -e "${GREEN}✓ $RUNTIME${NC}"

# Check swap
echo -n "Checking swap... "
SWAP=$(minikube ssh "free -h | grep Swap | awk '{print \$2}'")
if [ "$SWAP" = "0B" ]; then
    echo -e "${GREEN}✓ Disabled${NC}"
else
    echo -e "${YELLOW}⚠ Swap: $SWAP (should be disabled)${NC}"
fi

# Check kernel modules
echo -n "Checking kernel modules... "
if minikube ssh "lsmod | grep -q br_netfilter" &> /dev/null; then
    echo -e "${GREEN}✓ br_netfilter loaded${NC}"
else
    echo -e "${YELLOW}⚠ br_netfilter not loaded${NC}"
fi

echo ""
echo "==============================="
echo -e "${GREEN}Prerequisites check complete!${NC}"
echo ""
echo "What you would install on fresh VMs:"
echo "  1. Container runtime (containerd/cri-o)"
echo "  2. kubeadm, kubelet, kubectl"
echo "  3. Disable swap"
echo "  4. Load kernel modules (overlay, br_netfilter)"
echo "  5. Configure sysctl (ip_forward, bridge-nf-call)"
echo ""
echo "Next: Inspect control plane components"
echo "  ./scripts/inspect-cluster.sh"