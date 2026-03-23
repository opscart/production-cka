# Lab 04: Cluster Upgrade - Solution Guide

## Complete Upgrade: 1.33.0 → 1.34.0

This solution shows the complete upgrade process for a 3-node cluster.

---

## Pre-Upgrade: Backup etcd (CRITICAL!)

```bash
# On control plane node
ETCDCTL_API=3 etcdctl snapshot save /tmp/etcd-backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Verify backup
ETCDCTL_API=3 etcdctl snapshot status /tmp/etcd-backup.db
```

---

## Step 1: Upgrade Control Plane (5 minutes)

### 1.1: Upgrade kubeadm

```bash
# Unhold package
sudo apt-mark unhold kubeadm

# Update and install
sudo apt-get update
sudo apt-get install -y kubeadm=1.34.0-00

# Hold again
sudo apt-mark hold kubeadm

# Verify
kubeadm version
# Output: kubeadm version: &version.Info{Major:"1", Minor:"34", GitVersion:"v1.34.0"...}
```

### 1.2: Plan Upgrade

```bash
sudo kubeadm upgrade plan

# Review output:
# - Current versions
# - Target versions
# - Components to upgrade
# - Manual steps required
```

### 1.3: Apply Upgrade

```bash
sudo kubeadm upgrade apply v1.34.0 -y

# This will:
# [upgrade/config] Making sure the configuration is correct
# [upgrade/apply] Upgrading your Static Pod-hosted control plane
# [upgrade/staticpods] Writing new Static Pod manifests
# [upgrade/staticpods] Preparing for "kube-apiserver" upgrade
# [upgrade/staticpods] Renewing apiserver certificate
# [upgrade/staticpods] Moved new manifest and killed old pods
# [upgrade/staticpods] Waiting for the kubelet to restart component
# ... (repeats for controller-manager, scheduler)
# [upgrade/successful] SUCCESS! Your cluster was upgraded to "v1.34.0"
```

### 1.4: Upgrade kubelet and kubectl

```bash
# Unhold packages
sudo apt-mark unhold kubelet kubectl

# Install new versions
sudo apt-get update
sudo apt-get install -y kubelet=1.34.0-00 kubectl=1.34.0-00

# Hold packages
sudo apt-mark hold kubelet kubectl

# Restart kubelet
sudo systemctl daemon-reload
sudo systemctl restart kubelet

# Verify
kubectl version --short
kubelet --version
```

### 1.5: Verify Control Plane

```bash
# Check node version
kubectl get nodes
# NAME      STATUS   VERSION
# master    Ready    v1.34.0   ← Control plane upgraded!
# worker1   Ready    v1.33.0   ← Still old
# worker2   Ready    v1.33.0   ← Still old

# Check control plane pods
kubectl get pods -n kube-system -l tier=control-plane
# All should be Running with new images
```

---

## Step 2: Upgrade Worker Node 1 (3 minutes)

### 2.1: Drain Node (from control plane)

```bash
# Mark node unschedulable and evict pods
kubectl drain worker1 --ignore-daemonsets --delete-emptydir-data

# Output:
# node/worker1 cordoned
# evicting pod default/nginx-xxx
# evicting pod default/app-yyy
# pod/nginx-xxx evicted
# pod/app-yyy evicted
# node/worker1 drained

# Verify pods moved
kubectl get pods -o wide
# Pods should now be on worker2
```

### 2.2: Upgrade Node (on worker1)

```bash
# SSH to worker node
ssh worker1

# Upgrade kubeadm
sudo apt-mark unhold kubeadm
sudo apt-get update
sudo apt-get install -y kubeadm=1.34.0-00
sudo apt-mark hold kubeadm

# Upgrade node configuration
sudo kubeadm upgrade node

# Output:
# [upgrade] Reading configuration from the cluster...
# [upgrade] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
# [upgrade] Upgrading your Static Pod-hosted control plane instance on this node
# [upgrade] Upgrading the kubelet configuration for this node
# [upgrade] Successfully upgraded the kubelet configuration for this node!

# Upgrade kubelet and kubectl
sudo apt-mark unhold kubelet kubectl
sudo apt-get install -y kubelet=1.34.0-00 kubectl=1.34.0-00
sudo apt-mark hold kubelet kubectl

# Restart kubelet
sudo systemctl daemon-reload
sudo systemctl restart kubelet

# Exit worker node
exit
```

### 2.3: Uncordon Node (from control plane)

```bash
# Make node schedulable again
kubectl uncordon worker1

# Output:
# node/worker1 uncordoned

# Verify
kubectl get nodes
# NAME      STATUS   VERSION
# master    Ready    v1.34.0
# worker1   Ready    v1.34.0   ← Upgraded!
# worker2   Ready    v1.33.0   ← Still old
```

---

## Step 3: Upgrade Worker Node 2 (3 minutes)

