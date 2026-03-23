# Lab 05: etcd Backup & Restore

## Objective
Master etcd backup and restore procedures, understand disaster recovery workflows, and implement production-grade backup strategies for Kubernetes cluster state.

## CKA Exam Relevance
- **Domain:** Cluster Architecture, Installation & Configuration (25%)
- **Topic:** Manage etcd backup and restore
- **Exam Weight:** Very High (appears in 95%+ of exams)
- **Typical Exam Time:** 8-10 minutes

## Time to Complete
45 minutes

## Scenario
Your pharmaceutical company's production Kubernetes cluster experienced a catastrophic failure. A misconfigured deployment accidentally deleted critical namespaces and resources. You need to:
- Restore the cluster from the last etcd backup
- Verify data integrity
- Document the restore procedure
- Implement automated backup strategy

This is a real scenario - etcd is the single source of truth for all cluster state!

## Prerequisites
- Completed Labs 01-04
- Understanding of cluster components
- Basic understanding of etcd architecture
- Existing minikube cluster running

## What is etcd?

**etcd** is a distributed key-value store that holds ALL Kubernetes cluster state:
- All pods, deployments, services
- Secrets, configmaps
- RBAC policies
- Network policies
- Everything!

**If etcd fails or is corrupted, you lose your entire cluster state.**

---

## etcd Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                    │
│                                                          │
│  ┌──────────────┐                                       │
│  │  kubectl     │─────┐                                 │
│  └──────────────┘     │                                 │
│                       ▼                                 │
│              ┌─────────────────┐                        │
│              │  kube-apiserver │                        │
│              └────────┬────────┘                        │
│                       │                                 │
│                       │ Read/Write                      │
│                       │                                 │
│              ┌────────▼────────┐                        │
│              │      etcd       │◄─── Backup            │
│              │                 │                        │
│              │ Key-Value Store │                        │
│              │                 │                        │
│              │  /registry/     │                        │
│              │    pods/...     │                        │
│              │    services/... │                        │
│              │    secrets/...  │                        │
│              └─────────────────┘                        │
│                                                          │
└──────────────────────────────────────────────────────────┘

Backup creates snapshot of ENTIRE etcd database
Restore replaces current etcd with snapshot data
```

---

## Lab Structure

```
lab05-etcd-backup-restore/
├── README.md
├── QUICK-REFERENCE.md
├── scripts/
│   ├── backup-etcd.sh          # Create etcd backup
│   ├── create-test-data.sh     # Create test resources
│   ├── restore-etcd.sh         # Restore from backup
│   └── verify-restore.sh       # Verify restored data
└── solutions/
    └── SOLUTION.md
```

---

## ⚠️ Minikube-Specific Challenges & Solutions

**Important:** This lab works differently on minikube vs production kubeadm clusters. Understanding these differences is valuable learning.

### Challenge 1: Distroless etcd Container

**Problem:**
- Minikube's etcd container is "distroless" (minimal security container)
- Contains ONLY `etcd` and `etcdctl` binaries
- No shell (`sh`, `bash`), no `tar`, no `cat`, no standard Linux utilities
- Cannot execute typical commands: `kubectl exec etcd-pod -- cat /file`

**Why This Exists:**
- Security best practice: Minimal attack surface
- Reduces container size and vulnerability
- Common in production Kubernetes

**Solution:**
```bash
# ❌ This fails
kubectl exec etcd-pod -- cat /tmp/backup.db

# ✅ This works - use docker cp
minikube ssh "sudo docker cp \$(sudo docker ps -qf 'name=k8s_etcd'):/tmp/backup.db /home/docker/backup.db"
minikube ssh "sudo cat /home/docker/backup.db" > ./backup.db
```

---

### Challenge 2: kubectl cp Doesn't Work

**Problem:**
- `kubectl cp` requires `tar` binary inside the container
- Distroless containers don't have `tar`
- Error: `tar: not found` or `exit code 126`

**Why This Exists:**
- `kubectl cp` internally uses `tar` to create archives
- Works fine on kubeadm clusters (containers have tar)
- Minikube uses ultra-minimal containers

**Solution:**
```bash
# ❌ This fails on minikube
kubectl cp etcd-pod:/tmp/backup.db ./backup.db
# Error: OCI runtime exec failed: exec: "tar": executable file not found

# ✅ Use docker cp workaround
# Step 1: Container → Node
minikube ssh "sudo docker cp CONTAINER_ID:/tmp/backup.db /home/docker/backup.db"

# Step 2: Node → Local
minikube ssh "sudo cat /home/docker/backup.db" > ./backup.db
```

---

### Challenge 3: Filesystem Isolation

**Problem:**
- `/tmp` in the etcd container ≠ `/tmp` on the minikube node
- Containers have isolated filesystems
- Cannot directly access container files from the node

**Why This Exists:**
- Container isolation is fundamental to Kubernetes
- Each container has its own filesystem namespace
- Security and resource isolation

**Solution:**
```bash
# ❌ This doesn't find the file
minikube ssh "ls /tmp/etcd-backup.db"
# File not found (it's inside the container, not on the node)

