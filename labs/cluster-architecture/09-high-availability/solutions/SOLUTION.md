# Lab 09: High Availability Clusters - Solution Guide

## Quick Solution (Exam Speed)

```bash
# Check control plane health
kubectl get pods -n kube-system | grep -E "etcd|apiserver|scheduler|controller"
kubectl get --raw='/healthz'

# Create PDB
kubectl create deployment my-app --image=nginx --replicas=3
cat > pdb.yaml << 'EOF'
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: my-app-pdb
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: my-app
EOF
kubectl apply -f pdb.yaml
```

---

## Complete Solution

### Step 1: Inspect Control Plane

```bash
# List all control plane components
kubectl get pods -n kube-system | grep -E "etcd|apiserver|scheduler|controller"

# Expected output:
# etcd-opscart                      1/1   Running
# kube-apiserver-opscart            1/1   Running
# kube-controller-manager-opscart   1/1   Running
# kube-scheduler-opscart            1/1   Running

# Check leader election
kubectl get lease -n kube-system
```

### Step 2: Verify Health

```bash
# API server health
kubectl get --raw='/healthz'   # ok
kubectl get --raw='/livez'     # ok
kubectl get --raw='/readyz'    # ok

# etcd health
kubectl exec -n kube-system etcd-opscart -- \
  etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/var/lib/minikube/certs/etcd/ca.crt \
  --cert=/var/lib/minikube/certs/etcd/server.crt \
  --key=/var/lib/minikube/certs/etcd/server.key \
  endpoint health
```

### Step 3: Create PodDisruptionBudget

```bash
# Create deployment
kubectl create deployment web-app --image=nginx --replicas=3

# Create PDB
cat > manifests/web-app-pdb.yaml << 'EOF'
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: web-app-pdb
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: web-app
EOF

kubectl apply -f manifests/web-app-pdb.yaml

# Verify
kubectl get pdb
# NAME             MIN AVAILABLE   ALLOWED DISRUPTIONS
# web-app-pdb   2               1
```

### Step 4: Configure Pod Anti-Affinity

```bash
kubectl apply -f manifests/web-app-ha.yaml

# Verify pods spread across nodes
kubectl get pods -l app=web-app-ha -o wide
```

### Run Automated Tests

```bash
./scripts/setup.sh
./scripts/test.sh
# Should show 13/13 checks passed
```

---

## etcd Quorum Reference

```
Nodes  │  Can Tolerate
───────┼──────────────
  1    │  0 failures
  3    │  1 failure   ← Minimum HA
  5    │  2 failures  ← Recommended
  7    │  3 failures  ← Enterprise
```

## Key Takeaways

✅ **3 control plane nodes** = minimum HA  
✅ **etcd quorum** = (n/2)+1 nodes needed  
✅ **PDB** prevents too many pods going down at once  
✅ **Anti-affinity** spreads pods across nodes  
✅ **Leader election** handles multiple schedulers/controllers  
✅ **Static pods** restart automatically via kubelet  

---

**Completed Lab 09?** ✅

Move to **[Lab 10: Cluster Components](../10-cluster-components/)**
