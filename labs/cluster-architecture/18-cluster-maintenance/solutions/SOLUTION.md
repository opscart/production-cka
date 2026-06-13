# Lab 18: Cluster Maintenance - Solution Guide

## Run the Scripts
```bash
./scripts/setup.sh
./scripts/test.sh
./scripts/cleanup.sh
```

---

## Complete Manual Solution

### Step 1: Prepare Workload
```bash
kubectl create namespace lab18-maintenance

kubectl create deployment web-maintenance \
  --image=nginx \
  --replicas=4 \
  -n lab18-maintenance

# Create PDB to protect availability during drain
kubectl apply -f - << 'PDBEOF'
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: web-maintenance-pdb
  namespace: lab18-maintenance
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: web-maintenance
PDBEOF

kubectl get pods -n lab18-maintenance -o wide
```

### Step 2: Cordon Node
```bash
kubectl cordon opscart-m02

# Verify
kubectl get nodes
# opscart-m02   Ready,SchedulingDisabled   ...
```

### Step 3: Drain Node
```bash
kubectl drain opscart-m02 \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --grace-period=30

# Verify pods moved to other nodes
kubectl get pods -n lab18-maintenance -o wide
# No pods should be on opscart-m02
```

### Step 4: Perform Maintenance
```bash
# SSH to node and do maintenance
# minikube ssh -n opscart-m02
# sudo apt update && sudo apt upgrade -y
# sudo reboot

# Wait for node to come back
kubectl wait --for=condition=Ready node/opscart-m02 --timeout=300s
```

### Step 5: Uncordon
```bash
kubectl uncordon opscart-m02

# Verify
kubectl get nodes
# All Ready (no SchedulingDisabled)

# Pods will reschedule gradually
kubectl get pods -n lab18-maintenance -o wide
```

### Step 6: Certificate Check
```bash
# On kubeadm clusters
sudo kubeadm certs check-expiration

# On minikube (openssl method)
minikube ssh "sudo openssl x509 \
  -in /var/lib/minikube/certs/apiserver.crt \
  -noout -subject -dates"
```

---

## Cordon vs Drain

```
kubectl cordon <node>
  → Marks unschedulable
  → DOES NOT evict existing pods
  → Use when: preventing NEW pods from landing

kubectl drain <node>
  → Marks unschedulable (like cordon)
  → EVICTS existing pods gracefully
  → Respects PodDisruptionBudgets
  → Use when: taking node OFFLINE for maintenance
```

---

## What Drain Does to Different Pod Types

```
Regular pods     → Evicted (graceful termination)
DaemonSet pods   → Skipped (--ignore-daemonsets)
Static pods      → Skipped (managed by kubelet)
Mirror pods      → Skipped
emptyDir pods    → Evicted only with --delete-emptydir-data
```

---

## PDB Role During Drain

```
PDB: minAvailable: 2
Deployment: 4 replicas
Node: opscart-m02 (1 pod)

Drain process:
1. Try to evict pod on opscart-m02
2. Check: after eviction, will minAvailable (2) be met?
3. 4 pods - 1 = 3 remaining ≥ 2 → OK to evict
4. Eviction proceeds
```

---

## Key Takeaways

✅ `cordon` = prevent new scheduling (existing pods stay)
✅ `drain` = cordon + evict all eligible pods
✅ `--ignore-daemonsets` is almost always required
✅ PDBs are respected during drain
✅ Certificate expiry should be monitored (90-day warning)
✅ Always uncordon after maintenance
✅ Check node conditions: MemoryPressure, DiskPressure, PIDPressure

---

🎉 **Cluster Architecture Domain Complete! (18/18 labs)**

Next: **[Domain 2: Services & Networking](../../networking/01-service-types/)**