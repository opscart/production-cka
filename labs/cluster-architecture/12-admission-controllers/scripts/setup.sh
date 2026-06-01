#!/bin/bash
# Lab 12: Admission Controllers - Setup Script

set -e

echo "🔧 Lab 12: Admission Controllers Setup"
echo "======================================="
echo ""

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="lab12-admission"

echo -e "${BLUE}Step 1: Creating namespace...${NC}"
kubectl create namespace $NAMESPACE 2>/dev/null || echo "Already exists"
echo -e "${GREEN}✓ Namespace: $NAMESPACE${NC}"
echo ""

echo -e "${BLUE}Step 2: Creating LimitRange...${NC}"
cat > manifests/limitrange.yaml << 'YAML'
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: lab12-admission
spec:
  limits:
  - type: Container
    default:
      cpu: 200m
      memory: 256Mi
    defaultRequest:
      cpu: 100m
      memory: 128Mi
    max:
      cpu: 500m
      memory: 512Mi
    min:
      cpu: 50m
      memory: 64Mi
YAML
kubectl apply -f manifests/limitrange.yaml
echo -e "${GREEN}✓ LimitRange: default-limits${NC}"
echo ""

echo -e "${BLUE}Step 3: Creating ResourceQuota...${NC}"
cat > manifests/resourcequota.yaml << 'YAML'
apiVersion: v1
kind: ResourceQuota
metadata:
  name: lab12-quota
  namespace: lab12-admission
spec:
  hard:
    pods: "5"
    requests.cpu: "1"
    requests.memory: 1Gi
    limits.cpu: "2"
    limits.memory: 2Gi
    configmaps: "10"
    secrets: "10"
    services: "5"
YAML
kubectl apply -f manifests/resourcequota.yaml
echo -e "${GREEN}✓ ResourceQuota: lab12-quota${NC}"
echo ""

echo -e "${BLUE}Step 4: Creating test pod (no explicit limits)...${NC}"
kubectl run no-limits-pod --image=nginx -n $NAMESPACE 2>/dev/null || \
  echo "Pod already exists"
kubectl wait --for=condition=ready pod/no-limits-pod \
  -n $NAMESPACE --timeout=60s
echo -e "${GREEN}✓ Pod: no-limits-pod${NC}"
echo ""

echo -e "${BLUE}Step 5: Verifying LimitRange injected defaults...${NC}"
CPU_LIMIT=$(kubectl get pod no-limits-pod -n $NAMESPACE \
  -o jsonpath='{.spec.containers[0].resources.limits.cpu}')
echo -e "${GREEN}✓ Auto-injected CPU limit: $CPU_LIMIT${NC}"
echo ""

echo "======================================="
echo -e "${GREEN}✓ Setup complete!${NC}"
echo ""
echo "LimitRange:"
kubectl describe limitrange default-limits -n $NAMESPACE
echo ""
echo "ResourceQuota:"
kubectl describe resourcequota lab12-quota -n $NAMESPACE
echo ""
echo "Run: ./scripts/test.sh"