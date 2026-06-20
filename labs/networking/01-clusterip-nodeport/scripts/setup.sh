#!/bin/bash
# Networking Lab 01: ClusterIP & NodePort - Setup Script

set -e

echo "🔧 Networking Lab 01: ClusterIP & NodePort Setup"
echo "=================================================="
echo ""

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="lab01-services"

echo -e "${BLUE}Step 1: Creating namespace...${NC}"
kubectl create namespace $NAMESPACE 2>/dev/null || echo "Already exists"
echo -e "${GREEN}✓ Namespace: $NAMESPACE${NC}"
echo ""

echo -e "${BLUE}Step 2: Creating web-app deployment (3 replicas)...${NC}"
kubectl create deployment web-app \
  --image=nginx \
  --replicas=3 \
  -n $NAMESPACE 2>/dev/null || echo "Already exists"

kubectl wait --for=condition=available \
  deployment/web-app -n $NAMESPACE --timeout=60s
echo -e "${GREEN}✓ Deployment: web-app (3 replicas)${NC}"
echo ""

echo -e "${BLUE}Step 3: Exposing as ClusterIP service...${NC}"
kubectl expose deployment web-app \
  --port=80 \
  --target-port=80 \
  --name=web-app-clusterip \
  -n $NAMESPACE 2>/dev/null || echo "Already exposed"
echo -e "${GREEN}✓ Service: web-app-clusterip (ClusterIP)${NC}"
echo ""

echo -e "${BLUE}Step 4: Creating broken service (wrong selector, for exam practice)...${NC}"
cat > manifests/broken-service.yaml << 'BROKENEOF'
apiVersion: v1
kind: Service
metadata:
  name: broken-service
  namespace: lab01-services
spec:
  selector:
    app: wrong-label
  ports:
  - port: 80
    targetPort: 80
BROKENEOF
kubectl apply -f manifests/broken-service.yaml
echo -e "${GREEN}✓ Service: broken-service (intentionally has no endpoints)${NC}"
echo ""

echo -e "${BLUE}Step 5: Creating NodePort service...${NC}"
cat > manifests/web-app-nodeport.yaml << 'NODEPORTEOF'
apiVersion: v1
kind: Service
metadata:
  name: web-app-nodeport
  namespace: lab01-services
spec:
  type: NodePort
  selector:
    app: web-app
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
NODEPORTEOF
kubectl apply -f manifests/web-app-nodeport.yaml
echo -e "${GREEN}✓ Service: web-app-nodeport (NodePort 30080)${NC}"
echo ""

echo -e "${BLUE}Step 6: Creating test client pod...${NC}"
kubectl run test-client --image=busybox -n $NAMESPACE -- sleep 3600 2>/dev/null || \
  echo "Already exists"
kubectl wait --for=condition=ready pod/test-client -n $NAMESPACE --timeout=60s
echo -e "${GREEN}✓ Pod: test-client${NC}"
echo ""

echo "=================================================="
echo -e "${GREEN}✓ Setup complete!${NC}"
echo ""
echo "Services:"
kubectl get svc -n $NAMESPACE
echo ""
echo "Endpoints:"
kubectl get endpoints -n $NAMESPACE 2>/dev/null
echo ""
echo "Run: ./scripts/test.sh"