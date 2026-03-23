#!/bin/bash
# Lab 05: etcd Backup & Restore - Create Test Data Script

set -e

echo "📦 Lab 05: Create Test Data"
echo "============================"
echo ""

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Creating test namespace and resources...${NC}"
echo ""

# Create namespace
echo "1. Creating namespace: backup-test"
kubectl create namespace backup-test 2>/dev/null || echo "Namespace already exists"

echo ""
echo "2. Creating deployment: nginx-test (3 replicas)"
kubectl create deployment nginx-test --image=nginx --replicas=3 -n backup-test 2>/dev/null || echo "Deployment already exists"

echo ""
echo "3. Creating configmap: test-config"
kubectl create configmap test-config \
  --from-literal=key1=value1 \
  --from-literal=key2=value2 \
  --from-literal=app=backup-test \
  -n backup-test 2>/dev/null || echo "ConfigMap already exists"

echo ""
echo "4. Creating secret: test-secret"
kubectl create secret generic test-secret \
  --from-literal=password=supersecret \
  --from-literal=api-key=abc123xyz \
  -n backup-test 2>/dev/null || echo "Secret already exists"

echo ""
echo "5. Creating service: nginx-test"
kubectl expose deployment nginx-test --port=80 -n backup-test 2>/dev/null || echo "Service already exists"

echo ""
echo "6. Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=nginx-test -n backup-test --timeout=60s

echo ""
echo "============================"
echo -e "${GREEN}Test data created!${NC}"
echo ""

echo -e "${BLUE}Resources in backup-test namespace:${NC}"
echo ""
kubectl get all,cm,secret -n backup-test

echo ""
echo "Saving current state for later verification..."
kubectl get all -n backup-test > ./before-disaster.txt

echo ""
echo -e "${GREEN}State saved to: ./before-disaster.txt${NC}"
echo ""

echo "These resources will be used to verify restore:"
echo "  ✓ Namespace: backup-test"
echo "  ✓ Deployment: nginx-test (3 pods)"
echo "  ✓ Service: nginx-test"
echo "  ✓ ConfigMap: test-config"
echo "  ✓ Secret: test-secret"
echo ""
echo "Next: Simulate disaster"
echo "  kubectl delete namespace backup-test"