**Repeat the same process:**

```bash
# Drain
kubectl drain worker2 --ignore-daemonsets --delete-emptydir-data

# SSH and upgrade
ssh worker2
sudo apt-mark unhold kubeadm && sudo apt-get install -y kubeadm=1.34.0-00 && sudo apt-mark hold kubeadm
sudo kubeadm upgrade node
sudo apt-mark unhold kubelet kubectl && sudo apt-get install -y kubelet=1.34.0-00 kubectl=1.34.0-00 && sudo apt-mark hold kubelet kubectl
sudo systemctl daemon-reload && sudo systemctl restart kubelet
exit

# Uncordon
kubectl uncordon worker2

# Verify
kubectl get nodes
# NAME      STATUS   VERSION
# master    Ready    v1.34.0
# worker1   Ready    v1.34.0
# worker2   Ready    v1.34.0   ← All upgraded!
```

---

## Step 4: Post-Upgrade Verification (2 minutes)

### 4.1: Verify All Nodes

```bash
kubectl get nodes -o wide
# All nodes should show v1.34.0
```

### 4.2: Verify All Pods

```bash
kubectl get pods -A
# All pods should be Running
```

### 4.3: Verify Control Plane Components

```bash
kubectl get pods -n kube-system -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}' | grep -E 'apiserver|scheduler|controller'

# Should show v1.34.0 images
```

### 4.4: Test Functionality

```bash
# Create test deployment
kubectl create deployment test --image=nginx

# Wait for pod
kubectl wait --for=condition=ready pod -l app=test --timeout=60s

# Expose service
kubectl expose deployment test --port=80

# Test DNS
kubectl run dns-test --image=busybox --rm -it --restart=Never -- nslookup kubernetes

# Cleanup
kubectl delete deployment test
kubectl delete service test
```

---

## Exam Simulation (12 minutes total)

**Scenario:** Upgrade cluster from 1.33.0 to 1.34.0

```bash
# === Control Plane (5 min) ===
sudo apt-mark unhold kubeadm && sudo apt-get install -y kubeadm=1.34.0-*
sudo kubeadm upgrade plan
sudo kubeadm upgrade apply v1.34.0 -y
sudo apt-mark unhold kubelet kubectl && sudo apt-get install -y kubelet=1.34.0-* kubectl=1.34.0-*
sudo systemctl daemon-reload && sudo systemctl restart kubelet

# === Worker 1 (3 min) ===
kubectl drain worker1 --ignore-daemonsets
ssh worker1 "sudo apt-get install -y kubeadm=1.34.0-* && sudo kubeadm upgrade node && sudo apt-get install -y kubelet=1.34.0-* && sudo systemctl restart kubelet"
kubectl uncordon worker1

# === Worker 2 (3 min) ===
kubectl drain worker2 --ignore-daemonsets
ssh worker2 "sudo apt-get install -y kubeadm=1.34.0-* && sudo kubeadm upgrade node && sudo apt-get install -y kubelet=1.34.0-* && sudo systemctl restart kubelet"
kubectl uncordon worker2

# === Verify (1 min) ===
kubectl get nodes
kubectl get pods -A
```

---

## Common Issues & Solutions

### Issue: Drain Fails Due to PDB

**Error:**
```
error when evicting pod: Cannot evict pod as it would violate the pod's disruption budget
```

**Solution:**
```bash
# Check PDBs
kubectl get pdb -A

# Either wait for PDB to allow, or force drain
kubectl drain worker1 --ignore-daemonsets --delete-emptydir-data --force
```

### Issue: kubelet Won't Start

**Error:**
```
kubelet.service: Failed with result 'exit-code'
```

**Solution:**
```bash
# Check logs
sudo journalctl -u kubelet -n 100

# Common fixes:
# 1. Reinstall correct version
sudo apt-get install --reinstall kubelet=1.34.0-*

# 2. Check configuration
cat /var/lib/kubelet/config.yaml

# 3. Restart
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

### Issue: Static Pods Not Starting

**Solution:**
```bash
# Check manifests
sudo ls -la /etc/kubernetes/manifests/

# Check kubelet
sudo systemctl status kubelet

# Restart kubelet (recreates static pods)
sudo systemctl restart kubelet

# Check pod logs
kubectl logs -n kube-system <pod-name>
```

---

## Key Takeaways

✅ **Always backup etcd first**
✅ **Upgrade control plane before workers**
✅ **One worker at a time** (drain → upgrade → uncordon)
✅ **Cannot skip versions** (1.32 → 1.33 → 1.34, not 1.32 → 1.34)
✅ **kubeadm upgrade does NOT upgrade kubelet** (manual step)
✅ **No automatic rollback** (fix issues and retry)

---

**Completed Lab 04?** ✅

Move to **[Lab 05: etcd Backup & Restore](../05-etcd-backup-restore/)**