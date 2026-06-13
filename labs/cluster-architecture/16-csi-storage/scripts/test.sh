#!/bin/bash
# Lab 16: CSI Storage - Test Script

set -e

echo "🧪 Lab 16: CSI Storage Tests"
echo "=============================="
echo ""

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="lab16-storage"
passed=0
total=0

run_check() {
    local name="$1"
    local cmd="$2"
    total=$((total + 1))
    echo -ne "Checking $name... "
    if eval "$cmd" &>/dev/null; then
        echo -e "${GREEN}✓ PASS${NC}"
        passed=$((passed + 1))
    else
        echo -e "${RED}✗ FAIL${NC}"
    fi
}

echo -e "${BLUE}=== Storage Classes ===${NC}"
echo ""

run_check "at least one StorageClass exists" \
    "kubectl get sc --no-headers | grep -q ."

run_check "default StorageClass exists" \
    "kubectl get sc -o jsonpath='{.items[*].metadata.annotations}' | \
     grep -q 'storageclass.kubernetes.io/is-default-class.*true'"

echo ""
echo -e "${BLUE}=== Static PersistentVolume ===${NC}"
echo ""

run_check "lab16-static-pv exists" \
    "kubectl get pv lab16-static-pv"

run_check "PV capacity is 1Gi" \
    "kubectl get pv lab16-static-pv \
     -o jsonpath='{.spec.capacity.storage}' | grep -q 1Gi"

run_check "PV access mode is ReadWriteOnce" \
    "kubectl get pv lab16-static-pv \
     -o jsonpath='{.spec.accessModes[0]}' | grep -q ReadWriteOnce"

run_check "PV reclaim policy is Retain" \
    "kubectl get pv lab16-static-pv \
     -o jsonpath='{.spec.persistentVolumeReclaimPolicy}' | grep -q Retain"

run_check "PV storageClass is manual" \
    "kubectl get pv lab16-static-pv \
     -o jsonpath='{.spec.storageClassName}' | grep -q manual"

echo ""
echo -e "${BLUE}=== Static PVC ===${NC}"
echo ""

run_check "static-pvc exists" \
    "kubectl get pvc static-pvc -n $NAMESPACE"

run_check "static-pvc is Bound" \
    "kubectl get pvc static-pvc -n $NAMESPACE \
     -o jsonpath='{.status.phase}' | grep -q Bound"

run_check "static-pvc bound to lab16-static-pv" \
    "kubectl get pvc static-pvc -n $NAMESPACE \
     -o jsonpath='{.spec.volumeName}' | grep -q lab16-static-pv"

echo ""
echo -e "${BLUE}=== Dynamic PVC ===${NC}"
echo ""

run_check "dynamic-pvc exists" \
    "kubectl get pvc dynamic-pvc -n $NAMESPACE"

run_check "dynamic-pvc is Bound" \
    "kubectl get pvc dynamic-pvc -n $NAMESPACE \
     -o jsonpath='{.status.phase}' | grep -q Bound"

run_check "dynamic PV was auto-created" \
    "kubectl get pv --no-headers | grep -v lab16-static-pv | grep -q Bound"

echo ""
echo -e "${BLUE}=== Pod with Storage ===${NC}"
echo ""

run_check "storage-pod exists" \
    "kubectl get pod storage-pod -n $NAMESPACE"

run_check "storage-pod is Running" \
    "kubectl get pod storage-pod -n $NAMESPACE \
     -o jsonpath='{.status.phase}' | grep -q Running"

run_check "storage-pod uses static-pvc" \
    "kubectl get pod storage-pod -n $NAMESPACE \
     -o jsonpath='{.spec.volumes[0].persistentVolumeClaim.claimName}' \
     | grep -q static-pvc"

run_check "volume is mounted at /data" \
    "kubectl get pod storage-pod -n $NAMESPACE \
     -o jsonpath='{.spec.containers[0].volumeMounts[0].mountPath}' \
     | grep -q /data"

run_check "data persists in volume" \
    "kubectl exec storage-pod -n $NAMESPACE -- cat /data/test.txt | grep -q 'persistent'"

echo ""
echo "=============================="
echo -e "Results: ${passed}/${total} checks passed"
echo ""

if [ $passed -eq $total ]; then
    echo -e "${GREEN}🎉 All checks passed! Lab 16 complete!${NC}"
    echo ""
    echo "PersistentVolumes:"
    kubectl get pv
    echo ""
    echo "PersistentVolumeClaims:"
    kubectl get pvc -n $NAMESPACE
else
    echo -e "${RED}Some checks failed${NC}"
    echo ""
    echo "Debug:"
    kubectl get pv
    kubectl get pvc -n $NAMESPACE
    kubectl describe pvc -n $NAMESPACE
fi

echo ""
echo "Cleanup: ./scripts/cleanup.sh"