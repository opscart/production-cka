# Lab 05: etcd Backup & Restore - Solution Guide

## Complete Workflow: Backup → Disaster → Restore

This solution demonstrates the complete disaster recovery process.

---

## Step 1: Create Initial Backup (3 minutes)

### 1.1: Find etcd Pod and Certificates

```bash
# Get etcd pod name
kubectl get pod -n kube-system | grep etcd
# Output: etcd-master

# Verify certificates exist
kubectl exec -n kube-system etcd-master -- ls -la /etc/kubernetes/pki/etcd/

# Expected output:
# ca.crt
# ca.key
# server.crt
# server.key
```

### 1.2: Create Backup

```bash
# Set environment variable
export ETCDCTL_API=3

# Create backup inside etcd pod
kubectl exec -n kube-system etcd-master -- \
  etcdctl snapshot save /tmp/etcd-backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Output:
# Snapshot saved at /tmp/etcd-backup.db
```

### 1.3: Verify Backup

```bash
# Verify backup integrity
kubectl exec -n kube-system etcd-master -- \
  etcdctl snapshot status /tmp/etcd-backup.db

# With table format for better readability
kubectl exec -n kube-system etcd-master -- \
  etcdctl snapshot status /tmp/etcd-backup.db -w table

# Expected output:
# +----------+----------+------------+------------+
# |   HASH   | REVISION | TOTAL KEYS | TOTAL SIZE |
# +----------+----------+------------+------------+
# | 12345... |    15432 |       1234 |     3.5 MB |
# +----------+----------+------------+------------+
```

### 1.4: Copy Backup to Safe Location

```bash
# Copy backup out of pod
kubectl cp -n kube-system etcd-master:/tmp/etcd-backup.db ./etcd-backup.db

# Verify local copy
ls -lh etcd-backup.db

# In production, copy to:
# - S3: aws s3 cp etcd-backup.db s3://backups/
# - Azure: az storage blob upload ...
# - NAS: scp etcd-backup.db user@nas:/backups/
```

---

## Step 2: Create Test Data (2 minutes)

### 2.1: Create Resources

```bash
# Create namespace
kubectl create namespace backup-test

# Create deployment
kubectl create deployment nginx-test --image=nginx --replicas=3 -n backup-test

# Wait for pods
kubectl wait --for=condition=ready pod -l app=nginx-test -n backup-test --timeout=60s

# Create configmap
kubectl create configmap test-config \
  --from-literal=key1=value1 \
  --from-literal=app=backup-test \
  -n backup-test

# Create secret
kubectl create secret generic test-secret \
  --from-literal=password=supersecret \
  -n backup-test

# Create service
kubectl expose deployment nginx-test --port=80 -n backup-test
```

### 2.2: Document Current State

```bash
# Save current state
kubectl get all,cm,secret -n backup-test > before-disaster.txt

# View what we created
cat before-disaster.txt
```

---

## Step 3: Simulate Disaster (30 seconds)

### 3.1: Delete Everything

```bash
# Simulate disaster - delete entire namespace
kubectl delete namespace backup-test

# Verify it's gone
kubectl get namespace backup-test
# Error from server (NotFound): namespaces "backup-test" not found

# Try to get resources
kubectl get all -n backup-test
# No resources found in backup-test namespace
```

**Disaster scenarios in production:**
- Accidental `kubectl delete namespace production`
- Script error deleting wrong resources
- Malicious activity
- Hardware failure
- Database corruption

---

## Step 4: Restore from Backup (5-7 minutes)

### 4.1: Stop kubelet (on control plane)

```bash
# SSH to control plane node
ssh master

# Stop kubelet (this stops API server and etcd)
sudo systemctl stop kubelet

# Verify kubelet stopped
sudo systemctl status kubelet
# Should show: inactive (dead)
```

### 4.2: Backup Current etcd Data (Safety)

```bash
# Move current etcd data directory (just in case)
sudo mv /var/lib/etcd /var/lib/etcd.old

# Verify
ls -la /var/lib/ | grep etcd
# Should show: etcd.old
```

### 4.3: Restore Snapshot

```bash
# Restore snapshot to new directory
sudo ETCDCTL_API=3 etcdctl snapshot restore /path/to/etcd-backup.db \
  --data-dir=/var/lib/etcd-restored \
  --name=master \
  --initial-cluster=master=https://192.168.1.10:2380 \
  --initial-advertise-peer-urls=https://192.168.1.10:2380

# Output:
# 2024-01-15 10:30:00.123456 I | mvcc: restore compact to 12345
# 2024-01-15 10:30:00.234567 I | etcdserver/membership: added member...
# ...
# 2024-01-15 10:30:01.345678 I | snapshot: restored snapshot
```

**Parameters explained:**
- `--data-dir`: Where to restore the data
- `--name`: Node name (must match cluster config)
- `--initial-cluster`: Cluster member list
- `--initial-advertise-peer-urls`: This node's peer URL

### 4.4: Update etcd Manifest

```bash
# Edit etcd static pod manifest
sudo vi /etc/kubernetes/manifests/etcd.yaml

# Find this line:
    - --data-dir=/var/lib/etcd

# Change to:
    - --data-dir=/var/lib/etcd-restored

# Save and exit (:wq)
```

**Important:** The kubelet watches `/etc/kubernetes/manifests/` and will automatically restart etcd when the manifest changes.

