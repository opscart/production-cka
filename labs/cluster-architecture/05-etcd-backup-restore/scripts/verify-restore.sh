#!/bin/bash
# Lab 05: etcd Backup & Restore - Verify Restore Script

set -e

echo "✅ Lab 05: Verify Restore"
echo "========================="
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

echo -e "${BLUE}=== Namespace Verification ===${NC}"
echo ""

run_check "backup-test namespace exists" \
    "kubectl get namespace backup-test"

echo ""
echo -e "${BLUE}=== Deployment Verification ===${NC}"
echo ""

run_check "nginx-test deployment exists" \
    "kubectl get deployment nginx-test -n backup-test"

run_check "nginx-test has 3 replicas" \
    "kubectl get deployment nginx-test -n backup-test -o jsonpath='{.spec.replicas}' | grep -q 3"

run_check "All pods are running" \
    "kubectl get pods -n backup-test -l app=nginx-test --no-headers | grep -c Running | grep -q 3"

echo ""
echo -e "${BLUE}=== Service Verification ===${NC}"
echo ""

run_check "nginx-test service exists" \
    "kubectl get service nginx-test -n backup-test"

run_check "Service has endpoints" \
    "kubectl get endpoints nginx-test -n backup-test -o jsonpath='{.subsets[*].addresses[*].ip}' | grep -q ."

echo ""
echo -e "${BLUE}=== ConfigMap Verification ===${NC}"
echo ""

run_check "test-config configmap exists" \
    "kubectl get configmap test-config -n backup-test"

run_check "ConfigMap has key1=value1" \
    "kubectl get configmap test-config -n backup-test -o jsonpath='{.data.key1}' | grep -q value1"

run_check "ConfigMap has key2=value2" \
    "kubectl get configmap test-config -n backup-test -o jsonpath='{.data.key2}' | grep -q value2"

echo ""
echo -e "${BLUE}=== Secret Verification ===${NC}"
echo ""

run_check "test-secret secret exists" \
    "kubectl get secret test-secret -n backup-test"

run_check "Secret has password field" \
    "kubectl get secret test-secret -n backup-test -o jsonpath='{.data.password}' | grep -q ."

run_check "Secret has api-key field" \
    "kubectl get secret test-secret -n backup-test -o jsonpath='{.data.api-key}' | grep -q ."

echo ""
echo -e "${BLUE}=== Functional Verification ===${NC}"
echo ""

run_check "Pods are accessible via service" \
    "kubectl run test-curl --image=curlimages/curl --rm -it --restart=Never -n backup-test -- curl -s -o /dev/null -w '%{http_code}' http://nginx-test | grep -q 200"

echo ""
echo "========================="
echo -e "${BLUE}Verification Results: $passed_checks/$total_checks checks passed${NC}"
echo "========================="
echo ""

if [ $passed_checks -eq $total_checks ]; then
    echo -e "${GREEN}🎉 All checks passed! Restore successful!${NC}"
    echo ""
    echo "Your restore verified:"
    echo "  ✓ Namespace restored"
    echo "  ✓ Deployment restored (3 replicas)"
    echo "  ✓ Pods running"
    echo "  ✓ Service restored and working"
    echo "  ✓ ConfigMap data intact"
    echo "  ✓ Secret data intact"
    echo "  ✓ Application functional"
    echo ""
    
    if [ -f "./before-disaster.txt" ]; then
        echo "Comparing with pre-disaster state..."
        echo ""
        echo "Before disaster:"
        cat ./before-disaster.txt
        echo ""
        echo "After restore:"
        kubectl get all -n backup-test
        echo ""
    fi
    
    exit 0
else
    echo -e "${RED}❌ Some checks failed. Restore may be incomplete.${NC}"
    echo ""
    echo "Debug steps:"
    echo "  1. Check if namespace exists: kubectl get namespace backup-test"
    echo "  2. Check resources: kubectl get all,cm,secret -n backup-test"
    echo "  3. Check pod logs: kubectl logs -n backup-test <pod-name>"
    echo "  4. Re-run restore if needed"
    exit 1
fi