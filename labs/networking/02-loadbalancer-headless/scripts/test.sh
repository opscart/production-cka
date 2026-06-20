#!/bin/bash
# Networking Lab 02: LoadBalancer & Headless Services - Test Script

set -e

echo "🧪 Networking Lab 02: LoadBalancer & Headless Tests"
echo "======================================================"
echo ""

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="lab02-services"
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

echo -e "${BLUE}=== LoadBalancer Service ===${NC}"
echo ""

run_check "web-app-lb service exists" \
    "kubectl get service web-app-lb -n $NAMESPACE"

run_check "service type is LoadBalancer" \
    "kubectl get service web-app-lb -n $NAMESPACE \
     -o jsonpath='{.spec.type}' | grep -q LoadBalancer"

run_check "service has a ClusterIP assigned (even though LoadBalancer)" \
    "kubectl get service web-app-lb -n $NAMESPACE \
     -o jsonpath='{.spec.clusterIP}' | grep -qE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+'"

run_check "service has an auto-assigned NodePort" \
    "kubectl get service web-app-lb -n $NAMESPACE \
     -o jsonpath='{.spec.ports[0].nodePort}' | grep -qE '[0-9]+'"

echo ""
echo -e "${BLUE}=== Headless Service ===${NC}"
echo ""

run_check "web-app-headless service exists" \
    "kubectl get service web-app-headless -n $NAMESPACE"

run_check "headless service has clusterIP: None" \
    "kubectl get service web-app-headless -n $NAMESPACE \
     -o jsonpath='{.spec.clusterIP}' | grep -q None"

run_check "headless service has endpoints (pods reachable)" \
    "kubectl get endpoints web-app-headless -n $NAMESPACE \
     -o jsonpath='{.subsets[0].addresses}' 2>/dev/null | grep -q ip"

echo ""
echo -e "${BLUE}=== StatefulSet with Headless Service ===${NC}"
echo ""

run_check "postgres-headless service exists" \
    "kubectl get service postgres-headless -n $NAMESPACE"

run_check "postgres-headless has clusterIP: None" \
    "kubectl get service postgres-headless -n $NAMESPACE \
     -o jsonpath='{.spec.clusterIP}' | grep -q None"

run_check "postgres StatefulSet exists" \
    "kubectl get statefulset postgres -n $NAMESPACE"

run_check "StatefulSet serviceName matches headless service" \
    "kubectl get statefulset postgres -n $NAMESPACE \
     -o jsonpath='{.spec.serviceName}' | grep -q postgres-headless"

run_check "postgres-0 pod exists and is running" \
    "kubectl get pod postgres-0 -n $NAMESPACE \
     -o jsonpath='{.status.phase}' | grep -q Running"

run_check "postgres-1 pod exists and is running" \
    "kubectl get pod postgres-1 -n $NAMESPACE \
     -o jsonpath='{.status.phase}' | grep -q Running"

echo ""
echo -e "${BLUE}=== DNS Resolution Comparison ===${NC}"
echo ""

run_check "dns-test pod is running" \
    "kubectl get pod dns-test -n $NAMESPACE \
     -o jsonpath='{.status.phase}' | grep -q Running"

run_check "normal service resolves to single IP" \
    "[ \$(kubectl exec dns-test -n $NAMESPACE -- \
     nslookup web-app-lb.$NAMESPACE.svc.cluster.local 2>/dev/null | \
     grep -c 'Address') -le 2 ]"

run_check "headless service resolves to multiple pod IPs" \
    "[ \$(kubectl exec dns-test -n $NAMESPACE -- \
     nslookup web-app-headless.$NAMESPACE.svc.cluster.local 2>/dev/null | \
     grep -c 'Address') -ge 3 ]"

run_check "postgres-0 has its own stable DNS name" \
    "kubectl exec dns-test -n $NAMESPACE -- \
     nslookup postgres-0.postgres-headless.$NAMESPACE.svc.cluster.local 2>/dev/null | \
     grep -q Address"

run_check "postgres-1 has its own stable DNS name" \
    "kubectl exec dns-test -n $NAMESPACE -- \
     nslookup postgres-1.postgres-headless.$NAMESPACE.svc.cluster.local 2>/dev/null | \
     grep -q Address"

echo ""
echo "======================================================"
echo -e "Results: ${passed}/${total} checks passed"
echo ""

if [ $passed -eq $total ]; then
    echo -e "${GREEN}🎉 All checks passed! Networking Lab 02 complete!${NC}"
    echo ""
    echo "Services summary:"
    kubectl get svc -n $NAMESPACE
else
    echo -e "${RED}Some checks failed${NC}"
    echo ""
    echo "Debug:"
    kubectl get svc,statefulset,pods -n $NAMESPACE
fi

echo ""
echo "Cleanup: ./scripts/cleanup.sh"