#!/bin/bash
# Lab 05: etcd Backup & Restore - Restore Script
# Works on: minikube (conceptual), kubeadm (full restore)

set -e

echo "🔄 Lab 05: etcd Restore"
echo "======================="
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if backup file provided
if [ -z "$1" ]; then
    echo -e "${YELLOW}Usage: $0 <backup-file>${NC}"
    echo ""
    echo "Available backups:"
    ls -lh ./backups/*.db 2>/dev/null | grep -v ".info" || echo "  No backups found"
    echo ""
    echo "Example:"
    echo "  $0 ./backups/etcd-backup-20260323-093705.db"
    exit 1
fi

BACKUP_FILE=$1

if [ ! -f "$BACKUP_FILE" ]; then
    echo -e "${RED}Error: Backup file not found: $BACKUP_FILE${NC}"
    exit 1
fi

BACKUP_SIZE=$(ls -lh "$BACKUP_FILE" | awk '{print $5}')
echo -e "${BLUE}Backup file: $BACKUP_FILE${NC}"
echo -e "${BLUE}Backup size: $BACKUP_SIZE${NC}"
echo ""

# Detect cluster
echo -e "${BLUE}Step 1: Detecting cluster type...${NC}"
echo ""

ETCD_POD=$(kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$ETCD_POD" ]; then
    echo -e "${YELLOW}⚠️  Managed cluster (AKS/EKS/GKE)${NC}"
    echo "Use Velero for restore: velero restore create --from-backup <backup-name>"
    exit 1
fi

echo -e "${GREEN}✓ etcd pod found: $ETCD_POD${NC}"
echo ""

# Verify backup
echo -e "${BLUE}Step 2: Verifying backup integrity...${NC}"
echo ""

# Copy backup to minikube node first
if command -v minikube &> /dev/null; then
    minikube ssh "sudo rm -f /home/docker/restore-backup.db" 2>/dev/null || true
    cat "$BACKUP_FILE" | minikube ssh "sudo tee /home/docker/restore-backup.db > /dev/null"
    
    # Copy to container
    minikube ssh "sudo docker cp /home/docker/restore-backup.db \$(sudo docker ps -qf 'name=k8s_etcd' | head -n 1):/tmp/restore-verify.db"
    
    # Verify
    kubectl exec -n kube-system $ETCD_POD -- \
      etcdutl snapshot status /tmp/restore-verify.db --write-out=table
else
    echo "Skipping verification"
fi

echo ""
echo -e "${GREEN}✓ Backup is valid${NC}"
echo ""

echo -e "${RED}⚠️  WARNING: RESTORE IS DESTRUCTIVE!${NC}"
echo ""
echo "Restore will:"
echo "  - Replace ALL current cluster state"
echo "  - Restore to backup point-in-time"
echo "  - Lose any changes after backup"
echo ""

echo -e "${YELLOW}=== Restore Process ===${NC}"
echo ""

echo "█ On kubeadm (Production Clusters):"
echo ""
cat << 'EOF'
# 1. SSH to control plane
ssh master

# 2. Copy backup to control plane
scp /path/to/backup.db master:/tmp/

# 3. Stop kubelet (stops API server and etcd)
sudo systemctl stop kubelet

# 4. Backup current etcd data (safety)
sudo mv /var/lib/etcd /var/lib/etcd.old

# 5. Restore snapshot
sudo ETCDCTL_API=3 etcdctl snapshot restore /tmp/backup.db \
  --data-dir=/var/lib/etcd-restored \
  --name=master \
  --initial-cluster=master=https://192.168.1.10:2380 \
  --initial-advertise-peer-urls=https://192.168.1.10:2380

# 6. Update etcd manifest
sudo vi /etc/kubernetes/manifests/etcd.yaml
# Change: --data-dir=/var/lib/etcd
# To:     --data-dir=/var/lib/etcd-restored

# 7. Start kubelet (etcd restarts automatically)
sudo systemctl start kubelet

# 8. Wait and verify (30-60 seconds)
sleep 30
kubectl get nodes
kubectl get all -n backup-test
EOF

echo ""
echo ""
echo "█ On minikube (Local Development):"
echo ""
cat << 'EOF'
# Minikube restore is complex due to:
# - etcd runs in container with no direct access
# - Would require stopping entire minikube
# - Data-dir is container-specific

# For learning:
# 1. Understand the restore commands above
# 2. Practice on kubeadm cluster or VMs
# 3. For minikube, recreate cluster instead

# Alternative: Delete and recreate
minikube delete
minikube start --nodes=3
# Then restore application manifests
EOF

echo ""
echo ""
echo "█ On AKS/EKS/GKE (Managed Clusters):"
echo ""
cat << 'EOF'
# You CANNOT restore etcd directly
# Use these alternatives:

# Option 1: Velero
velero restore create --from-backup my-backup

# Option 2: kubectl apply from backup
kubectl apply -f cluster-backup.yaml

# Option 3: Cloud-native tools
# AKS: Azure Backup for AKS
# EKS: AWS Backup
# GKE: Backup for GKE
EOF

echo ""
echo ""
echo "======================="
echo -e "${GREEN}Restore process documented!${NC}"
echo ""

echo -e "${YELLOW}=== Key Restore Concepts ===${NC}"
echo ""
echo "✓ Restore replaces ALL cluster state"
echo "✓ Must stop kubelet first (kubeadm)"
echo "✓ Restore to NEW data directory"
echo "✓ Update etcd manifest with new path"
echo "✓ Restart kubelet to apply changes"
echo "✓ Wait 30-60s for cluster to stabilize"
echo "✓ Verify all resources restored"
echo ""

echo -e "${YELLOW}=== For CKA Exam ===${NC}"
echo ""
echo "Commands you need to know:"
echo ""
echo "# Stop kubelet"
echo "sudo systemctl stop kubelet"
echo ""
echo "# Restore"
echo "sudo ETCDCTL_API=3 etcdctl snapshot restore /backup.db \\"
echo "  --data-dir=/var/lib/etcd-new"
echo ""
echo "# Update manifest"
echo "sudo vi /etc/kubernetes/manifests/etcd.yaml"
echo "# Change --data-dir path"
echo ""
echo "# Start kubelet"
echo "sudo systemctl start kubelet"
echo ""
echo "# Verify"
echo "kubectl get nodes"
echo "kubectl get all -A"
echo ""

echo "Practice workflow:"
echo "  1. ./scripts/backup-etcd.sh"
echo "  2. ./scripts/create-test-data.sh"
echo "  3. kubectl delete namespace backup-test"
echo "  4. (On kubeadm: restore from backup)"
echo "  5. ./scripts/verify-restore.sh"
echo ""
echo "Time budget for exam: ~10 minutes"