# ✅ Access via docker container
minikube ssh "sudo docker ps -f 'name=k8s_etcd'"  # Get container ID
minikube ssh "sudo docker cp CONTAINER_ID:/tmp/backup.db /home/docker/"
```

---

### Challenge 4: etcdctl vs etcdutl

**Problem:**
- `etcdctl` is for etcd server operations (requires certificates)
- `etcdutl` is for offline operations (snapshot verification)
- Different tools for different purposes

**Solution:**
```bash
# ✅ For creating backup (online operation)
etcdctl --endpoints=... --cacert=... snapshot save /backup.db

# ✅ For verifying backup (offline operation)  
etcdutl snapshot status /backup.db --write-out=table
```

---

### Working Solution (Lab Scripts)

Our lab scripts implement the complete workaround:

```bash
# 1. Create backup in pod
kubectl exec etcd-pod -- etcdctl snapshot save /tmp/backup.db ...

# 2. Copy from container to node using docker cp
minikube ssh "sudo docker cp \$(sudo docker ps -qf 'name=k8s_etcd' | head -n 1):/tmp/backup.db /home/docker/backup.db"

# 3. Copy from node to local machine
minikube ssh "sudo cat /home/docker/backup.db" > ./backups/backup.db

# 4. Verify by copying back
minikube ssh "sudo docker cp /home/docker/backup.db \$(sudo docker ps -qf 'name=k8s_etcd'):/tmp/verify.db"
kubectl exec etcd-pod -- etcdutl snapshot status /tmp/verify.db --write-out=table
```

---

### On Production Clusters (CKA Exam)

**Good news:** None of these challenges exist on kubeadm/production clusters!

```bash
# ✅ This works perfectly on kubeadm
kubectl exec etcd-pod -- etcdctl snapshot save /tmp/backup.db ...
kubectl cp etcd-pod:/tmp/backup.db ./backup.db
etcdctl snapshot status ./backup.db
```

**Why:**
- Production etcd containers include `tar`
- `kubectl cp` works out of the box
- No workarounds needed

---

### Key Takeaways

✅ **You learned MORE** by hitting these challenges:
- Container isolation concepts
- Docker CLI for container operations
- Distroless containers (security best practice)
- Difference between development and production setups

✅ **For the exam:**
- CKA uses kubeadm clusters
- All commands work as documented
- No minikube-specific workarounds needed

✅ **What you mastered:**
- etcd backup/restore process
- Certificate requirements
- Verification procedures
- Troubleshooting skills

---

## Tasks

### Task 1: Understanding etcd Location & Configuration (10 min)

**Objective:** Find where etcd runs and how to access it.

**etcd runs as a static pod on the control plane:**

```bash
# View etcd pod
kubectl get pods -n kube-system -l component=etcd

# Expected:
# NAME           READY   STATUS    RESTARTS   AGE
# etcd-opscart   1/1     Running   0          45h

# Get etcd pod details
kubectl describe pod -n kube-system etcd-opscart
```

**Important etcd information:**

```bash
# etcd listens on
# Client URL: https://127.0.0.1:2379
# Peer URL: https://127.0.0.1:2380

# Certificate locations (inside the pod):
# CA cert: /etc/kubernetes/pki/etcd/ca.crt
# Server cert: /etc/kubernetes/pki/etcd/server.crt
# Server key: /etc/kubernetes/pki/etcd/server.key

# Data directory:
# /var/lib/etcd
```

**View etcd configuration:**

```bash
# SSH into minikube
minikube ssh

# View etcd static pod manifest
sudo cat /etc/kubernetes/manifests/etcd.yaml

# Key lines to note:
# - --advertise-client-urls=https://192.168.58.2:2379
# - --data-dir=/var/lib/etcd
# - --cert-file=/etc/kubernetes/pki/etcd/server.crt
# - --key-file=/etc/kubernetes/pki/etcd/server.key

# Exit minikube
exit
```

---

### Task 2: Creating an etcd Backup (15 min)

**Objective:** Learn how to backup etcd using etcdctl.

**CRITICAL: You need etcdctl tool!**

On minikube, etcdctl is available inside the etcd pod:

```bash
# Method 1: Execute inside etcd pod
kubectl exec -it -n kube-system etcd-opscart -- sh

# Inside the pod:
ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /tmp/etcd-backup.db

# Verify snapshot
ETCDCTL_API=3 etcdctl snapshot status /tmp/etcd-backup.db

