# Lab 04: Cluster Upgrade with kubeadm

## Objective
Master Kubernetes cluster upgrades using kubeadm, understand the upgrade process for control plane and worker nodes, handle upgrade failures, and implement zero-downtime upgrades in production environments.

## CKA Exam Relevance
- **Domain:** Cluster Architecture, Installation & Configuration (25%)
- **Topic:** Manage the lifecycle of Kubernetes clusters
- **Exam Weight:** Very High (appears in 85%+ of exams)
- **Typical Exam Time:** 12-15 minutes

## Time to Complete
50 minutes

## Scenario
Your pharmaceutical company is running Kubernetes 1.33.0 in production. A critical security patch requires upgrading to 1.34.0. You need to:
- Upgrade the control plane without downtime
- Upgrade worker nodes with rolling updates
- Ensure zero application downtime
- Handle any upgrade failures gracefully

## Prerequisites
- Completed Lab 03 (kubeadm Installation)
- Understanding of cluster components
- Existing minikube cluster running

## Important Note: Lab Environment

**Current minikube version:** v1.35.1 (already latest)

Since your minikube is already on the latest version, we'll:
1. **Understand** the upgrade process conceptually
2. **Practice** upgrade commands in dry-run mode
3. **Simulate** upgrade scenarios
4. **Learn** rollback procedures

**For real practice**, you'd need a cluster on an older version (e.g., 1.33.0 → 1.34.0).

## Kubernetes Version Support Policy

```
┌─────────────────────────────────────────────────────────┐
│  Kubernetes Version Support (N-2 Policy)                │
│                                                          │
│  Current: 1.34.0 (latest)                               │
│  Supported: 1.33.x, 1.32.x (N-1, N-2)                   │
│  Deprecated: 1.31.x and older                           │
│                                                          │
│  You can ONLY upgrade one minor version at a time:      │
│  1.32.0 → 1.33.0 → 1.34.0 ✓                            │
│  1.32.0 → 1.34.0 ✗ (NOT ALLOWED)                       │
└─────────────────────────────────────────────────────────┘
```

## Upgrade Workflow

```
┌──────────────────────────────────────────────────────────┐
│ Step 1: Upgrade kubeadm on Control Plane                 │
│ - apt-get update                                         │
│ - apt-get install kubeadm=1.34.0-*                      │
└──────────────────────────────────────────────────────────┘
                         ▼
┌──────────────────────────────────────────────────────────┐
│ Step 2: Plan Upgrade                                     │
│ - kubeadm upgrade plan                                   │
│ - Review what will be upgraded                           │
└──────────────────────────────────────────────────────────┘
                         ▼
┌──────────────────────────────────────────────────────────┐
│ Step 3: Apply Control Plane Upgrade                      │
│ - kubeadm upgrade apply v1.34.0                         │
│ - Upgrades: API server, scheduler, controller-manager   │
└──────────────────────────────────────────────────────────┘
                         ▼
┌──────────────────────────────────────────────────────────┐
│ Step 4: Upgrade kubelet & kubectl (Control Plane)        │
│ - apt-get install kubelet=1.34.0-* kubectl=1.34.0-*    │
│ - systemctl daemon-reload                                │
│ - systemctl restart kubelet                              │
└──────────────────────────────────────────────────────────┘
                         ▼
┌──────────────────────────────────────────────────────────┐
│ Step 5: Upgrade Each Worker Node (One at a Time)         │
│ - Drain node                                             │
│ - Upgrade kubeadm                                        │
│ - kubeadm upgrade node                                   │
│ - Upgrade kubelet & kubectl                              │
│ - Restart kubelet                                        │
│ - Uncordon node                                          │
└──────────────────────────────────────────────────────────┘
                         ▼
┌──────────────────────────────────────────────────────────┐
│ Step 6: Verify Upgrade                                   │
│ - kubectl get nodes (check versions)                     │
│ - kubectl get pods -A (check all running)                │
└──────────────────────────────────────────────────────────┘
```

---

## Tasks

### Task 1: Understanding Upgrade Process (10 min)

**Objective:** Learn what gets upgraded and in what order.

**Components That Get Upgraded:**

1. **kubeadm** (tool itself)
2. **Control plane components:**
   - kube-apiserver
   - kube-controller-manager
   - kube-scheduler
   - etcd (if managed by kubeadm)
3. **kubelet** (on each node)
4. **kubectl** (CLI tool)
5. **kube-proxy** (via DaemonSet)
6. **CoreDNS** (via Deployment)

