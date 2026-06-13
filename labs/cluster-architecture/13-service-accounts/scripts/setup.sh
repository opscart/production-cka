#!/bin/bash
# Lab 13: Service Accounts - Setup Script

set -e

echo "🔧 Lab 13: Service Accounts Setup"
echo "=================================="
echo ""

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="lab13-sa"

echo -e "${BLUE}Step 1: Creating namespace...${NC}"
kubectl create namespace $NAMESPACE 2>/dev/null || echo "Already exists"
echo -e "${GREEN}✓ Namespace: $NAMESPACE${NC}"
echo ""

echo -e "${BLUE}Step 2: Creating monitoring service account...${NC}"
kubectl create serviceaccount monitoring-sa -n $NAMESPACE 2>/dev/null || \
  echo "Already exists"
echo -e "${GREEN}✓ Service account: monitoring-sa${NC}"
echo ""

echo -e "${BLUE}Step 3: Creating monitoring Role...${NC}"
cat > manifests/monitoring-role.yaml << 'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: monitoring-role
  namespace: lab13-sa
rules:
- apiGroups: [""]
  resources: ["pods", "services", "endpoints"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch"]
EOF
kubectl apply -f manifests/monitoring-role.yaml
echo -e "${GREEN}✓ Role: monitoring-role${NC}"
echo ""

echo -e "${BLUE}Step 4: Creating RoleBinding...${NC}"
cat > manifests/monitoring-rolebinding.yaml << 'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: monitoring-rolebinding
  namespace: lab13-sa
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: monitoring-role
subjects:
- kind: ServiceAccount
  name: monitoring-sa
  namespace: lab13-sa
EOF
kubectl apply -f manifests/monitoring-rolebinding.yaml
echo -e "${GREEN}✓ RoleBinding: monitoring-rolebinding${NC}"
echo ""

echo -e "${BLUE}Step 5: Creating monitoring pod...${NC}"
cat > manifests/monitoring-pod.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: monitoring-pod
  namespace: lab13-sa
spec:
  serviceAccountName: monitoring-sa
  containers:
  - name: monitor
    image: nginx
    command: ["sleep", "3600"]
EOF
kubectl apply -f manifests/monitoring-pod.yaml
kubectl wait --for=condition=ready pod/monitoring-pod \
  -n $NAMESPACE --timeout=60s
echo -e "${GREEN}✓ Pod: monitoring-pod${NC}"
echo ""

echo -e "${BLUE}Step 6: Creating restricted service account...${NC}"
cat > manifests/restricted-sa.yaml << 'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: restricted-sa
  namespace: lab13-sa
automountServiceAccountToken: false
EOF
kubectl apply -f manifests/restricted-sa.yaml
echo -e "${GREEN}✓ Service account: restricted-sa (no automount)${NC}"
echo ""

echo -e "${BLUE}Step 7: Creating restricted pod...${NC}"
cat > manifests/restricted-pod.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: restricted-pod
  namespace: lab13-sa
spec:
  serviceAccountName: restricted-sa
  containers:
  - name: app
    image: nginx
    command: ["sleep", "3600"]
EOF
kubectl apply -f manifests/restricted-pod.yaml
kubectl wait --for=condition=ready pod/restricted-pod \
  -n $NAMESPACE --timeout=60s
echo -e "${GREEN}✓ Pod: restricted-pod${NC}"
echo ""

echo "=================================="
echo -e "${GREEN}✓ Setup complete!${NC}"
echo ""
echo "Service accounts:"
kubectl get serviceaccount -n $NAMESPACE
echo ""
echo "Pods:"
kubectl get pods -n $NAMESPACE
echo ""
echo "Run: ./scripts/test.sh"