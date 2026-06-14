#!/bin/bash
# Lab 04: Cluster Upgrade - Setup Script
# NOTE: Real version upgrade is NOT possible on minikube
# minikube always runs the latest Kubernetes version

set -e

echo "🔧 Lab 04: Cluster Upgrade Setup"
echo "=================================="
echo ""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${YELLOW}⚠️  MINIKUBE LIMITATION${NC}"
echo ""
echo "Real Kubernetes version upgrades cannot be done on minikube because:"
echo "  - minikube always installs the latest Kubernetes version"
echo "  - kubeadm upgrade commands are not available inside minikube"
echo "  - Version pinning for upgrades requires multi-node kubeadm cluster"
echo ""
echo "This lab practices UPGRADE CONCEPTS and DRAIN/UNCORDON"
echo "which works identically on all cluster types."
echo ""

echo -e "${BLUE}What this lab covers:${NC}"
echo "  ✅ Drain/uncordon workflow (works on minikube)"
echo "  ✅ Zero-downtime pod migration"
echo "  ✅ Understanding upgrade sequence"
echo "  📖 Upgrade commands (conceptual - for real clusters)"
echo ""

NAMESPACE="lab04-upgrade"

echo -e "${BLUE}Step 1: Creating namespace...${NC}"
kubectl create namespace $NAMESPACE 2>/dev/null || echo "Already exists"
echo -e "${GREEN}✓ Namespace: $NAMESPACE${NC}"
echo ""

echo -e "${BLUE}Step 2: Deploying test workload (6 replicas across nodes)...${NC}"
kubectl create deployment upgrade-test \
  --image=nginx \
  --replicas=6 \
  -n $NAMESPACE 2>/dev/null || echo "Already exists"

kubectl wait --for=condition=available \
  deployment/upgrade-test \
  -n $NAMESPACE --timeout=60s

echo -e "${GREEN}✓ Deployment: upgrade-test (6 replicas)${NC}"
echo ""

echo "Current pod distribution:"
kubectl get pods -n $NAMESPACE -o wide
echo ""

echo "Current node versions:"
kubectl get nodes -o custom-columns=\
"NAME:.metadata.name,VERSION:.status.nodeInfo.kubeletVersion,STATUS:.status.conditions[-1].type"

echo ""
echo "=================================="
echo -e "${GREEN}✓ Setup complete!${NC}"
echo ""
echo "Run: ./scripts/test.sh"
