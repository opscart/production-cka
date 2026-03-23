# Lab 04: Cluster Upgrade Quick Reference

## Complete Upgrade Flow (1.33.0 → 1.34.0)

### Prerequisites

```bash
# Backup etcd BEFORE upgrade!
ETCDCTL_API=3 etcdctl snapshot save /backup/etcd-snapshot.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Verify backup
ETCDCTL_API=3 etcdctl snapshot status /backup/etcd-snapshot.db
```

---

## Part 1: Control Plane Upgrade (5 min)

Run on **control plane node**:

```bash
# Step 1: Upgrade kubeadm
sudo apt-mark unhold kubeadm
sudo apt-get update
sudo apt-get install -y kubeadm=1.34.0-*
sudo apt-mark hold kubeadm

# Verify
kubeadm version

# Step 2: Check upgrade plan
sudo kubeadm upgrade plan

# Step 3: Apply upgrade
sudo kubeadm upgrade apply v1.34.0 -y

# Step 4: Upgrade kubelet & kubectl
sudo apt-mark unhold kubelet kubectl
sudo apt-get install -y kubelet=1.34.0-* kubectl=1.34.0-*
sudo apt-mark hold kubelet kubectl

# Step 5: Restart kubelet
sudo systemctl daemon-reload
sudo systemctl restart kubelet

# Verify
kubectl get nodes
```

---

## Part 2: Worker Node Upgrade (3 min per node)

**Upgrade ONE worker at a time!**

### From Control Plane:

```bash
# Drain node
kubectl drain worker-1 --ignore-daemonsets --delete-emptydir-data

# Wait for pods to evict
kubectl get pods -o wide
```

### On Worker Node:

```bash
# SSH to worker
ssh worker-1

# Upgrade kubeadm
sudo apt-mark unhold kubeadm
sudo apt-get update
sudo apt-get install -y kubeadm=1.34.0-*
sudo apt-mark hold kubeadm

# Upgrade node config
sudo kubeadm upgrade node

# Upgrade kubelet & kubectl
sudo apt-mark unhold kubelet kubectl
sudo apt-get install -y kubelet=1.34.0-* kubectl=1.34.0-*
sudo apt-mark hold kubelet kubectl

# Restart kubelet
sudo systemctl daemon-reload
sudo systemctl restart kubelet

# Exit
exit
```

### Back on Control Plane:

```bash
# Uncordon node
kubectl uncordon worker-1

# Verify
kubectl get nodes

# Repeat for worker-2, worker-3, etc.
```

---

## Quick Commands Summary

### Control Plane (Master)

```bash
# Upgrade kubeadm
apt-mark unhold kubeadm && apt-get install -y kubeadm=1.34.0-* && apt-mark hold kubeadm

# Plan
kubeadm upgrade plan

# Apply
kubeadm upgrade apply v1.34.0 -y

# Upgrade kubelet/kubectl
apt-mark unhold kubelet kubectl && apt-get install -y kubelet=1.34.0-* kubectl=1.34.0-* && apt-mark hold kubelet kubectl

# Restart
systemctl daemon-reload && systemctl restart kubelet
```

### Worker Node (Each)

```bash
# From control plane: drain
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data

# On worker: upgrade
apt-mark unhold kubeadm && apt-get install -y kubeadm=1.34.0-* && apt-mark hold kubeadm
kubeadm upgrade node
apt-mark unhold kubelet kubectl && apt-get install -y kubelet=1.34.0-* kubectl=1.34.0-* && apt-mark hold kubelet kubectl
systemctl daemon-reload && systemctl restart kubelet

# From control plane: uncordon
kubectl uncordon <node>
```

---

## Version Compatibility

```
Kubernetes Version Support (N-2):
- Current: 1.34.0
- Supported: 1.33.x, 1.32.x
- Deprecated: 1.31.x and older

Upgrade Path (One Minor Version at a Time):
✓ 1.32.0 → 1.33.0 → 1.34.0
✗ 1.32.0 → 1.34.0 (NOT ALLOWED - skip version)

Component Version Skew:
- kube-apiserver: N
- kube-controller-manager: N-1
- kube-scheduler: N-1
- kubelet: N-2
- kubectl: N±1
```

---

## Verification Commands

```bash
# Check all node versions
kubectl get nodes

# Check control plane pods
kubectl get pods -n kube-system

# Check all pods
kubectl get pods -A

# Check component versions
kubectl get pods -n kube-system -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}'

# Test cluster
kubectl run test --image=nginx --rm -it -- nginx -v
```

---

## Troubleshooting

### Issue: kubeadm upgrade plan Fails

```bash
# Check kubeadm version
kubeadm version

# Check API server connectivity
kubectl cluster-info

# Check certificates
kubeadm certs check-expiration

# View logs
journalctl -u kubelet -n 50
```

