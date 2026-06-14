#!/bin/bash
# Lab 16: CSI Storage - Setup Script

set -e

echo "🔧 Lab 16: CSI Storage Setup"
echo "=============================="
echo ""

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="lab16-storage"

echo -e "${BLUE}Step 1: Creating namespace...${NC}"
kubectl create namespace $NAMESPACE 2>/dev/null || echo "Already exists"
echo -e "${GREEN}✓ Namespace: $NAMESPACE${NC}"
echo ""

echo -e "${BLUE}Step 2: Creating static PersistentVolume...${NC}"
cat > manifests/static-pv.yaml << 'PVEOF'
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
PVEOF
kubectl apply -f manifests/static-pv.yaml
echo -e "${GREEN}✓ PersistentVolume: lab16-static-pv${NC}"
echo ""

echo -e "${BLUE}Step 3: Creating static PVC...${NC}"
cat > manifests/static-pvc.yaml << 'PVCEOF'
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
PVCEOF
kubectl apply -f manifests/static-pvc.yaml
echo -e "${GREEN}✓ PVC: static-pvc${NC}"
echo ""

echo -e "${BLUE}Step 4: Creating dynamic PVC...${NC}"
cat > manifests/dynamic-pvc.yaml << 'DYNEOF'
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
DYNEOF
kubectl apply -f manifests/dynamic-pvc.yaml
echo -e "${GREEN}✓ PVC: dynamic-pvc${NC}"
echo ""

echo -e "${BLUE}Step 5: Waiting for PVCs to bind...${NC}"
sleep 5

STATUS=$(kubectl get pvc static-pvc -n $NAMESPACE \
  -o jsonpath='{.status.phase}')
echo "  static-pvc: $STATUS"

STATUS=$(kubectl get pvc dynamic-pvc -n $NAMESPACE \
  -o jsonpath='{.status.phase}')
echo "  dynamic-pvc: $STATUS"
echo ""

echo -e "${BLUE}Step 6: Creating storage pod...${NC}"
cat > manifests/storage-pod.yaml << 'PODEOF'
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
PODEOF
kubectl apply -f manifests/storage-pod.yaml
kubectl wait --for=condition=ready pod/storage-pod \
  -n $NAMESPACE --timeout=60s

# Write test data
kubectl exec storage-pod -n $NAMESPACE -- \
  sh -c "echo 'persistent data test' > /data/test.txt"
echo -e "${GREEN}✓ Pod: storage-pod (with data written)${NC}"
echo ""

echo "=============================="
echo -e "${GREEN}✓ Setup complete!${NC}"
echo ""
echo "PersistentVolumes:"
kubectl get pv | grep -E "NAME|lab16"
echo ""
echo "PersistentVolumeClaims:"
kubectl get pvc -n $NAMESPACE
echo ""
echo "Run: ./scripts/test.sh"