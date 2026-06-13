#!/bin/bash
# Lab 18: Cluster Maintenance - Setup Script

set -e

echo "🔧 Lab 18: Cluster Maintenance Setup"
echo "======================================"
echo ""

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="lab18-maintenance"

echo -e "${BLUE}Step 1: Creating namespace...${NC}"
kubectl create namespace $NAMESPACE 2>/dev/null || echo "Already exists"
echo -e "${GREEN}✓ Namespace: $NAMESPACE${NC}"
echo ""

echo -e "${BLUE}Step 2: Deploying workload across nodes...${NC}"
kubectl create deployment web-maintenance \
  --image=nginx \
  --replicas=4 \
  -n $NAMESPACE 2>/dev/null || echo "Already exists"

kubectl wait --for=condition=available \
  deployment/web-maintenance \
  -n $NAMESPACE --timeout=60s

echo -e "${GREEN}✓ Deployment: web-maintenance (4 replicas)${NC}"
echo ""

echo -e "${BLUE}Step 3: Creating PodDisruptionBudget...${NC}"
cat > manifests/web-pdb.yaml << 'PDBEOF'
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: web-maintenance-pdb
  namespace: lab18-maintenance
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: web-maintenance
PDBEOF

kubectl apply -f manifests/web-pdb.yaml
echo -e "${GREEN}✓ PDB: web-maintenance-pdb (minAvailable: 2)${NC}"
echo ""

echo -e "${BLUE}Step 4: Checking initial pod distribution...${NC}"
kubectl get pods -n $NAMESPACE -o wide
echo ""

echo -e "${BLUE}Step 5: Checking node health...${NC}"
kubectl get nodes
echo ""

echo "======================================"
echo -e "${GREEN}✓ Setup complete!${NC}"
echo ""
echo "Ready to practice:"
echo "  1. Cordon:   kubectl cordon opscart-m02"
echo "  2. Drain:    kubectl drain opscart-m02 --ignore-daemonsets --delete-emptydir-data"
echo "  3. Uncordon: kubectl uncordon opscart-m02"
echo ""
echo "Run: ./scripts/test.sh"