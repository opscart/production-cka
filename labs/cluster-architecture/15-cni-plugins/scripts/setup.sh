#!/bin/bash
# Lab 15: CNI Plugins - Setup Script

set -e

echo "🔧 Lab 15: CNI Plugins Setup"
echo "=============================="
echo ""

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

NAMESPACE="lab15-cni"

echo -e "${BLUE}Step 1: Identifying CNI plugin...${NC}"
CNI_POD=$(kubectl get pods -n kube-system \
  --no-headers 2>/dev/null | \
  grep -E "calico|flannel|weave|cilium|kindnet" | \
  awk '{print $1}' | head -1)

if [ -n "$CNI_POD" ]; then
    echo -e "${GREEN}✓ CNI plugin pod: $CNI_POD${NC}"
else
    echo -e "${YELLOW}⚠️  No standard CNI pod found - checking config files${NC}"
fi
echo ""

echo -e "${BLUE}Step 2: Creating namespace...${NC}"
kubectl create namespace $NAMESPACE 2>/dev/null || echo "Already exists"
echo -e "${GREEN}✓ Namespace: $NAMESPACE${NC}"
echo ""

echo -e "${BLUE}Step 3: Creating test pods on different nodes...${NC}"

# Get node names
NODE1=$(kubectl get nodes --no-headers | awk 'NR==1{print $1}')
NODE2=$(kubectl get nodes --no-headers | awk 'NR==2{print $1}')

echo "  Node 1: $NODE1"
echo "  Node 2: $NODE2"

cat > manifests/pod-node1.yaml << EOF
apiVersion: v1
kind: Pod
metadata:
  name: pod-node1
  namespace: $NAMESPACE
spec:
  nodeSelector:
    kubernetes.io/hostname: $NODE1
  containers:
  - name: net-test
    image: busybox
    command: ["sleep", "3600"]
EOF

cat > manifests/pod-node2.yaml << EOF
apiVersion: v1
kind: Pod
metadata:
  name: pod-node2
  namespace: $NAMESPACE
spec:
  nodeSelector:
    kubernetes.io/hostname: $NODE2
  containers:
  - name: net-test
    image: busybox
    command: ["sleep", "3600"]
EOF

kubectl apply -f manifests/pod-node1.yaml
kubectl apply -f manifests/pod-node2.yaml

kubectl wait --for=condition=ready pod/pod-node1 \
  -n $NAMESPACE --timeout=60s
kubectl wait --for=condition=ready pod/pod-node2 \
  -n $NAMESPACE --timeout=60s

echo -e "${GREEN}✓ Pods created on different nodes${NC}"
echo ""

echo -e "${BLUE}Step 4: Creating web-app for DNS test...${NC}"
kubectl create deployment web-app \
  --image=nginx -n $NAMESPACE 2>/dev/null || echo "Already exists"
kubectl expose deployment web-app \
  --port=80 -n $NAMESPACE 2>/dev/null || echo "Already exposed"
kubectl wait --for=condition=available \
  deployment/web-app -n $NAMESPACE --timeout=60s
echo -e "${GREEN}✓ web-app deployed and exposed${NC}"
echo ""

echo "=============================="
echo -e "${GREEN}✓ Setup complete!${NC}"
echo ""
echo "Pod IPs:"
kubectl get pods -n $NAMESPACE -o wide
echo ""
echo "Node pod CIDRs:"
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.podCIDR}{"\n"}{end}'
echo ""
echo "Run: ./scripts/test.sh"