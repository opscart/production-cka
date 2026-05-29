#!/bin/bash
# Lab 08: Kustomize Basics - Test Script

set -e

echo "🧪 Lab 08: Kustomize Tests"
echo "=========================="
echo ""

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

DEMO_DIR="./kustomize-demo"
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

# Apply overlays
echo -e "${BLUE}Deploying dev and staging environments...${NC}"
kubectl apply -k $DEMO_DIR/overlays/dev/ --wait
kubectl apply -k $DEMO_DIR/overlays/staging/ --wait
echo ""

# Wait for deployments
kubectl wait --for=condition=available --timeout=60s deployment/dev-pharma-api
kubectl wait --for=condition=available --timeout=60s deployment/staging-pharma-api

echo -e "${BLUE}Running validation checks...${NC}"
echo ""

run_check "dev deployment exists" \
    "kubectl get deployment dev-pharma-api"

run_check "dev has 1 replica" \
    "kubectl get deployment dev-pharma-api -o jsonpath='{.spec.replicas}' | grep -q 1"

run_check "dev label set" \
    "kubectl get deployment dev-pharma-api -o jsonpath='{.metadata.labels}' | grep -q environment"

run_check "staging deployment exists" \
    "kubectl get deployment staging-pharma-api"

run_check "staging has 2 replicas" \
    "kubectl get deployment staging-pharma-api -o jsonpath='{.spec.replicas}' | grep -q 2"

run_check "staging label set" \
    "kubectl get deployment staging-pharma-api -o jsonpath='{.metadata.labels}' | grep -q environment"

run_check "dev service exists" \
    "kubectl get service dev-pharma-api"

run_check "staging service exists" \
    "kubectl get service staging-pharma-api"

run_check "dev pods running" \
    "kubectl get pods --no-headers | grep dev-pharma-api | grep -q Running"

run_check "staging pods running" \
    "kubectl get pods --no-headers | grep staging-pharma-api | grep -q Running"

echo ""
echo "=========================="
echo -e "Results: ${passed}/${total} checks passed"
echo ""

if [ $passed -eq $total ]; then
    echo -e "${GREEN}🎉 All checks passed! Lab 08 complete!${NC}"
    echo ""
    kubectl get deployments | grep -E "dev-|staging-"
else
    echo -e "${RED}Some checks failed${NC}"
    echo ""
    kubectl get all -l environment=dev
    kubectl get all -l environment=staging
fi

echo ""
echo "Cleanup: ./scripts/cleanup.sh"