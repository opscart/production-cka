#!/bin/bash
# Networking Lab 02: LoadBalancer & Headless Services - Setup Script

set -e

echo "🔧 Networking Lab 02: LoadBalancer & Headless Setup"
echo "======================================================"
echo ""

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

NAMESPACE="lab02-services"

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

echo -e "${BLUE}Step 3: Creating LoadBalancer service...${NC}"
kubectl expose deployment web-app \
  --port=80 \
  --target-port=80 \
  --type=LoadBalancer \
  --name=web-app-lb \
  -n $NAMESPACE 2>/dev/null || echo "Already exposed"
echo -e "${GREEN}✓ Service: web-app-lb (LoadBalancer)${NC}"
echo -e "${YELLOW}  Note: EXTERNAL-IP will show <pending> without 'minikube tunnel'${NC}"
echo ""

echo -e "${BLUE}Step 4: Creating headless service...${NC}"
cat > manifests/web-app-headless.yaml << 'HEADLESSEOF'
apiVersion: v1
kind: Service
metadata:
  name: web-app-headless
  namespace: lab02-services
spec:
  clusterIP: None
  selector:
    app: web-app
  ports:
  - port: 80
    targetPort: 80
HEADLESSEOF
kubectl apply -f manifests/web-app-headless.yaml
echo -e "${GREEN}✓ Service: web-app-headless (clusterIP: None)${NC}"
echo ""

echo -e "${BLUE}Step 5: Creating Postgres StatefulSet with headless service...${NC}"
cat > manifests/postgres-statefulset.yaml << 'PGEOF'
apiVersion: v1
kind: Service
metadata:
  name: postgres-headless
  namespace: lab02-services
spec:
  clusterIP: None
  selector:
    app: postgres
  ports:
  - port: 5432
    targetPort: 5432
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: lab02-services
spec:
  serviceName: postgres-headless
  replicas: 2
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:16-alpine
        env:
        - name: POSTGRES_PASSWORD
          value: "labpassword"
        ports:
        - containerPort: 5432
PGEOF
kubectl apply -f manifests/postgres-statefulset.yaml

echo "Waiting for postgres-0 and postgres-1 (this can take ~60s on first pull)..."

# StatefulSet pods are created sequentially and may not exist yet -
# wait for them to appear before waiting for readiness condition
for pod in postgres-0 postgres-1; do
    echo "  Waiting for pod/$pod to exist..."
    until kubectl get pod $pod -n $NAMESPACE &>/dev/null; do
        sleep 2
    done
    kubectl wait --for=condition=ready pod/$pod \
      -n $NAMESPACE --timeout=120s
done
echo -e "${GREEN}✓ StatefulSet: postgres (2 replicas) + postgres-headless service${NC}"
echo ""

echo -e "${BLUE}Step 6: Creating DNS test pod...${NC}"
kubectl run dns-test --image=busybox -n $NAMESPACE -- sleep 3600 2>/dev/null || \
  echo "Already exists"
kubectl wait --for=condition=ready pod/dns-test -n $NAMESPACE --timeout=60s
echo -e "${GREEN}✓ Pod: dns-test${NC}"
echo ""

echo "======================================================"
echo -e "${GREEN}✓ Setup complete!${NC}"
echo ""
echo "Services:"
kubectl get svc -n $NAMESPACE
echo ""
echo "StatefulSet pods:"
kubectl get pods -n $NAMESPACE -l app=postgres -o wide
echo ""
echo "Run: ./scripts/test.sh"