# Lab 05: etcd Backup & Restore Quick Reference

## Essential etcd Commands

### Environment Setup

```bash
# Always set API version
export ETCDCTL_API=3

# Certificate paths (standard kubeadm locations)
CA_CERT=/etc/kubernetes/pki/etcd/ca.crt
SERVER_CERT=/etc/kubernetes/pki/etcd/server.crt
SERVER_KEY=/etc/kubernetes/pki/etcd/server.key
ENDPOINT=https://127.0.0.1:2379
```

---

## Backup

### Quick Backup

```bash
ETCDCTL_API=3 etcdctl snapshot save /tmp/etcd-backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

### Verify Backup

```bash
ETCDCTL_API=3 etcdctl snapshot status /tmp/etcd-backup.db

# With table format
ETCDCTL_API=3 etcdctl snapshot status /tmp/etcd-backup.db -w table
```

### Backup with Timestamp

```bash
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
ETCDCTL_API=3 etcdctl snapshot save /backup/etcd-$TIMESTAMP.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

---

## Restore

### Complete Restore Process

```bash
# 1. Stop kubelet (stops API server and etcd)
sudo systemctl stop kubelet

# 2. Restore snapshot to new directory
ETCDCTL_API=3 etcdctl snapshot restore /tmp/etcd-backup.db \
  --data-dir=/var/lib/etcd-restored \
  --name=master \
  --initial-cluster=master=https://192.168.1.10:2380 \
  --initial-advertise-peer-urls=https://192.168.1.10:2380

# 3. Update etcd manifest
sudo vim /etc/kubernetes/manifests/etcd.yaml
# Change: --data-dir=/var/lib/etcd
# To:     --data-dir=/var/lib/etcd-restored

# 4. Start kubelet (etcd restarts automatically)
sudo systemctl start kubelet

# 5. Verify
kubectl get nodes
kubectl get pods -A
```

---

## Finding etcd Information

### Get etcd Pod Name

```bash
kubectl get pod -n kube-system | grep etcd
# Output: etcd-master
```

### Get Certificate Paths

```bash
kubectl describe pod -n kube-system etcd-master | grep -E 'cert|key|ca'
```

### Get etcd Data Directory

```bash
kubectl describe pod -n kube-system etcd-master | grep data-dir
```

### Get etcd Endpoints

```bash
kubectl describe pod -n kube-system etcd-master | grep listen-client-urls
```

---

## Exam Scenarios

### Scenario 1: Create Backup

**Question:** Create an etcd backup at `/tmp/etcd-snapshot.db`

```bash
ETCDCTL_API=3 etcdctl snapshot save /tmp/etcd-snapshot.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

### Scenario 2: Verify Backup

**Question:** Verify the backup at `/data/backup.db`

```bash
ETCDCTL_API=3 etcdctl snapshot status /data/backup.db
```

### Scenario 3: Restore from Backup

**Question:** Restore cluster from `/backup/snapshot.db`

```bash
# Stop kubelet
sudo systemctl stop kubelet

# Restore
ETCDCTL_API=3 etcdctl snapshot restore /backup/snapshot.db \
  --data-dir=/var/lib/etcd-from-backup

# Edit manifest
sudo vi /etc/kubernetes/manifests/etcd.yaml
# Change data-dir to /var/lib/etcd-from-backup

# Start kubelet
sudo systemctl start kubelet
```

---

## Troubleshooting

### Error: "context deadline exceeded"

**Cause:** Wrong endpoint or certificates

**Solution:**
```bash
# Verify endpoint
kubectl describe pod -n kube-system etcd-master | grep advertise-client-urls

# Verify certificates exist
ls -la /etc/kubernetes/pki/etcd/
```

### Error: "permission denied"

**Cause:** Running without sudo or wrong file permissions

**Solution:**
```bash
# Run with sudo
sudo ETCDCTL_API=3 etcdctl ...

# Or fix permissions
sudo chown $(whoami) /path/to/backup.db
```

### Error: "database space exceeded"

**Cause:** etcd database full

**Solution:**
```bash
# Compact etcd
ETCDCTL_API=3 etcdctl compact $(ETCDCTL_API=3 etcdctl endpoint status --write-out="json" | grep -o '"revision":[0-9]*' | awk -F':' '{print $2}')

# Defragment
ETCDCTL_API=3 etcdctl defrag
```

### Error: "data-dir already exists"

**Cause:** Trying to restore to existing directory

**Solution:**
```bash
# Use different directory
--data-dir=/var/lib/etcd-new

# Or move old directory
sudo mv /var/lib/etcd /var/lib/etcd.old
```

---

## Production Best Practices

### Automated Backup Script

```bash
#!/bin/bash
# /usr/local/bin/backup-etcd.sh

BACKUP_DIR=/backup/etcd
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Create backup
ETCDCTL_API=3 etcdctl snapshot save $BACKUP_DIR/etcd-$TIMESTAMP.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Verify
ETCDCTL_API=3 etcdctl snapshot status $BACKUP_DIR/etcd-$TIMESTAMP.db

# Cleanup old backups (keep 30 days)
find $BACKUP_DIR -name "etcd-*.db" -mtime +30 -delete
```

### Cron Schedule

```bash
# Backup every 6 hours
0 */6 * * * root /usr/local/bin/backup-etcd.sh
```

### Off-site Storage

```bash
# Copy to S3
aws s3 cp /backup/etcd-$TIMESTAMP.db s3://k8s-backups/etcd/

# Copy to Azure Blob
az storage blob upload \
  --account-name backups \
  --container-name etcd \
  --file /backup/etcd-$TIMESTAMP.db
```

---

## Exam Cheat Sheet

**Complete backup command:**
```bash
ETCDCTL_API=3 etcdctl snapshot save /tmp/backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

**Complete restore commands:**
```bash
sudo systemctl stop kubelet
ETCDCTL_API=3 etcdctl snapshot restore /tmp/backup.db --data-dir=/var/lib/etcd-new
sudo vi /etc/kubernetes/manifests/etcd.yaml  # Change data-dir
sudo systemctl start kubelet
```

**Verify commands:**
```bash
ETCDCTL_API=3 etcdctl snapshot status /tmp/backup.db
kubectl get nodes
kubectl get pods -A
```

---

## Key Points to Remember

✅ **ALWAYS set ETCDCTL_API=3**
✅ **Backup requires certificates** (ca.crt, server.crt, server.key)
✅ **Restore is DESTRUCTIVE** (replaces all cluster state)
✅ **Test backups regularly** (monthly restore test)
✅ **Store backups off-site** (S3, Azure, multiple locations)
✅ **Restore to NEW data-dir** (not existing one)
✅ **Update etcd manifest** after restore
✅ **Restart kubelet** to apply changes

---

## Time Budget (Exam)

- Find certificate paths: **1 minute**
- Create backup: **2 minutes**
- Verify backup: **1 minute**
- Restore backup: **5 minutes**
- Verify restore: **1 minute**
- **Total: ~10 minutes**