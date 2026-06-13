# Lab 16: CSI Storage - Solution Guide

## Run the Scripts
```bash
./scripts/setup.sh
./scripts/test.sh
./scripts/cleanup.sh
```

---

## Complete Manual Solution

### Step 1: Create Namespace
```bash
kubectl create namespace lab16-storage
```

### Step 2: Static PV + PVC
```bash
# Create PV
kubectl apply -f - << 'EOF'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: lab16-static-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /data/lab16-static-pv
  storageClassName: manual
EOF

# Create PVC
kubectl apply -f - << 'EOF'
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

# Verify binding
kubectl get pv lab16-static-pv     # STATUS: Bound
kubectl get pvc static-pvc -n lab16-storage  # STATUS: Bound
```

### Step 3: Dynamic PVC
```bash
# No storageClassName = uses default StorageClass
kubectl apply -f - << 'EOF'
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

# PV auto-created!
kubectl get pv  # new PV appears automatically
kubectl get pvc dynamic-pvc -n lab16-storage  # STATUS: Bound
```

### Step 4: Use PVC in Pod
```bash
kubectl apply -f - << 'EOF'
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

# Write data
kubectl exec storage-pod -n lab16-storage -- \
  sh -c "echo 'persistent data test' > /data/test.txt"

# Read data
kubectl exec storage-pod -n lab16-storage -- cat /data/test.txt

# Check mount
kubectl exec storage-pod -n lab16-storage -- df -h /data
```

### Step 5: Test Retain Policy
```bash
# Delete PVC
kubectl delete pvc static-pvc -n lab16-storage

# PV still exists (Retain policy!)
kubectl get pv lab16-static-pv
# STATUS: Released (not Available - has old claimRef)

# To reuse: remove claimRef
kubectl patch pv lab16-static-pv --type=json \
  -p='[{"op":"remove","path":"/spec/claimRef"}]'

kubectl get pv lab16-static-pv
# STATUS: Available (ready for new PVC)
```

---

## Key Takeaways

✅ **PV** = actual storage (cluster-scoped)
✅ **PVC** = request for storage (namespace-scoped)
✅ **StorageClass** = provisioner configuration
✅ Static: Admin creates PV, PVC binds to it
✅ Dynamic: PVC triggers auto-provisioning via StorageClass
✅ **Retain** policy keeps PV after PVC deleted
✅ **Delete** policy removes PV and storage with PVC
✅ PVCs and pods must be in same namespace

---

**Completed Lab 16?** ✅

Move to **[Lab 17: CRI Container Runtimes](../17-cri-runtimes/)**