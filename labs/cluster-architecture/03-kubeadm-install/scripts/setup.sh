#!/bin/bash
# Lab 03: kubeadm Installation - Setup Script
# NOTE: kubeadm install is CONCEPTUAL on minikube
# Real installation requires fresh VMs/bare metal

set -e

echo "🔧 Lab 03: kubeadm Installation Setup"
echo "======================================="
echo ""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${YELLOW}⚠️  MINIKUBE LIMITATION${NC}"
echo ""
echo "kubeadm install cannot be demonstrated on minikube because:"
echo "  - minikube already provides a running cluster"
echo "  - kubeadm requires fresh nodes with no Kubernetes installed"
echo "  - The 'kubeadm init' command is not available inside minikube"
echo ""
echo "This lab is CONCEPTUAL on minikube."
echo "For real kubeadm practice, use:"
echo "  - Multipass VMs (free, local)"
echo "  - Vagrant + VirtualBox"
echo "  - Cloud VMs (Hetzner, DigitalOcean, AWS EC2)"
echo ""
echo "========================================="
echo ""

echo -e "${BLUE}What we CAN do on minikube:${NC}"
echo ""

echo "1. Inspect the cluster kubeadm already configured:"
echo ""

# Show static pod manifests
echo "Static pod manifests (created by kubeadm):"
minikube ssh "sudo ls -la /etc/kubernetes/manifests/" 2>/dev/null || \
  echo "  (accessible via minikube ssh)"

echo ""
echo "2. View kubeadm configuration:"
minikube ssh "sudo cat /etc/kubernetes/kubeadm-flags.env 2>/dev/null" || \
  echo "  (not available on minikube)"

echo ""
echo "3. View cluster info:"
kubectl cluster-info
kubectl get nodes -o wide

echo ""
echo "4. View control plane components:"
kubectl get pods -n kube-system | grep -E "etcd|apiserver|scheduler|controller"

echo ""
echo "======================================="
echo -e "${GREEN}✓ Setup complete!${NC}"
echo ""
echo "Study the README.md for kubeadm installation steps"
echo "that apply to real clusters."
echo ""
echo "Run: ./scripts/test.sh"
