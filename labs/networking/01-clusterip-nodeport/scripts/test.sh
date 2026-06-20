#!/bin/bash
# Networking Lab 01: ClusterIP & NodePort - Test Script

set -e

echo "🧪 Networking Lab 01: ClusterIP & NodePort Tests"
echo "=================================================="
echo ""

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="lab01-services"
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

echo -e "${BLUE}=== Namespace and Deployment ===${NC}"
echo ""

run_check "namespace lab01-services exists" \
    "kubectl get namespace $NAMESPACE"

run_check "web-app deployment exists" \
    "kubectl get deployment web-app -n $NAMESPACE"

run_check "web-app has 3 ready replicas" \
    "kubectl get deployment web-app -n $NAMESPACE \
     -o jsonpath='{.status.readyReplicas}' | grep -q 3"

echo ""
echo -e "${BLUE}=== ClusterIP Service ===${NC}"
echo ""

run_check "web-app-clusterip service exists" \
    "kubectl get service web-app-clusterip -n $NAMESPACE"

run_check "service type is ClusterIP" \
    "kubectl get service web-app-clusterip -n $NAMESPACE \
     -o jsonpath='{.spec.type}' | grep -q ClusterIP"

run_check "service has a ClusterIP assigned" \
    "kubectl get service web-app-clusterip -n $NAMESPACE \
     -o jsonpath='{.spec.clusterIP}' | grep -qE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+'"

echo ""
echo -e "${BLUE}=== Endpoints ===${NC}"
echo ""

run_check "web-app-clusterip has 3 endpoints" \
    "kubectl get endpoints web-app-clusterip -n $NAMESPACE \
     -o jsonpath='{.subsets[0].addresses}' | grep -o 'ip' | wc -l | grep -q 3"

run_check "EndpointSlice exists for web-app-clusterip" \
    "kubectl get endpointslice -n $NAMESPACE \
     -l kubernetes.io/service-name=web-app-clusterip --no-headers | grep -q ."

total=$((total + 1))
echo -ne "Checking broken-service exists with zero endpoints (exam trap demo)... "
BROKEN_SUBSETS=$(kubectl get endpoints broken-service -n $NAMESPACE \
  -o jsonpath='{.subsets}' 2>/dev/null)
if [ -z "$BROKEN_SUBSETS" ]; then
    echo -e "${GREEN}✓ PASS${NC}"
    passed=$((passed + 1))
else
    echo -e "${RED}✗ FAIL${NC}"
    echo "  subsets returned: $BROKEN_SUBSETS"
fi

echo ""
echo -e "${BLUE}=== NodePort Service ===${NC}"
echo ""

run_check "web-app-nodeport service exists" \
    "kubectl get service web-app-nodeport -n $NAMESPACE"

run_check "service type is NodePort" \
    "kubectl get service web-app-nodeport -n $NAMESPACE \
     -o jsonpath='{.spec.type}' | grep -q NodePort"

run_check "nodePort is 30080" \
    "kubectl get service web-app-nodeport -n $NAMESPACE \
     -o jsonpath='{.spec.ports[0].nodePort}' | grep -q 30080"

echo ""
echo -e "${BLUE}=== Connectivity ===${NC}"
echo ""

CLUSTER_IP=$(kubectl get service web-app-clusterip -n $NAMESPACE \
  -o jsonpath='{.spec.clusterIP}' 2>/dev/null)

run_check "test-client pod is running" \
    "kubectl get pod test-client -n $NAMESPACE \
     -o jsonpath='{.status.phase}' | grep -q Running"

run_check "ClusterIP reachable by IP from test-client" \
    "kubectl exec test-client -n $NAMESPACE -- \
     wget -q -O /dev/null --timeout=5 http://$CLUSTER_IP"

run_check "ClusterIP reachable by DNS name from test-client" \
    "kubectl exec test-client -n $NAMESPACE -- \
     wget -q -O /dev/null --timeout=5 http://web-app-clusterip"

run_check "NodePort reachable on node (via minikube ssh)" \
    "minikube ssh 'curl -s -o /dev/null -w \"%{http_code}\" http://localhost:30080' 2>/dev/null | grep -q 200"

echo ""
echo "=================================================="
echo -e "Results: ${passed}/${total} checks passed"
echo ""

if [ $passed -eq $total ]; then
    echo -e "${GREEN}🎉 All checks passed! Networking Lab 01 complete!${NC}"
    echo ""
    echo "Services summary:"
    kubectl get svc -n $NAMESPACE
else
    echo -e "${RED}Some checks failed${NC}"
    echo ""
    echo "Debug:"
    kubectl get svc,endpoints -n $NAMESPACE
    kubectl get pods -n $NAMESPACE -o wide
fi

echo ""
echo "Cleanup: ./scripts/cleanup.sh"