# Exit pod
exit
```

**Copy backup out of pod:**

```bash
# Copy backup to local machine
kubectl cp -n kube-system etcd-opscart:/tmp/etcd-backup.db ./etcd-backup.db

# Verify locally
ls -lh etcd-backup.db
```

**What gets backed up:**
- ALL Kubernetes objects (pods, services, deployments, etc.)
- ALL secrets and configmaps
- ALL RBAC policies
- ALL custom resources
- Entire cluster state at that moment

---

### Task 3: Creating Test Data (5 min)

**Objective:** Create resources to verify restore works.

```bash
# Create test namespace
kubectl create namespace backup-test

# Create deployment
kubectl create deployment nginx-test --image=nginx --replicas=3 -n backup-test

# Create configmap
kubectl create configmap test-config --from-literal=key1=value1 -n backup-test

# Create secret
kubectl create secret generic test-secret --from-literal=password=supersecret -n backup-test

# Create service
kubectl expose deployment nginx-test --port=80 -n backup-test

# Verify
kubectl get all,cm,secret -n backup-test
```

**Save state for verification:**

```bash
# Document what we created
kubectl get all -n backup-test > before-restore.txt
cat before-restore.txt
```

---

### Task 4: Simulating Disaster (5 min)

**Objective:** Delete resources to simulate data loss.

```bash
# Delete the entire namespace (disaster!)
kubectl delete namespace backup-test

# Verify it's gone
kubectl get namespace backup-test
# Error from server (NotFound): namespaces "backup-test" not found

# Try to get resources
kubectl get all -n backup-test
# No resources found (namespace deleted!)
```

**In a real disaster:**
- Accidental `kubectl delete` with wrong namespace
- Corrupted etcd data
- Hardware failure
- Ransomware attack
- Human error

---

### Task 5: Restoring from Backup (15 min)

**Objective:** Restore cluster state from etcd backup.

**⚠️ WARNING: Restore is DESTRUCTIVE - it replaces ALL cluster state!**

**On a real kubeadm cluster, you would:**

```bash
# 1. Stop API server and etcd
sudo systemctl stop kubelet

# 2. Move old etcd data
sudo mv /var/lib/etcd /var/lib/etcd.old

# 3. Restore from snapshot
ETCDCTL_API=3 etcdctl snapshot restore etcd-backup.db \
  --data-dir=/var/lib/etcd-restored \
  --name=master \
  --initial-cluster=master=https://192.168.1.10:2380 \
  --initial-advertise-peer-urls=https://192.168.1.10:2380

# 4. Update etcd manifest
sudo vim /etc/kubernetes/manifests/etcd.yaml
# Change --data-dir=/var/lib/etcd to --data-dir=/var/lib/etcd-restored

# 5. Start kubelet (etcd will restart automatically)
sudo systemctl start kubelet

# 6. Verify
kubectl get nodes
kubectl get all -n backup-test
```

**On minikube (simplified approach):**

Unfortunately, minikube's etcd restore is complex due to its architecture. Instead, we'll:
1. Understand the restore process conceptually
2. Verify backup contents
3. Practice the commands (dry-run)

**Verify backup contents:**

```bash
# Copy backup back to pod
kubectl cp ./etcd-backup.db -n kube-system etcd-opscart:/tmp/etcd-backup.db

# Exec into pod
kubectl exec -it -n kube-system etcd-opscart -- sh

# Verify backup integrity
ETCDCTL_API=3 etcdctl snapshot status /tmp/etcd-backup.db -w table

# Expected output:
# +----------+----------+------------+------------+
# |   HASH   | REVISION | TOTAL KEYS | TOTAL SIZE |
# +----------+----------+------------+------------+
# | 12345678 |    15432 |       1234 |     3.5 MB |
# +----------+----------+------------+------------+

# Exit
exit
```

---

### Task 6: Verification After Restore (5 min)

**Objective:** Verify restored data matches backup.

**After a real restore, you would verify:**

```bash
# Check all nodes are Ready
kubectl get nodes

# Check all namespaces exist
kubectl get namespaces

# Check specific resources
kubectl get all -n backup-test

# Compare with before-restore.txt
diff before-restore.txt <(kubectl get all -n backup-test)

# Verify secrets and configmaps
kubectl get secret,cm -n backup-test

# Test application functionality
kubectl run test --image=busybox --rm -it -n backup-test -- wget -O- nginx-test
```

---

## Validation Checklist

**After backup:**
- [ ] Backup file exists and has size > 0
- [ ] `etcdctl snapshot status` shows valid snapshot
- [ ] Backup is copied to safe location (off-cluster)
- [ ] Backup filename includes timestamp

**After restore:**
- [ ] All nodes Ready
- [ ] All namespaces exist
- [ ] All resources restored
- [ ] Applications functioning
- [ ] No data loss

---

## Production Backup Strategy

**At our pharmaceutical company:**

### 1. Automated Backups

```bash
#!/bin/bash
# /usr/local/bin/backup-etcd.sh