### 4.5: Start kubelet

```bash
# Start kubelet
sudo systemctl start kubelet

# Verify kubelet started
sudo systemctl status kubelet
# Should show: active (running)

# Exit SSH
exit
```

### 4.6: Wait for Cluster to Come Up

```bash
# Wait a moment for cluster to start
sleep 30

# Check if API server is responsive
kubectl get nodes

# If it times out, wait longer (can take 1-2 minutes)
```

---

## Step 5: Verify Restore (2 minutes)

### 5.1: Check Cluster Health

```bash
# Check all nodes are Ready
kubectl get nodes

# Expected:
# NAME     STATUS   ROLES           AGE   VERSION
# master   Ready    control-plane   2d    v1.34.0
# worker1  Ready    <none>          2d    v1.34.0
# worker2  Ready    <none>          2d    v1.34.0

# Check system pods
kubectl get pods -n kube-system

# All should be Running
```

### 5.2: Verify Test Data Restored

```bash
# Check namespace exists
kubectl get namespace backup-test

# Check all resources
kubectl get all,cm,secret -n backup-test

# Expected output (compare with before-disaster.txt):
# NAME                              READY   STATUS    RESTARTS   AGE
# pod/nginx-test-xxx                1/1     Running   0          5m
# pod/nginx-test-yyy                1/1     Running   0          5m
# pod/nginx-test-zzz                1/1     Running   0          5m
#
# NAME                 TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
# service/nginx-test   ClusterIP   10.96.123.456   <none>        80/TCP    5m
#
# NAME                         READY   UP-TO-DATE   AVAILABLE   AGE
# deployment.apps/nginx-test   3/3     3            3           5m
#
# NAME                DATA   AGE
# configmap/test-config   2      5m
#
# NAME                 TYPE     DATA   AGE
# secret/test-secret   Opaque   1      5m
```

### 5.3: Verify Data Integrity

```bash
# Check ConfigMap data
kubectl get configmap test-config -n backup-test -o yaml

# Should contain:
# data:
#   app: backup-test
#   key1: value1

# Check Secret data
kubectl get secret test-secret -n backup-test -o jsonpath='{.data.password}' | base64 -d

# Should output: supersecret
```

### 5.4: Test Application Functionality

```bash
# Test that the service works
kubectl run test-curl --image=curlimages/curl --rm -it --restart=Never -n backup-test -- \
  curl -s -o /dev/null -w "%{http_code}" http://nginx-test

# Should output: 200 (HTTP OK)
```

---

## Exam Simulation (10 minutes total)

**Scenario:** The production cluster lost data. Restore from backup at `/data/etcd-backup.db`

```bash
# === Backup (if not exists) - 2 min ===
kubectl exec -n kube-system etcd-master -- \
  etcdctl snapshot save /tmp/backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# === Restore - 5 min ===
# SSH to master
ssh master

# Stop kubelet
sudo systemctl stop kubelet

# Restore
sudo ETCDCTL_API=3 etcdctl snapshot restore /data/etcd-backup.db \
  --data-dir=/var/lib/etcd-restored

# Update manifest
sudo sed -i 's|--data-dir=/var/lib/etcd|--data-dir=/var/lib/etcd-restored|' \
  /etc/kubernetes/manifests/etcd.yaml

# Start kubelet
sudo systemctl start kubelet
exit

# === Verify - 2 min ===
sleep 30
kubectl get nodes
kubectl get pods -A
kubectl get all -n <namespace-to-verify>
```

---

## Common Issues & Solutions

### Issue: API Server Won't Start After Restore

**Symptoms:**
```bash
kubectl get nodes
# The connection to the server localhost:8080 was refused
```

**Debug:**
```bash
# Check kubelet logs
sudo journalctl -u kubelet -n 50

# Check etcd logs
sudo crictl logs <etcd-container-id>

# Verify etcd manifest
sudo cat /etc/kubernetes/manifests/etcd.yaml | grep data-dir
```

**Solution:**
```bash
# Ensure data-dir path is correct
# Ensure ownership is correct
sudo chown -R root:root /var/lib/etcd-restored

# Restart kubelet
sudo systemctl restart kubelet
```

### Issue: Restored Data is Old

**Problem:** Restored from old backup, recent data missing

**Solution:**
- Always restore from most recent backup
- Implement backup frequency: every 6 hours or less
- Monitor backup timestamps

### Issue: Restore Failed - Data Dir Exists

**Error:**
```
Error: data-dir "/var/lib/etcd" exists
```

**Solution:**
```bash
# Use different directory
--data-dir=/var/lib/etcd-new

# Or rename old directory
sudo mv /var/lib/etcd /var/lib/etcd.backup
```

---

## Key Takeaways

✅ **etcd is critical** - Contains ALL cluster state
✅ **Regular backups essential** - Every 6 hours minimum
✅ **Test restores monthly** - Verify backup integrity
✅ **Restore is destructive** - Replaces all current state
✅ **Off-site storage required** - Don't keep only on cluster
✅ **Document procedures** - RTO/RPO requirements
✅ **Certificates required** - For backup and restore
✅ **Update manifest** - Change data-dir after restore

---

**Completed Lab 05?** ✅

Move to **[Lab 06: Helm Basics](../06-helm-basics/)**