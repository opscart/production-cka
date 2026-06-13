# Lab 16: CSI Storage

## Objective
Understand Container Storage Interface (CSI), work with PersistentVolumes, PersistentVolumeClaims, and StorageClasses. Learn how Kubernetes provisions storage dynamically and statically.

## CKA Exam Relevance
- **Domain:** Storage (10%) + Cluster Architecture (25%)
- **Topic:** Understand persistent storage and CSI
- **Exam Weight:** High (appears in 70%+ of exams)
- **Typical Exam Time:** 8-10 minutes

## Time to Complete
45 minutes

## Prerequisites
- Completed Labs 01-15
- Basic understanding of storage concepts

---

## What is CSI?

**CSI (Container Storage Interface)** is a standard that lets storage vendors write plugins to work with Kubernetes without modifying core Kubernetes code.

```
Without CSI:                    With CSI:
────────────────────────        ────────────────────────────────
Storage code built into         Storage vendors write plugins:
Kubernetes core                 - AWS EBS CSI driver
(hard to update, limited)       - Azure Disk CSI driver
                                - GCE PD CSI driver
                                - NFS CSI driver
```

---

## Storage Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    Kubernetes Storage Stack                   │
│                                                              │
│  Pod                                                         │
│  └─► PersistentVolumeClaim (PVC)  ─► "I need 5Gi storage"  │
│            │                                                 │
│            ▼                                                 │
│  StorageClass  ─────────────────────► "How to provision"    │
│            │                                                 │
│            ▼                                                 │
│  PersistentVolume (PV) ─────────────► "Actual storage"      │
│            │                                                 │
│            ▼                                                 │
│  CSI Driver ────────────────────────► "Talks to backend"    │
│            │                                                 │
│            ▼                                                 │
│  Storage Backend (AWS EBS, Azure Disk, NFS, hostPath)        │
└──────────────────────────────────────────────────────────────┘
```

---

## Static vs Dynamic Provisioning

```
Static:                          Dynamic:
────────────────────────────     ────────────────────────────────
Admin creates PV manually        StorageClass provisions PV
PVC binds to existing PV         PVC triggers automatic PV creation
More control                     More convenient
```

---

## Tasks

### Task 1: Explore Storage Classes (5 min)

**Objective:** Find available storage classes.

```bash
# List storage classes
kubectl get storageclass
kubectl get sc     # short name

# View default storage class
kubectl get sc -o wide

# Describe storage class
kubectl describe sc standard

# Note which is default (marked with *)
# StorageClass with (default) annotation auto-provisions PVCs
```

---

### Task 2: Static Provisioning - Create PV and PVC (15 min)

**Objective:** Manually create a PersistentVolume and claim it.

```bash
kubectl create namespace lab16-storage

# Create a PersistentVolume (hostPath for minikube)
cat > manifests/static-pv.yaml << 'EOF'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: static-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /data/static-pv
  storageClassName: manual
EOF

kubectl apply -f manifests/static-pv.yaml

# Create PVC that binds to the PV
cat > manifests/static-pvc.yaml << 'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: static-pvc
  namespace: lab16-storage
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: manual
EOF

kubectl apply -f manifests/static-pvc.yaml

# Verify binding
kubectl get pv static-pv
kubectl get pvc static-pvc -n lab16-storage
# STATUS should be: Bound
```

---

### Task 3: Dynamic Provisioning - PVC with StorageClass (10 min)

**Objective:** Use StorageClass to automatically provision storage.

```bash
# Create PVC using default storage class (no storageClassName needed)
cat > manifests/dynamic-pvc.yaml << 'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: dynamic-pvc
  namespace: lab16-storage
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
EOF

kubectl apply -f manifests/dynamic-pvc.yaml

# Check - PV automatically created!
kubectl get pvc dynamic-pvc -n lab16-storage
kubectl get pv  # New PV automatically created

# Describe to see storage class used
kubectl describe pvc dynamic-pvc -n lab16-storage
```

---

### Task 4: Mount Storage in Pod (10 min)

**Objective:** Use PVCs in pods.

```bash
# Create pod using static PVC
cat > manifests/storage-pod.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: storage-pod
  namespace: lab16-storage
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: data-volume
      mountPath: /data
  volumes:
  - name: data-volume
    persistentVolumeClaim:
      claimName: static-pvc
EOF

kubectl apply -f manifests/storage-pod.yaml
kubectl wait --for=condition=ready pod/storage-pod \
  -n lab16-storage --timeout=60s

# Write data to volume
kubectl exec storage-pod -n lab16-storage -- \
  sh -c "echo 'persistent data' > /data/test.txt"