BACKUP_DIR="/backup/etcd"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="$BACKUP_DIR/etcd-backup-$TIMESTAMP.db"

# Create backup
ETCDCTL_API=3 etcdctl snapshot save $BACKUP_FILE \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Verify backup
ETCDCTL_API=3 etcdctl snapshot status $BACKUP_FILE

# Copy to Azure Blob Storage (off-site)
az storage blob upload \
  --account-name prodbackups \
  --container-name etcd-backups \
  --file $BACKUP_FILE \
  --name "$(basename $BACKUP_FILE)"

# Delete backups older than 30 days
find $BACKUP_DIR -name "etcd-backup-*.db" -mtime +30 -delete

# Log
echo "$(date): Backup completed: $BACKUP_FILE"
```

**Cron schedule:**
```bash
# /etc/cron.d/etcd-backup
0 */6 * * * root /usr/local/bin/backup-etcd.sh >> /var/log/etcd-backup.log 2>&1
```

**Backup every 6 hours!**

### 2. Retention Policy

- Hourly: Keep last 24 hours
- Daily: Keep last 7 days
- Weekly: Keep last 4 weeks
- Monthly: Keep last 12 months

### 3. Offsite Storage

- Azure Blob Storage (geo-redundant)
- AWS S3 (versioning enabled)
- Local NAS (encrypted)

### 4. Test Restores

- Monthly restore test in staging
- Document restore time (RTO)
- Verify data integrity

---

## Common Issues & Troubleshooting

### Issue 1: Permission Denied

**Error:**
```
Error: context deadline exceeded
```

**Cause:** Wrong certificates or permissions

**Solution:**
```bash
# Verify certificate paths
ls -la /etc/kubernetes/pki/etcd/

# Ensure ETCDCTL_API=3 is set
export ETCDCTL_API=3

# Use correct certificate paths
```

---

### Issue 2: Snapshot Fails

**Error:**
```
Error: etcdserver: mvcc: database space exceeded
```

**Cause:** etcd database full

**Solution:**
```bash
# Compact etcd
ETCDCTL_API=3 etcdctl compact <revision>

# Defragment
ETCDCTL_API=3 etcdctl defrag
```

---

### Issue 3: Restore Fails

**Error:**
```
Error: data-dir already exists
```

**Solution:**
```bash
# Move or delete old data-dir
sudo mv /var/lib/etcd /var/lib/etcd.old

# Or use different data-dir
etcdctl snapshot restore ... --data-dir=/var/lib/etcd-new
```

---

## Exam Tips

⏱️ **Time Management:**
- Backup: 3 minutes
- Restore: 5-7 minutes
- Verification: 2 minutes
- **Total: ~10 minutes**

🔑 **Quick Commands (Exam Speed):**

**Backup:**
```bash
ETCDCTL_API=3 etcdctl snapshot save /tmp/backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

**Restore:**
```bash
ETCDCTL_API=3 etcdctl snapshot restore /tmp/backup.db \
  --data-dir=/var/lib/etcd-restored
```

📖 **Documentation Reference (Allowed in Exam):**
- etcd backup: kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/#backing-up-an-etcd-cluster
- Search: "etcd backup restore"

🎯 **Exam Question Patterns:**

> *"Create an etcd backup and save it to /tmp/etcd-backup.db"*

> *"Restore the cluster from backup located at /data/etcd-backup.db"*

> *"Verify the etcd backup at /backup/snapshot.db is valid"*

---

## Exam Cheat Sheet

**Find etcd info:**
```bash
# Get etcd pod name
kubectl get pod -n kube-system | grep etcd

# Get certificate paths
kubectl describe pod -n kube-system etcd-* | grep -E 'cert|key|ca'
```

**Backup:**
```bash
ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /path/to/backup.db
```

**Verify:**
```bash
ETCDCTL_API=3 etcdctl snapshot status /path/to/backup.db
```

**Restore:**
```bash
# Stop kubelet
sudo systemctl stop kubelet

# Restore snapshot
ETCDCTL_API=3 etcdctl snapshot restore /path/to/backup.db \
  --data-dir=/var/lib/etcd-restored

# Update etcd manifest
sudo vim /etc/kubernetes/manifests/etcd.yaml
# Change: --data-dir=/var/lib/etcd-restored

# Start kubelet
sudo systemctl start kubelet
```

---

## Next Lab

Ready to continue? Move to **[Lab 06: Helm Basics](../06-helm-basics/README.md)**

In Lab 06, you'll learn:
- Install applications with Helm
- Manage Helm releases
- Create custom charts
- Helm in the CKA exam

---

**Author:** Shamsher Khan | **Blog:** opscart.com | **Course:** Production CKA 2026