#!/bin/bash
# Lab 04: Cluster Upgrade - Drain/Uncordon Simulation Script

set -e

echo "🔄 Lab 04: Node Drain/Uncordon Simulation"
echo "=========================================="
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if node name provided
if [ -z "$1" ]; then
    echo -e "${YELLOW}Usage: $0 <node-name>${NC}"
    echo ""
    echo "Available nodes:"
    kubectl get nodes --no-headers | awk '{print "  - " $1}'
    echo ""
    echo "Example:"
    echo "  $0 opscart-m02"
    exit 1
fi

NODE=$1

# Check if node exists
if ! kubectl get node $NODE &> /dev/null; then
    echo -e "${RED}Error: Node '$NODE' not found${NC}"
    echo ""
    echo "Available nodes:"
    kubectl get nodes
    exit 1
fi

echo -e "${BLUE}This simulates the worker node upgrade process${NC}"
echo ""
echo "Target node: $NODE"
echo ""

# Show pods on the node
echo -e "${BLUE}=== Step 1: Pods currently on $NODE ===${NC}"
echo ""
kubectl get pods -A -o wide --field-selector spec.nodeName=$NODE --no-headers | wc -l | awk '{print $1 " pods running on this node"}'
echo ""
kubectl get pods -A -o wide --field-selector spec.nodeName=$NODE

echo ""
echo -e "${YELLOW}Press Enter to drain the node (or Ctrl+C to cancel)${NC}"
read

echo ""
echo -e "${BLUE}=== Step 2: Draining node $NODE ===${NC}"
echo ""
echo "Command: kubectl drain $NODE --ignore-daemonsets --delete-emptydir-data"
echo ""

# Drain the node
kubectl drain $NODE --ignore-daemonsets --delete-emptydir-data

echo ""
echo -e "${GREEN}✓ Node drained successfully${NC}"
echo ""

# Show node status
echo -e "${BLUE}=== Step 3: Node Status ===${NC}"
echo ""
kubectl get node $NODE

echo ""
echo "Node is now:"
echo "  - SchedulingDisabled (cordoned)"
echo "  - Pods have been evicted"
echo "  - Only DaemonSet pods remain"
echo ""

# Show remaining pods
echo -e "${BLUE}=== Step 4: Remaining Pods on $NODE ===${NC}"
echo ""
kubectl get pods -A -o wide --field-selector spec.nodeName=$NODE

echo ""
echo -e "${YELLOW}In a real upgrade, you would now:${NC}"
echo "  1. SSH to the node"
echo "  2. Upgrade kubeadm"
echo "  3. Run: sudo kubeadm upgrade node"
echo "  4. Upgrade kubelet and kubectl"
echo "  5. Restart kubelet"
echo ""
echo -e "${YELLOW}Press Enter to uncordon the node${NC}"
read

echo ""
echo -e "${BLUE}=== Step 5: Uncordoning node $NODE ===${NC}"
echo ""
echo "Command: kubectl uncordon $NODE"
echo ""

# Uncordon the node
kubectl uncordon $NODE

echo ""
echo -e "${GREEN}✓ Node uncordoned successfully${NC}"
echo ""

# Show final node status
echo -e "${BLUE}=== Step 6: Final Node Status ===${NC}"
echo ""
kubectl get node $NODE

echo ""
echo "Node is now:"
echo "  - Ready and schedulable"
echo "  - Can accept new pods"
echo "  - Existing pods may reschedule back"
echo ""

echo "=========================================="
echo -e "${GREEN}Drain/Uncordon simulation complete!${NC}"
echo ""
echo "What you learned:"
echo "  ✓ How to safely drain a node"
echo "  ✓ Pods are evicted gracefully"
echo "  ✓ DaemonSet pods are not evicted"
echo "  ✓ How to uncordon after maintenance"
echo ""
echo "This is the process used during worker node upgrades!"