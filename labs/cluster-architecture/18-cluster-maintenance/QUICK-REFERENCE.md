# Lab 18: Cluster Maintenance - Quick Reference

## Node Lifecycle Commands

```bash
# Mark unschedulable (keep existing pods)
kubectl cordon <node>

# Evict all pods + mark unschedulable
kubectl drain <node> \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --grace-period=60 \
  --timeout=300s

# Return node to service
kubectl uncordon <node>

# Check node status
kubectl get nodes
# SchedulingDisabled = cordoned
```

---

## Drain Options

```bash
--ignore-daemonsets      # skip DaemonSet pods (required!)
--delete-emptydir-data   # allow deleting emptyDir volumes
--grace-period=60        # time for pods to terminate
--timeout=300s           # total drain timeout
--force                  # delete pods without controllers
--dry-run                # preview what would be drained
```

---

## Certificate Management (kubeadm)

```bash
# Check expiry
kubeadm certs check-expiration

# Renew all
kubeadm certs renew all

# Renew specific cert
kubeadm certs renew apiserver
kubeadm certs renew etcd-server

# Manual check with openssl
openssl x509 -in /etc/kubernetes/pki/apiserver.crt \
  -noout -dates -subject
```

---

## Node Health Checks

```bash
# Node conditions
kubectl describe node <name> | grep -A 10 Conditions

# All nodes
kubectl get nodes -o wide

# Resource capacity vs allocatable
kubectl get nodes -o custom-columns=\
"NAME:.metadata.name,\
CPU:.status.allocatable.cpu,\
MEM:.status.allocatable.memory"

# Node pressure conditions
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{" "}{range .status.conditions[?(@.type=="Ready")]}{.status}{end}{"\n"}{end}'
```

---

## PodDisruptionBudget

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: my-pdb
spec:
  minAvailable: 2       # at least 2 must be running
  # OR
  maxUnavailable: 1     # at most 1 can be down
  selector:
    matchLabels:
      app: my-app
```

```bash
kubectl get pdb -A
kubectl describe pdb <name>
```

---

## Cluster Health Report

```bash
# Nodes
kubectl get nodes -o wide

# System pods
kubectl get pods -n kube-system

# Unhealthy pods
kubectl get pods -A | grep -v Running | grep -v Completed

# Resource quotas
kubectl get resourcequota -A

# PV status
kubectl get pv
```

---

## Image Cleanup on Node

```bash
# List images (via crictl)
crictl images

# Remove unused images
crictl rmi --prune

# Or via docker (minikube)
docker image prune -a
```

---

## Exam Scenarios

### Drain node for maintenance
```bash
kubectl drain worker1 \
  --ignore-daemonsets \
  --delete-emptydir-data
# Do maintenance...
kubectl uncordon worker1
```

### Just prevent new scheduling
```bash
kubectl cordon worker1
# Does NOT evict existing pods
```

### Check certificate expiry
```bash
kubeadm certs check-expiration
# or
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -dates
```

---

## Time Budget (Exam)

- Cordon node: **30 seconds**
- Drain node: **2-3 minutes** (pods evicting)
- Perform maintenance: varies
- Uncordon: **30 seconds**
- Verify: **1 minute**
- **Total: ~5 minutes**