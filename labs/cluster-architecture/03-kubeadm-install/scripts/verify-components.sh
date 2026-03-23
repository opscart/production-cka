#!/bin/bash
# Lab 03: kubeadm Installation - Verify Components Script

set -e

echo "✅ Lab 03: Verify Cluster Components"
echo "====================================="
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

total_checks=0
passed_checks=0

# Function to run check
run_check() {
    local check_name="$1"
    local command="$2"
    
    total_checks=$((total_checks + 1))
    
    echo -ne "${YELLOW}Checking $check_name... ${NC}"
    
    if eval "$command" &> /dev/null; then
        echo -e "${GREEN}✓ PASS${NC}"
        passed_checks=$((passed_checks + 1))
    else
        echo -e "${RED}✗ FAIL${NC}"
    fi
}

echo -e "${BLUE}=== API Server Health ===${NC}"
echo ""

run_check "API server /healthz endpoint" \
    "kubectl get --raw='/healthz' | grep -q ok"

run_check "API server /readyz endpoint" \
    "kubectl get --raw='/readyz' | grep -q ok"

echo ""
echo -e "${BLUE}=== Control Plane Components ===${NC}"
echo ""

run_check "etcd pod running" \
    "kubectl get pod -n kube-system -l component=etcd --no-headers | grep -q Running"

run_check "API server pod running" \
    "kubectl get pod -n kube-system -l component=kube-apiserver --no-headers | grep -q Running"

run_check "Controller manager pod running" \
    "kubectl get pod -n kube-system -l component=kube-controller-manager --no-headers | grep -q Running"

run_check "Scheduler pod running" \
    "kubectl get pod -n kube-system -l component=kube-scheduler --no-headers | grep -q Running"

echo ""
echo -e "${BLUE}=== Node Components ===${NC}"
echo ""

run_check "All nodes Ready" \
    "kubectl get nodes --no-headers | grep -v NotReady | wc -l | grep -q 3"

run_check "kube-proxy running on all nodes" \
    "kubectl get pods -n kube-system -l k8s-app=kube-proxy --no-headers | grep -c Running | grep -q 3"

echo ""
echo -e "${BLUE}=== Networking ===${NC}"
echo ""

run_check "CNI plugin installed" \
    "kubectl get pods -n kube-system -l k8s-app=kindnet --no-headers | grep -q Running"

run_check "CoreDNS running" \
    "kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers | grep -q Running"

echo ""
echo -e "${BLUE}=== Functional Tests ===${NC}"
echo ""

# Create test deployment
echo "Creating test deployment..."
kubectl create deployment nginx-test --image=nginx --replicas=2 &> /dev/null || true

# Wait for deployment to be ready (up to 60 seconds)
echo "Waiting for pods to be ready..."
kubectl wait --for=condition=available --timeout=60s deployment/nginx-test &> /dev/null || true

run_check "Pods can be scheduled" \
    "kubectl get deployment nginx-test -o jsonpath='{.status.availableReplicas}' | grep -q 2"

run_check "Service can be created" \
    "kubectl expose deployment nginx-test --port=80 --target-port=80 &> /dev/null; kubectl get svc nginx-test"

run_check "DNS resolution works" \
    "kubectl run test-dns --image=busybox --rm -it --restart=Never -- nslookup kubernetes.default &> /dev/null || true"

# Cleanup
echo ""
echo "Cleaning up test resources..."
kubectl delete deployment nginx-test &> /dev/null || true
kubectl delete service nginx-test &> /dev/null || true
kubectl delete pod test-dns &> /dev/null || true

echo ""
echo "====================================="
echo -e "${BLUE}Verification Results: $passed_checks/$total_checks checks passed${NC}"
echo "====================================="
echo ""

if [ $passed_checks -eq $total_checks ]; then
    echo -e "${GREEN}🎉 All checks passed! Cluster is fully functional!${NC}"
    echo ""
    echo "Your cluster has:"
    echo "  ✓ Healthy control plane components"
    echo "  ✓ All nodes ready"
    echo "  ✓ Working networking (CNI + DNS)"
    echo "  ✓ Ability to schedule and run pods"
    echo ""
    echo "This is what kubeadm creates when you run:"
    echo "  sudo kubeadm init"
    echo ""
    echo "Next: Study the SOLUTION.md for exam scenarios"
    exit 0
else
    echo -e "${RED}❌ Some checks failed. Cluster needs attention.${NC}"
    echo ""
    echo "Debug steps:"
    echo "  1. Check control plane pods: kubectl get pods -n kube-system"
    echo "  2. View pod logs: kubectl logs -n kube-system <pod-name>"
    echo "  3. Check node status: kubectl describe node <node-name>"
    exit 1
fi