#!/bin/bash
# Lab 11: API Server Authentication - Setup Script

set -e

echo "🔧 Lab 11: API Server Auth Setup"
echo "================================="
echo ""

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="lab11-auth"
mkdir -p certs manifests

# Create namespace
echo -e "${BLUE}Step 1: Creating namespace...${NC}"
kubectl create namespace $NAMESPACE 2>/dev/null || echo "Namespace already exists"
echo -e "${GREEN}✓ Namespace: $NAMESPACE${NC}"
echo ""

# Generate key and CSR
echo -e "${BLUE}Step 2: Generating user key and CSR...${NC}"
openssl genrsa -out certs/dev-user.key 2048 2>/dev/null
echo -e "${GREEN}✓ Private key: certs/dev-user.key${NC}"

openssl req -new \
  -key certs/dev-user.key \
  -out certs/dev-user.csr \
  -subj "/CN=dev-user/O=dev-team" 2>/dev/null
echo -e "${GREEN}✓ CSR: certs/dev-user.csr${NC}"
echo ""

# Submit CSR
echo -e "${BLUE}Step 3: Submitting CSR to Kubernetes...${NC}"
CSR=$(cat certs/dev-user.csr | base64 | tr -d '\n')

cat > manifests/dev-user-csr.yaml << YAML
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: dev-user
spec:
  request: $CSR
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400
  usages:
  - client auth
YAML

kubectl delete csr dev-user 2>/dev/null || true
kubectl apply -f manifests/dev-user-csr.yaml
echo -e "${GREEN}✓ CSR submitted${NC}"
echo ""

# Approve CSR
echo -e "${BLUE}Step 4: Approving CSR...${NC}"
kubectl certificate approve dev-user
echo -e "${GREEN}✓ CSR approved${NC}"
echo ""

# Extract certificate
echo -e "${BLUE}Step 5: Extracting signed certificate...${NC}"
sleep 2
kubectl get csr dev-user \
  -o jsonpath='{.status.certificate}' | base64 -d > certs/dev-user.crt
echo -e "${GREEN}✓ Certificate: certs/dev-user.crt${NC}"
echo ""

# Get CA cert - handle both file path and inline base64
echo -e "${BLUE}Step 6: Getting cluster CA and server URL...${NC}"
SERVER=$(kubectl config view -o jsonpath='{.clusters[?(@.name=="opscart")].cluster.server}')

CA_DATA=$(kubectl config view --raw -o jsonpath='{.clusters[?(@.name=="opscart")].cluster.certificate-authority-data}')
CA_FILE=$(kubectl config view --raw -o jsonpath='{.clusters[?(@.name=="opscart")].cluster.certificate-authority}')

if [ -n "$CA_DATA" ]; then
    echo "$CA_DATA" | base64 -d > certs/ca.crt
elif [ -n "$CA_FILE" ] && [ -f "$CA_FILE" ]; then
    cp "$CA_FILE" certs/ca.crt
else
    echo -e "${RED}✗ Cannot find CA certificate${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Server: $SERVER${NC}"
echo -e "${GREEN}✓ CA cert: $(wc -c < certs/ca.crt) bytes${NC}"
echo ""

# Create kubeconfig
echo -e "${BLUE}Step 7: Creating kubeconfig for dev-user...${NC}"

kubectl config set-cluster opscart \
  --certificate-authority=certs/ca.crt \
  --server=$SERVER \
  --embed-certs=true \
  --kubeconfig=certs/dev-user.kubeconfig 2>/dev/null

kubectl config set-credentials dev-user \
  --client-certificate=certs/dev-user.crt \
  --client-key=certs/dev-user.key \
  --embed-certs=true \
  --kubeconfig=certs/dev-user.kubeconfig 2>/dev/null

kubectl config set-context dev-user-context \
  --cluster=opscart \
  --user=dev-user \
  --namespace=$NAMESPACE \
  --kubeconfig=certs/dev-user.kubeconfig 2>/dev/null

kubectl config use-context dev-user-context \
  --kubeconfig=certs/dev-user.kubeconfig 2>/dev/null

echo -e "${GREEN}✓ kubeconfig: certs/dev-user.kubeconfig${NC}"
echo ""

# Create service account in namespace
echo -e "${BLUE}Step 8: Creating service account...${NC}"
kubectl create serviceaccount auth-demo-sa -n $NAMESPACE 2>/dev/null || \
  echo "Service account already exists"
echo -e "${GREEN}✓ Service account: auth-demo-sa${NC}"
echo ""

# Create pod in namespace
echo -e "${BLUE}Step 9: Creating demo pod...${NC}"
cat > manifests/auth-demo-pod.yaml << 'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: auth-demo-pod
  namespace: lab11-auth
spec:
  serviceAccountName: auth-demo-sa
  containers:
  - name: demo
    image: nginx
    command: ["sleep", "3600"]
YAML

kubectl apply -f manifests/auth-demo-pod.yaml
echo -e "${GREEN}✓ Pod: auth-demo-pod in $NAMESPACE${NC}"
echo ""

echo "================================="
echo -e "${GREEN}✓ Setup complete!${NC}"
echo ""
echo "Files created:"
ls -la certs/
echo ""
echo "Run: ./scripts/test.sh"