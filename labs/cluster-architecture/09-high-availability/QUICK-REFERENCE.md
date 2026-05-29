# Lab 09: High Availability - Quick Reference

## HA Cluster Requirements

```
Minimum HA:  3 control plane nodes + Load Balancer
etcd quorum: (n/2)+1 nodes needed
Worker nodes: Not counted for HA
```

## etcd Quorum Table

```
Nodes  │  Quorum  │  Failure tolerance
───────┼──────────┼────────────────────
  1    │    1     │  0
  3    │    2     │  1  ← Minimum HA
  5    │    3     │  2  ← Recommended
  7    │    4     │  3  ← Enterprise
```

---

## Component Health Commands

```bash
# Check all control plane pods
kubectl get pods -n kube-system | grep -E "etcd|apiserver|scheduler|controller"

# API server health endpoints
kubectl get --raw='/healthz'
kubectl get --raw='/livez'
kubectl get --raw='/readyz'

# etcd health
kubectl exec -n kube-system etcd-<node> -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/var/lib/minikube/certs/etcd/ca.crt \
  --cert=/var/lib/minikube/certs/etcd/server.crt \
  --key=/var/lib/minikube/certs/etcd/server.key \
  endpoint health

# etcd members (HA clusters show multiple)
kubectl exec -n kube-system etcd-<node> -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=... member list

# Check leader election leases
kubectl get lease -n kube-system
```

---

## Static Pod Manifests

```bash
# Location on control plane node
ls /etc/kubernetes/manifests/
# etcd.yaml
# kube-apiserver.yaml
# kube-controller-manager.yaml
# kube-scheduler.yaml

# kubelet watches this directory
# Deleting/modifying → immediate restart
```

---

## PodDisruptionBudget

```yaml
# Ensure minimum availability during disruptions
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: my-pdb
spec:
  minAvailable: 2       # At least 2 must be running
  # OR
  maxUnavailable: 1     # At most 1 can be down
  selector:
    matchLabels:
      app: my-app
```

```bash
# Create PDB
kubectl apply -f pdb.yaml

# Check PDB
kubectl get pdb
# NAME    MIN AVAILABLE  MAX UNAVAILABLE  ALLOWED DISRUPTIONS
# my-pdb  2              N/A              1
```

---

## Pod Anti-Affinity (Spread Pods)

```yaml
spec:
  affinity:
    podAntiAffinity:
      # Hard rule (requiredDuring)
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels:
            app: my-app
        topologyKey: kubernetes.io/hostname

      # Soft rule (preferredDuring)
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchLabels:
              app: my-app
          topologyKey: kubernetes.io/hostname
```

---

## Exam Scenarios

### Check Control Plane Health

```bash
kubectl get pods -n kube-system
kubectl get --raw='/healthz'
kubectl get componentstatuses
```

### Create PDB

```bash
kubectl create pdb my-pdb \
  --selector=app=my-app \
  --min-available=2
```

### View Leader Election

```bash
kubectl get lease -n kube-system
kubectl describe lease kube-scheduler -n kube-system
```

---

## Time Budget (Exam)

- Inspect components: **2 minutes**
- Check health: **1 minute**
- Create PDB: **1 minute**
- **Total: ~4-5 minutes**