### Issue: Node Won't Drain

```bash
# Check PodDisruptionBudgets
kubectl get pdb -A

# Force drain (careful!)
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data --force

# Delete stuck pods
kubectl delete pod <pod> --force --grace-period=0
```

### Issue: kubelet Won't Start

```bash
# Check status
systemctl status kubelet

# View logs
journalctl -u kubelet -f

# Check config
cat /var/lib/kubelet/config.yaml

# Restart
systemctl daemon-reload
systemctl restart kubelet
```

### Issue: Control Plane Pods Stuck

```bash
# Check static pod manifests
ls -la /etc/kubernetes/manifests/

# Check pod status
kubectl get pods -n kube-system

# View pod logs
kubectl logs -n kube-system <pod-name>

# Restart kubelet (recreates static pods)
systemctl restart kubelet
```

---

## Rollback (If Upgrade Fails)

### kubeadm Does NOT Support Rollback!

If upgrade fails:

1. **Fix the issue** and retry upgrade
2. **Restore from etcd backup** (last resort)

```bash
# Stop API server
systemctl stop kubelet

# Restore etcd
ETCDCTL_API=3 etcdctl snapshot restore /backup/etcd-snapshot.db \
  --data-dir=/var/lib/etcd-backup

# Update etcd manifest to point to new data-dir
vim /etc/kubernetes/manifests/etcd.yaml
# Change: --data-dir=/var/lib/etcd-backup

# Start kubelet
systemctl start kubelet
```

---

## Pre-Upgrade Checklist

- [ ] Backup etcd
- [ ] Document current versions
- [ ] Test in staging environment
- [ ] Review release notes
- [ ] Check deprecated APIs
- [ ] Notify stakeholders
- [ ] Schedule maintenance window
- [ ] Have rollback plan

---

## During Upgrade Checklist

- [ ] Upgrade kubeadm first
- [ ] Run upgrade plan
- [ ] Apply control plane upgrade
- [ ] Verify control plane health
- [ ] Upgrade control plane kubelet
- [ ] Drain each worker one at a time
- [ ] Upgrade worker components
- [ ] Uncordon worker
- [ ] Verify before next worker

---

## Post-Upgrade Checklist

- [ ] All nodes show correct version
- [ ] All pods running
- [ ] No failed components
- [ ] Test application functionality
- [ ] Check logs for errors
- [ ] Update documentation
- [ ] Notify stakeholders
- [ ] Monitor for 24 hours

---

## Exam Scenarios

### Scenario 1: Full Cluster Upgrade

**Question:** Upgrade cluster from 1.33.0 to 1.34.0

```bash
# Control plane
apt-mark unhold kubeadm && apt-get install -y kubeadm=1.34.0-*
kubeadm upgrade apply v1.34.0 -y
apt-mark unhold kubelet kubectl && apt-get install -y kubelet=1.34.0-* kubectl=1.34.0-*
systemctl restart kubelet

# Each worker
kubectl drain worker-1 --ignore-daemonsets
ssh worker-1
apt-get install -y kubeadm=1.34.0-*
kubeadm upgrade node
apt-get install -y kubelet=1.34.0-*
systemctl restart kubelet
exit
kubectl uncordon worker-1
```

### Scenario 2: Drain Node for Maintenance

**Question:** Drain node 'worker-1' for maintenance

```bash
kubectl drain worker-1 --ignore-daemonsets --delete-emptydir-data
# Do maintenance
kubectl uncordon worker-1
```

### Scenario 3: Upgrade Failed - Fix It

**Question:** Control plane upgrade failed, investigate and fix

```bash
# Check kubelet
systemctl status kubelet
journalctl -u kubelet -n 100

# Check pods
kubectl get pods -n kube-system

# Common fixes:
# - Restart kubelet
# - Fix certificates
# - Check disk space
# - Review manifests
```

---

## Time Budget (Exam)

- Control plane upgrade: **5 minutes**
- Worker node 1: **3 minutes**
- Worker node 2: **3 minutes**
- Verification: **2 minutes**
- **Total: 13 minutes for 3-node cluster**

---

## Critical Rules

1. ⚠️ **Always backup etcd first**
2. ⚠️ **One minor version at a time** (no skip versions)
3. ⚠️ **Control plane before workers**
4. ⚠️ **One worker at a time** (drain → upgrade → uncordon)
5. ⚠️ **Verify after each step**
6. ⚠️ **No rollback - fix and retry**

---

## Documentation Links

- Upgrade guide: kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/
- Version skew: kubernetes.io/releases/version-skew-policy/
- Release notes: github.com/kubernetes/kubernetes/releases