# Read it back
kubectl exec storage-pod -n lab16-storage -- \
  cat /data/test.txt

# Verify volume is mounted
kubectl exec storage-pod -n lab16-storage -- \
  df -h /data
```

---

### Task 5: Access Modes and Reclaim Policies (5 min)

**Objective:** Understand access modes and what happens when PVC is deleted.

**Access Modes:**
```
ReadWriteOnce (RWO)  - One node at a time (most common)
ReadOnlyMany (ROX)   - Many nodes, read-only
ReadWriteMany (RWX)  - Many nodes, read-write (NFS, CephFS)
ReadWriteOncePod     - Single pod only (newest)
```

**Reclaim Policies:**
```
Retain  - PV kept after PVC deleted (manual cleanup)
Delete  - PV and storage deleted when PVC deleted
Recycle - Data wiped, PV available again (deprecated)
```

```bash
# Check reclaim policies
kubectl get pv -o custom-columns=\
NAME:.metadata.name,\
CAPACITY:.spec.capacity.storage,\
POLICY:.spec.persistentVolumeReclaimPolicy,\
STATUS:.status.phase

# Delete PVC and observe PV behavior
kubectl delete pvc static-pvc -n lab16-storage

# With Retain policy - PV stays but shows Released
kubectl get pv static-pv
# STATUS: Released (not Bound, not Available)
```

---

## Exam Tips

⏱️ **Time Management:**
- Create PV: 2 minutes
- Create PVC: 1 minute
- Mount in pod: 2 minutes
- Verify: 1 minute
- **Total: ~6 minutes**

🎯 **Exam Question Patterns:**

> *"Create a PersistentVolume of 2Gi with ReadWriteOnce access"*

> *"Create a PVC that requests 1Gi and binds to the existing PV"*

> *"Mount the PVC into a pod at /data"*

> *"What happens to a PV with Retain policy when PVC is deleted?"*
→ PV status changes to **Released**

🔑 **Key Commands:**
```bash
kubectl get pv
kubectl get pvc -n <namespace>
kubectl get sc
kubectl describe pvc <name> -n <namespace>
```

---

## Common Issues

### PVC stuck in Pending
```bash
kubectl describe pvc <name> -n <namespace>
# Check Events:
# - No matching PV (capacity/accessMode mismatch)
# - No default StorageClass
# - StorageClass doesn't exist
```

### PV stuck in Released (not Available)
```bash
# PV with Retain policy keeps old claimRef
# Remove claimRef to make it Available again
kubectl patch pv <pv-name> --type=json \
  -p='[{"op":"remove","path":"/spec/claimRef"}]'
```

---

## ⚠️ Minikube-Specific Challenges & Solutions

### Challenge 1: No Default StorageClass

**Problem:** Dynamic PVC stuck in Pending
```
Events: no persistent volumes available for this claim and no storage class is set
```

**Why:** Minikube doesn't enable the storage provisioner addon by default.

**Solution:**
```bash
# Enable storage addons
minikube addons enable storage-provisioner
minikube addons enable default-storageclass

# Verify
kubectl get sc
# standard (default)   k8s.io/minikube-hostpath   Delete   Immediate   false   5s
```

**On kubeadm/production:** Default StorageClass configured at cluster setup (cloud providers auto-configure it).

---

### Challenge 2: heredoc EOF Conflicts

**Problem:** Script fails with syntax error
```
./scripts/setup.sh: command substitution: line 10: syntax error near unexpected token `PV'
```

**Why:** Multiple heredocs using the same `EOF` delimiter cause conflicts when the script contains comment blocks with similar content.

**Solution:** Use unique delimiters per heredoc:
```bash
# Instead of all using EOF:
cat > file.yaml << 'EOF'    # conflicts!

# Use unique names:
cat > pv.yaml << 'PVEOF'
cat > pvc.yaml << 'PVCEOF'
cat > pod.yaml << 'PODEOF'
```

---

### Challenge 3: Dynamic PV Uses Different StorageClass Name

**Observation:** Static PV uses `manual` StorageClass but dynamic PV uses `standard`.
```
lab16-static-pv   manual    (manually created)
pvc-xxx           standard  (auto-provisioned by minikube)
```

**Why:** Minikube's default StorageClass is named `standard`. The `standard` SC uses `k8s.io/minikube-hostpath` provisioner which automatically creates PVs.

**On production (AKS):** Default StorageClass is `default` using Azure Disk provisioner.

---

## Next Lab

Move to **[Lab 17: CRI Container Runtimes](../17-cri-runtimes/README.md)**

---

**Author:** Shamsher Khan | **Blog:** opscart.com | **Course:** Production CKA 2026