#!/bin/bash
# Lab 08: Kustomize Basics - Setup Script

set -e

echo "🔧 Lab 08: Kustomize Setup"
echo "=========================="
echo ""

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

DEMO_DIR="./kustomize-demo"

# Create directory structure
echo -e "${BLUE}Step 1: Creating directory structure...${NC}"
mkdir -p $DEMO_DIR/base
mkdir -p $DEMO_DIR/overlays/{dev,staging,prod}
echo -e "${GREEN}✓ Directories created${NC}"
echo ""

# Base deployment
echo -e "${BLUE}Step 2: Creating base manifests...${NC}"
cat > $DEMO_DIR/base/deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pharma-api
  labels:
    app: pharma-api
spec:
  replicas: 1
  selector:
    matchLabels:
      app: pharma-api
  template:
    metadata:
      labels:
        app: pharma-api
    spec:
      containers:
      - name: pharma-api
        image: nginx:1.25
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
EOF

cat > $DEMO_DIR/base/service.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: pharma-api
spec:
  selector:
    app: pharma-api
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF

cat > $DEMO_DIR/base/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml
- service.yaml
EOF

echo -e "${GREEN}✓ Base manifests created${NC}"
echo ""

# Dev overlay
echo -e "${BLUE}Step 3: Creating environment overlays...${NC}"
cat > $DEMO_DIR/overlays/dev/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base

namePrefix: dev-

patches:
- patch: |-
    - op: replace
      path: /spec/replicas
      value: 1
    - op: replace
      path: /spec/template/spec/containers/0/image
      value: nginx:latest
  target:
    kind: Deployment
    name: pharma-api

labels:
- pairs:
    environment: dev
  includeSelectors: false
EOF

# Staging overlay
cat > $DEMO_DIR/overlays/staging/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base

namePrefix: staging-

patches:
- patch: |-
    - op: replace
      path: /spec/replicas
      value: 2
  target:
    kind: Deployment
    name: pharma-api

labels:
- pairs:
    environment: staging
  includeSelectors: false
EOF

# Prod overlay
cat > $DEMO_DIR/overlays/prod/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base

namePrefix: prod-

patches:
- patch: |-
    - op: replace
      path: /spec/replicas
      value: 3
  target:
    kind: Deployment
    name: pharma-api
- patch: |-
    - op: replace
      path: /spec/type
      value: NodePort
  target:
    kind: Service
    name: pharma-api

labels:
- pairs:
    environment: prod
  includeSelectors: false
EOF

echo -e "${GREEN}✓ Overlays created (dev/staging/prod)${NC}"
echo ""

# Verify rendering
echo -e "${BLUE}Step 4: Verifying renders...${NC}"
echo ""
echo "--- Base ---"
kubectl kustomize $DEMO_DIR/base/

echo ""
echo "--- Dev overlay ---"
kubectl kustomize $DEMO_DIR/overlays/dev/

echo ""
echo "=========================="
echo -e "${GREEN}✓ Setup complete!${NC}"
echo ""
echo "Run next:"
echo "  ./scripts/test.sh"