**What Does NOT Get Upgraded:**
- Container runtime (containerd/docker)
- CNI plugin (manual upgrade if needed)
- Operating system
- Applications running in pods

**Check your current versions:**

```bash
# kubectl version
kubectl version --short

# Node versions
kubectl get nodes -o wide

# Component versions
kubectl get pods -n kube-system -o wide

# kubeadm version
minikube ssh "kubeadm version"
```

**Expected output:**
```
Client Version: v1.35.1
Server Version: v1.35.1

NAME          STATUS   VERSION
opscart       Ready    v1.35.1
opscart-m02   Ready    v1.35.1
opscart-m03   Ready    v1.35.1
```

---

### Task 2: Planning an Upgrade (10 min)

**Objective:** Understand what `kubeadm upgrade plan` shows.

**On a real cluster, you would run:**

```bash
# View available versions
sudo kubeadm upgrade plan

# Example output:
# Components that must be upgraded manually after you have upgraded the control plane:
# COMPONENT   CURRENT       TARGET
# kubelet     3 x v1.33.0   v1.34.0
#
# Upgrade to the latest stable version:
# COMPONENT                 CURRENT    TARGET
# kube-apiserver            v1.33.0    v1.34.0
# kube-controller-manager   v1.33.0    v1.34.0
# kube-scheduler            v1.33.0    v1.34.0
# kube-proxy                v1.33.0    v1.34.0
# CoreDNS                   v1.10.1    v1.11.1
# etcd                      3.5.9      3.5.12
```

**What the plan shows:**
- ✅ Current versions
- ✅ Target versions
- ✅ What will be upgraded
- ✅ What needs manual upgrade (kubelet)
- ⚠️ Any warnings or incompatibilities

**Simulate on minikube:**

```bash
# Check what version minikube is running
kubectl version --short

# View upgrade plan (may not work on minikube but shows the concept)
minikube ssh "sudo kubeadm upgrade plan" 2>/dev/null || echo "Already on latest version"
```

---

### Task 3: Control Plane Upgrade Process (15 min)

**Objective:** Understand the control plane upgrade steps.

**On a fresh cluster (1.33.0 → 1.34.0), you would run:**

```bash
# === Step 1: Upgrade kubeadm ===
sudo apt-mark unhold kubeadm
sudo apt-get update
sudo apt-get install -y kubeadm=1.34.0-*
sudo apt-mark hold kubeadm

# Verify
kubeadm version

# === Step 2: Plan upgrade ===
sudo kubeadm upgrade plan

# === Step 3: Apply upgrade ===
sudo kubeadm upgrade apply v1.34.0 -y

# This will:
# - Pull new images
# - Upgrade static pod manifests
# - Restart control plane components
# - Upgrade cluster configuration

# === Step 4: Upgrade kubelet & kubectl ===
sudo apt-mark unhold kubelet kubectl
sudo apt-get install -y kubelet=1.34.0-* kubectl=1.34.0-*
sudo apt-mark hold kubelet kubectl

# === Step 5: Restart kubelet ===
sudo systemctl daemon-reload
sudo systemctl restart kubelet

# === Step 6: Verify control plane ===
kubectl get nodes
kubectl get pods -n kube-system
```

**What happens during upgrade:**

```
Before:
etcd-master            v1.33.0
kube-apiserver-master  v1.33.0
kube-scheduler-master  v1.33.0
controller-manager     v1.33.0

During (rolling restart):
Old pod terminates → New pod starts
Each component upgraded one at a time
API remains available (brief connection drops possible)

After:
etcd-master            v1.34.0
kube-apiserver-master  v1.34.0
kube-scheduler-master  v1.34.0
controller-manager     v1.34.0
```

**Inspect control plane on your minikube:**

```bash
# View control plane pod images
kubectl get pods -n kube-system -l tier=control-plane -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].image}{"\n"}{end}'

# View static pod manifests
minikube ssh "ls -la /etc/kubernetes/manifests/"
```

---

### Task 4: Worker Node Upgrade Process (15 min)

**Objective:** Learn the safe way to upgrade worker nodes.

**Critical: Upgrade ONE worker node at a time!**

**For each worker node, you would run:**

