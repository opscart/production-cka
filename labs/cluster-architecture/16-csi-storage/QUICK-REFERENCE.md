# Lab 16: CSI Storage - Quick Reference

## Key Resources

```
PersistentVolume (PV)       → Actual storage (cluster-wide)
PersistentVolumeClaim (PVC) → Request for storage (namespaced)
StorageClass (SC)           → How to provision storage
```

---

## StorageClass

```bash
# List storage classes
kubectl get sc
kubectl get storageclass

# Default storage class (auto-used when PVC has no storageClassName)
kubectl get sc | grep "(default)"

# Describe
kubectl describe sc <name>
```

---

## PersistentVolume (Static)

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: my-pv
spec:
  capacity:
    storage: 5Gi
  accessModes:
  - ReadWriteOnce            # RWO, ROX, RWX, RWOP
  persistentVolumeReclaimPolicy: Retain   # Retain, Delete, Recycle
  storageClassName: manual   # must match PVC
  hostPath:                  # or nfs, csi, etc.
    path: /data/my-pv
```

---

## PersistentVolumeClaim

```yaml
# Static (binds to specific PV)
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
  namespace: my-namespace
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: manual   # must match PV

# Dynamic (auto-provisions via StorageClass)
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
  namespace: my-namespace
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  # no storageClassName = uses default SC
```

---

## Mount PVC in Pod

```yaml
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: data
      mountPath: /data        # where to mount inside container
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: my-pvc       # must exist in same namespace
```

---

## Key Commands

```bash
# Check PVs
kubectl get pv
kubectl describe pv <name>

# Check PVCs
kubectl get pvc -n <namespace>
kubectl describe pvc <name> -n <namespace>

# Check binding
kubectl get pv,pvc -n <namespace>

# Verify mounted in pod
kubectl exec <pod> -n <ns> -- df -h /data
kubectl exec <pod> -n <ns> -- ls /data
```

---

## Access Modes

```
RWO  (ReadWriteOnce)    → One node read/write    (most common)
ROX  (ReadOnlyMany)     → Many nodes read-only
RWX  (ReadWriteMany)    → Many nodes read/write  (NFS/CephFS)
RWOP (ReadWriteOncePod) → Single pod only
```

---

## Reclaim Policies

```
Retain  → PV kept after PVC deleted, status = Released
Delete  → PV and backend storage deleted with PVC
Recycle → Data wiped, PV reused (deprecated)
```

---

## Troubleshooting

```bash
# PVC stuck Pending
kubectl describe pvc <name> -n <ns>
# Check: capacity match, accessMode match, storageClass exists

# Re-use Released PV (Retain policy)
kubectl patch pv <name> --type=json \
  -p='[{"op":"remove","path":"/spec/claimRef"}]'
# PV goes back to Available

# Check if default SC exists
kubectl get sc | grep default
```

---

## Exam Scenarios

### Create PV + PVC + Pod
```bash
# 1. Create PV
kubectl apply -f pv.yaml

# 2. Create PVC
kubectl apply -f pvc.yaml

# 3. Verify bound
kubectl get pv,pvc

# 4. Use in pod
kubectl apply -f pod.yaml

# 5. Verify mount
kubectl exec <pod> -- df -h /mount-path
```

---

## Time Budget (Exam)

- Create PV: **1 minute**
- Create PVC: **1 minute**
- Mount in pod: **1 minute**
- Verify: **30 seconds**
- **Total: ~4 minutes**