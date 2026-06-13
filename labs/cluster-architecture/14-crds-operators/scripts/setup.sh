#!/bin/bash
# Lab 14: CRDs and Operators - Setup Script

set -e

echo "🔧 Lab 14: CRDs and Operators Setup"
echo "====================================="
echo ""

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="lab14-crds"

echo -e "${BLUE}Step 1: Creating namespace...${NC}"
kubectl create namespace $NAMESPACE 2>/dev/null || echo "Already exists"
echo -e "${GREEN}✓ Namespace: $NAMESPACE${NC}"
echo ""

echo -e "${BLUE}Step 2: Creating BackupPolicy CRD...${NC}"
cat > manifests/backuppolicy-crd.yaml << 'EOF'
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: backuppolicies.ops.example.com
spec:
  group: ops.example.com
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            required: ["schedule", "retentionDays"]
            properties:
              schedule:
                type: string
              retentionDays:
                type: integer
                minimum: 1
                maximum: 365
              target:
                type: string
              enabled:
                type: boolean
                default: true
          status:
            type: object
            properties:
              lastBackup:
                type: string
              phase:
                type: string
  scope: Namespaced
  names:
    plural: backuppolicies
    singular: backuppolicy
    kind: BackupPolicy
    shortNames:
    - bp
EOF

kubectl apply -f manifests/backuppolicy-crd.yaml

kubectl wait --for=condition=Established \
  crd/backuppolicies.ops.example.com --timeout=30s
echo -e "${GREEN}✓ CRD: backuppolicies.ops.example.com${NC}"
echo ""

echo -e "${BLUE}Step 3: Creating BackupPolicy instances...${NC}"
cat > manifests/db-backup-policy.yaml << 'EOF'
apiVersion: ops.example.com/v1
kind: BackupPolicy
metadata:
  name: database-backup
  namespace: lab14-crds
spec:
  schedule: "0 2 * * *"
  retentionDays: 30
  target: "postgres-db"
  enabled: true
EOF

cat > manifests/config-backup-policy.yaml << 'EOF'
apiVersion: ops.example.com/v1
kind: BackupPolicy
metadata:
  name: config-backup
  namespace: lab14-crds
spec:
  schedule: "0 */6 * * *"
  retentionDays: 7
  target: "app-config"
  enabled: true
EOF

kubectl apply -f manifests/db-backup-policy.yaml
kubectl apply -f manifests/config-backup-policy.yaml
echo -e "${GREEN}✓ BackupPolicy instances created${NC}"
echo ""

echo "====================================="
echo -e "${GREEN}✓ Setup complete!${NC}"
echo ""
echo "CRD registered:"
kubectl get crd backuppolicies.ops.example.com
echo ""
echo "Custom resources:"
kubectl get backuppolicies -n $NAMESPACE
echo ""
echo "Run: ./scripts/test.sh"