```bash
# === Step 1: Drain node (from control plane) ===
kubectl drain worker-1 --ignore-daemonsets --delete-emptydir-data

# This will:
# - Cordon node (mark unschedulable)
# - Evict all pods gracefully
# - Pods reschedule on other nodes (zero downtime)

# === Step 2: SSH to worker node ===
ssh worker-1

# === Step 3: Upgrade kubeadm ===
sudo apt-mark unhold kubeadm
sudo apt-get update
sudo apt-get install -y kubeadm=1.34.0-*
sudo apt-mark hold kubeadm

# === Step 4: Upgrade node ===
sudo kubeadm upgrade node

# This will:
# - Update kubelet configuration
# - Update kube-proxy on this node

# === Step 5: Upgrade kubelet & kubectl ===
sudo apt-mark unhold kubelet kubectl
sudo apt-get install -y kubelet=1.34.0-* kubectl=1.34.0-*
sudo apt-mark hold kubelet kubectl

# === Step 6: Restart kubelet ===
sudo systemctl daemon-reload
sudo systemctl restart kubelet

# === Step 7: Exit back to control plane ===
exit

# === Step 8: Uncordon node ===
kubectl uncordon worker-1

# === Step 9: Verify ===
kubectl get nodes
```

**Simulate drain/uncordon on minikube:**

```bash
# List nodes
kubectl get nodes

# Drain a worker node (pods will move to other nodes)
kubectl drain opscart-m02 --ignore-daemonsets --delete-emptydir-data

# Check pods moved
kubectl get pods -o wide

# Uncordon to make it schedulable again
kubectl uncordon opscart-m02

# Verify
kubectl get nodes
```

---

### Task 5: Handling Upgrade Failures (10 min)

**Objective:** Learn how to recover from failed upgrades.

**Common Failure Scenarios:**

### Scenario 1: kubeadm upgrade apply Fails

**Error:**
```
[upgrade/apply] FATAL: failed to upgrade the control plane
```

**Troubleshoot:**
```bash
# Check logs
sudo journalctl -u kubelet -n 50

# Check pod status
kubectl get pods -n kube-system

# Check disk space
df -h

# Check API server
kubectl get --raw='/healthz?verbose'
```

**Rollback:**
```bash
# kubeadm doesn't support rollback
# You must fix the issue and retry

# Common fixes:
# 1. Free up disk space
# 2. Fix network issues
# 3. Resolve certificate problems
```

---

### Scenario 2: Node Won't Drain

**Error:**
```
error when evicting pod: Cannot evict pod as it would violate the pod's disruption budget
```

**Solution:**
```bash
# Option 1: Wait for PDB to allow eviction
kubectl get pdb -A

# Option 2: Force drain (use carefully!)
kubectl drain node --ignore-daemonsets --delete-emptydir-data --force

# Option 3: Delete problematic pods manually
kubectl delete pod <pod-name> --force --grace-period=0
```

---

### Scenario 3: kubelet Won't Start After Upgrade

**Error:**
```
kubelet.service: Failed with result 'exit-code'
```

**Debug:**
```bash
# Check kubelet status
sudo systemctl status kubelet

# View logs
sudo journalctl -u kubelet -n 100

# Common causes:
# - Wrong kubelet version
# - Certificate issues
# - Configuration mismatch
```

**Fix:**
```bash
# Reinstall correct version
sudo apt-get install --reinstall kubelet=1.34.0-*

# Restart
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

---

## Validation Checklist

**After upgrade, verify:**

- [ ] All nodes show correct version (`kubectl get nodes`)
- [ ] All control plane pods running (`kubectl get pods -n kube-system`)
- [ ] All application pods running (`kubectl get pods -A`)
- [ ] API server responsive (`kubectl cluster-info`)
- [ ] DNS working (`kubectl run test --image=busybox --rm -it -- nslookup kubernetes`)
- [ ] New pods can be created
- [ ] Services working
- [ ] No failed upgrades in history (`kubectl get events -n kube-system`)

---

## Zero-Downtime Upgrade Checklist

**For production environments:**

✅ **Before Upgrade:**
- [ ] Backup etcd
- [ ] Document current versions
- [ ] Test upgrade in staging
- [ ] Schedule maintenance window
- [ ] Notify stakeholders
- [ ] Have rollback plan ready

✅ **During Upgrade:**
- [ ] Upgrade control plane first
- [ ] Upgrade one worker at a time
- [ ] Verify each node before next
- [ ] Monitor application health
- [ ] Watch for errors

✅ **After Upgrade:**
- [ ] Verify all nodes upgraded
- [ ] Test critical applications
- [ ] Check logs for errors
- [ ] Update documentation
- [ ] Notify stakeholders

---

## Common Issues & Troubleshooting

### Issue 1: Version Skew

**Problem:** kubelet is 2+ versions behind API server

**Error:**
```
kubelet v1.32.0 is too old (apiserver is v1.34.0)
```

**Solution:**
- Upgrade kubelet to within 1 minor version of API server
- Can't skip versions: 1.32 → 1.33 → 1.34

---

### Issue 2: Image Pull Failures

**Problem:** Can't pull new control plane images

**Solution:**
```bash
# Pre-pull images
sudo kubeadm config images pull --kubernetes-version v1.34.0

