#!/bin/bash
# Lab 09: High Availability - Setup Script

set -e

echo "🔧 Lab 09: High Availability Setup"
echo "==================================="
echo ""

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Create manifests directory
mkdir -p ./manifests

echo -e "${BLUE}Step 1: Creating test deployment (3 replicas)...${NC}"
kubectl create deployment web-app --image=nginx --replicas=3 2>/dev/null || \
  echo "Deployment already exists"
kubectl wait --for=condition=available --timeout=60s deployment/web-app
echo -e "${GREEN}✓ Deployment created${NC}"
echo ""

echo -e "${BLUE}Step 2: Creating PodDisruptionBudget...${NC}"
cat > manifests/web-app-pdb.yaml << 'EOF'
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: web-app-pdb
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: web-app
EOF

kubectl apply -f manifests/web-app-pdb.yaml
echo -e "${GREEN}✓ PDB created${NC}"
echo ""

echo -e "${BLUE}Step 3: Creating HA deployment with anti-affinity...${NC}"
cat > manifests/web-app-ha.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app-ha
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web-app-ha
  template:
    metadata:
      labels:
        app: web-app-ha
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  app: web-app-ha
              topologyKey: kubernetes.io/hostname
      containers:
      - name: web-app
        image: nginx
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
EOF

kubectl apply -f manifests/web-app-ha.yaml
kubectl wait --for=condition=available --timeout=60s deployment/web-app-ha
echo -e "${GREEN}✓ HA deployment created${NC}"
echo ""

echo "==================================="
echo -e "${GREEN}✓ Setup complete!${NC}"
echo ""
echo "Control plane components:"
kubectl get pods -n kube-system | grep -E "etcd|apiserver|scheduler|controller"
echo ""
echo "Deployments:"
kubectl get deployments
echo ""
echo "PDB:"
kubectl get pdb
echo ""
echo "Run: ./scripts/test.sh"
