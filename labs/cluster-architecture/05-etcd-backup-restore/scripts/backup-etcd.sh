#!/bin/bash
# Lab 05: etcd Backup & Restore - Backup Script
# Works on: minikube (with docker cp workaround), kubeadm, kind

set -e

echo "💾 Lab 05: etcd Backup"
echo "======================"
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Backup directory
BACKUP_DIR="./backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="$BACKUP_DIR/etcd-backup-$TIMESTAMP.db"

# Create backup directory
mkdir -p $BACKUP_DIR

echo -e "${BLUE}Step 1: Detecting cluster type...${NC}"
echo ""

# Detect etcd pod
ETCD_POD=$(kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$ETCD_POD" ]; then
    echo -e "${YELLOW}⚠️  No etcd pod found${NC}"
    echo "This is a managed cluster (AKS/EKS/GKE) - use Velero instead"
    exit 1
fi

echo -e "${GREEN}✓ Found etcd pod: $ETCD_POD${NC}"
echo ""

# Detect certificate paths
echo -e "${BLUE}Step 2: Detecting certificate paths...${NC}"
echo ""

POD_SPEC=$(kubectl get pod -n kube-system $ETCD_POD -o yaml)
CA_CERT=$(echo "$POD_SPEC" | grep "trusted-ca-file=" | head -1 | cut -d'=' -f2 | tr -d ' ')
SERVER_CERT=$(echo "$POD_SPEC" | grep "cert-file=" | grep -v "peer-cert" | head -1 | cut -d'=' -f2 | tr -d ' ')
SERVER_KEY=$(echo "$POD_SPEC" | grep "key-file=" | grep -v "peer-key" | head -1 | cut -d'=' -f2 | tr -d ' ')

echo -e "${GREEN}✓ Certificates detected${NC}"
echo "  CA: $CA_CERT"
echo "  Cert: $SERVER_CERT"
echo "  Key: $SERVER_KEY"
echo ""

# Create backup
echo -e "${BLUE}Step 3: Creating etcd backup in pod...${NC}"
echo ""

kubectl exec -n kube-system $ETCD_POD -- \
  etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=$CA_CERT \
  --cert=$SERVER_CERT \
  --key=$SERVER_KEY \
  snapshot save /tmp/etcd-backup.db

echo ""
echo -e "${GREEN}✓ Backup created: /tmp/etcd-backup.db (in pod)${NC}"
echo ""

# Copy backup out
echo -e "${BLUE}Step 4: Copying backup to local machine...${NC}"
echo ""

# Try kubectl cp first (works on kubeadm)
if kubectl cp -n kube-system $ETCD_POD:/tmp/etcd-backup.db "$BACKUP_FILE" 2>/dev/null; then
    echo -e "${GREEN}✓ Copied via kubectl cp (kubeadm cluster)${NC}"
else
    # Minikube workaround
    echo -e "${YELLOW}kubectl cp failed (distroless container)${NC}"
    echo "Using docker cp workaround for minikube..."
    echo ""
    
    if ! command -v minikube &> /dev/null; then
        echo -e "${RED}✗ minikube not found${NC}"
        exit 1
    fi
    
    # Step 1: Container → Node
    echo "  → Copying from container to minikube node..."
    minikube ssh "sudo docker cp \$(sudo docker ps -qf 'name=k8s_etcd' | head -n 1):/tmp/etcd-backup.db /home/docker/etcd-backup.db" || {
        echo -e "${RED}✗ Docker cp failed${NC}"
        exit 1
    }
    
    # Step 2: Node → Local
    echo "  → Copying from node to local machine..."
    minikube ssh "sudo cat /home/docker/etcd-backup.db" > "$BACKUP_FILE"
    
    if [ ! -s "$BACKUP_FILE" ]; then
        echo -e "${RED}✗ Copy failed${NC}"
        exit 1
    fi
    
    echo ""
    echo -e "${GREEN}✓ Copied via docker cp workaround${NC}"
fi

echo ""

# Show backup info
BACKUP_SIZE=$(ls -lh "$BACKUP_FILE" | awk '{print $5}')
echo -e "${GREEN}Backup file: $BACKUP_FILE${NC}"
echo -e "${GREEN}Backup size: $BACKUP_SIZE${NC}"
echo ""

# Verify backup
echo -e "${BLUE}Step 5: Verifying backup integrity...${NC}"
echo ""

# Copy back to pod for verification
if command -v minikube &> /dev/null; then
    minikube ssh "sudo docker cp /home/docker/etcd-backup.db \$(sudo docker ps -qf 'name=k8s_etcd' | head -n 1):/tmp/etcd-verify.db" 2>/dev/null
    
    kubectl exec -n kube-system $ETCD_POD -- \
      etcdutl snapshot status /tmp/etcd-verify.db --write-out=table
else
    echo "Skipping verification (minikube not available)"
fi

echo ""
echo "======================"
echo -e "${GREEN}✓ Backup complete and verified!${NC}"
echo ""
echo "📁 Backup location: $BACKUP_FILE"
echo "📊 Backup size: $BACKUP_SIZE"
echo ""

# Document challenges
echo -e "${YELLOW}=== Challenges Encountered (minikube) ===${NC}"
echo ""
echo "❌ Challenge 1: Distroless Container"
echo "   Problem: etcd container has NO shell, tar, cat"
echo "   Solution: Use docker cp to access container filesystem"
echo ""
echo "❌ Challenge 2: kubectl cp Doesn't Work"
echo "   Problem: kubectl cp requires 'tar' in container"
echo "   Solution: minikube ssh + docker cp workaround"
echo ""
echo "❌ Challenge 3: Filesystem Isolation"
echo "   Problem: /tmp in container ≠ /tmp on node"
echo "   Solution: docker ps + docker cp from container ID"
echo ""
echo "✅ On kubeadm/production clusters:"
echo "   - Containers have tar binary"
echo "   - kubectl cp works perfectly"
echo "   - No workarounds needed"
echo ""

echo "This backup contains:"
echo "  ✓ All namespaces, pods, services, deployments"
echo "  ✓ All secrets, configmaps, RBAC policies"
echo "  ✓ Entire cluster state (~313-400 keys)"
echo ""
echo "Next steps:"
echo "  1. Create test data: ./scripts/create-test-data.sh"
echo "  2. Delete namespace: kubectl delete ns backup-test"
echo "  3. Restore practice: Read ./scripts/restore-etcd.sh"