# Check image availability
sudo kubeadm config images list
```

---

### Issue 3: etcd Backup Failed

**Problem:** Upgrade fails due to etcd issues

**Solution:**
```bash
# Always backup etcd before upgrade!
ETCDCTL_API=3 etcdctl snapshot save /backup/etcd-backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

---

## Exam Tips

⏱️ **Time Management:**
- Control plane upgrade: 5 minutes
- Each worker node: 3 minutes
- Verification: 2 minutes
- **Total for 3-node cluster: ~12 minutes**

🔑 **Quick Commands (Exam Speed):**

```bash
# Control plane
sudo apt-mark unhold kubeadm
sudo apt-get install -y kubeadm=1.34.0-*
sudo kubeadm upgrade plan
sudo kubeadm upgrade apply v1.34.0 -y
sudo apt-get install -y kubelet=1.34.0-* kubectl=1.34.0-*
sudo systemctl daemon-reload && sudo systemctl restart kubelet

# Each worker
kubectl drain worker-1 --ignore-daemonsets
ssh worker-1
sudo apt-get install -y kubeadm=1.34.0-*
sudo kubeadm upgrade node
sudo apt-get install -y kubelet=1.34.0-*
sudo systemctl restart kubelet
exit
kubectl uncordon worker-1
```

📖 **Documentation Reference (Allowed in Exam):**
- Upgrade: kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/
- Search: "kubeadm upgrade"

🎯 **Exam Question Patterns:**

> *"Upgrade the cluster from v1.33.0 to v1.34.0. Control plane is on 'master1', workers are 'worker1' and 'worker2'."*

> *"Drain node 'worker1', upgrade it to v1.34.0, and uncordon it."*

> *"The upgrade failed on the control plane. Investigate and fix the issue."*

---

## Production Notes from Real Enterprise

**At our pharmaceutical company:**

1. **Upgrade Schedule:**
   - Staging: Friday afternoon
   - Production: Sunday 2 AM (lowest traffic)
   - One cluster per weekend

2. **Preparation:**
   - etcd backup automated
   - Staging cluster upgraded first
   - Application team notified 1 week ahead
   - Rollback plan documented

3. **Execution:**
   - Control plane: 5 minutes
   - 8 worker nodes: 30 minutes (one at a time)
   - Validation: 15 minutes
   - **Total: ~50 minutes downtime risk minimized**

4. **Monitoring:**
   - Prometheus alerts during upgrade
   - Application health checks
   - Database connection monitoring
   - Error rate tracking

5. **Post-Upgrade:**
   - 24-hour observation period
   - Detailed report to management
   - Documentation updated
   - Lessons learned documented

---

### Hands-On Practice: Drain/Uncordon Simulation

**This works on your existing minikube cluster!**

Even though you can't perform a real version upgrade, you can practice the critical drain/uncordon workflow:
```bash
# Create test deployment
kubectl create deployment test-app --image=nginx --replicas=6

# Wait for pods to spread
kubectl get pods -o wide

# Drain a worker node (this is what you do during upgrades)
kubectl drain opscart-m02 --ignore-daemonsets --delete-emptydir-data

# Watch pods reschedule to other nodes (zero downtime!)
kubectl get pods -o wide

# Check node status
kubectl get nodes
# opscart-m02 should show: Ready,SchedulingDisabled

# Uncordon to make schedulable again
kubectl uncordon opscart-m02

# Verify
kubectl get nodes
# opscart-m02 should show: Ready

# Cleanup
kubectl delete deployment test-app
```

**What you learned:**
- Pods are evicted gracefully (no interruption)
- DaemonSet pods stay (kube-proxy, CNI)
- New pods can't schedule on drained node
- Zero application downtime during node maintenance

**This is exactly what happens during worker node upgrades!**

---

## Next Lab

Ready for more? Move to **[Lab 05: etcd Backup & Restore](../05-etcd-backup-restore/README.md)**

In Lab 05, you'll learn:
- Backup etcd database
- Restore from backup
- Verify data integrity
- Disaster recovery procedures

---

**Author:** Shamsher Khan | **Blog:** opscart.com | **Course:** Production CKA 2026