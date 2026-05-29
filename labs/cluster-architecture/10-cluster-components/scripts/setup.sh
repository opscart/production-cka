#!/bin/bash
# Lab 10: Cluster Components - Setup Script

set -e

echo "🔧 Lab 10: Cluster Components Setup"
echo "===================================="
echo ""

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Verifying all components are running...${NC}"
echo ""

echo "Control plane pods:"
kubectl get pods -n kube-system | grep -E "etcd|apiserver|scheduler|controller"

echo ""
echo "Worker components:"
kubectl get daemonset kube-proxy -n kube-system
kubectl get pods -n kube-system -l k8s-app=kube-proxy -o wide

echo ""
echo "API server health:"
kubectl get --raw='/healthz'

echo ""
echo "===================================="
echo -e "${GREEN}✓ Setup complete!${NC}"
echo ""
echo "Run: ./scripts/test.sh"
