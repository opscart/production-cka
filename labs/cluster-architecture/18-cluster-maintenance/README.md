# Lab 18: Cluster Maintenance

## Objective
Master cluster maintenance operations: draining nodes, cordoning, upgrading components, managing node lifecycle, and performing cluster-level operations safely in production environments.

## CKA Exam Relevance
- **Domain:** Cluster Architecture, Installation & Configuration (25%)
- **Topic:** Implement etcd backup, cluster upgrades, node maintenance
- **Exam Weight:** High (appears in 70%+ of exams)
- **Typical Exam Time:** 8-12 minutes

## Time to Complete
50 minutes

## Prerequisites
- Completed Labs 01-17
- Understanding of cluster upgrades (Lab 04)
- Understanding of etcd backup (Lab 05)

---

## What is Cluster Maintenance?

Cluster maintenance covers all operations needed to keep a Kubernetes cluster healthy, updated, and operational:

```
Cluster Maintenance Areas:
──────────────────────────────────────────────────────────
Node Maintenance    → drain, cordon, uncordon nodes
Upgrades           → kubeadm upgrade plan/apply
OS Patching        → safely take nodes offline
etcd Operations    → backup, restore, member management
Certificate Mgmt   → check expiry, renew certificates
Resource Cleanup   → remove unused images, volumes
Log Management     → rotate logs, manage disk space
```

---

## Tasks

### Task 1: Node Cordon and Drain (15 min)

**Objective:** Safely take a node offline for maintenance.

```bash
kubectl create namespace lab18-maintenance

# Deploy workload across nodes
kubectl create deployment web-maintenance \
  --image=nginx \
  --replicas=4 \
  -n lab18-maintenance

kubectl wait --for=condition=available \
  deployment/web-maintenance \
  -n lab18-maintenance --timeout=60s

# Check pod distribution
kubectl get pods -n lab18-maintenance -o wide

# Pick a worker node to maintain
NODE="opscart-m02"

# Step 1: Cordon - mark node unschedulable (no new pods)
kubectl cordon $NODE
kubectl get nodes   # shows SchedulingDisabled

# Step 2: Drain - evict existing pods safely
kubectl drain $NODE \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --grace-period=30

# Check pods moved to other nodes
kubectl get pods -n lab18-maintenance -o wide

# Simulate maintenance work...
echo "Performing OS patching on $NODE..."
sleep 3

# Step 3: Uncordon - return node to service
kubectl uncordon $NODE
kubectl get nodes   # Ready again
```

---

### Task 2: Check Certificate Expiry (10 min)

**Objective:** Monitor TLS certificate health.

```bash
# Check certificate expiry (kubeadm clusters)
minikube ssh "sudo kubeadm certs check-expiration 2>/dev/null || \
  echo 'kubeadm not available on this node type'"

# Check API server certificate manually
minikube ssh "sudo openssl x509 -in /var/lib/minikube/certs/apiserver.crt \
  -noout -dates 2>/dev/null"

# Check etcd certificate
minikube ssh "sudo openssl x509 \
  -in /var/lib/minikube/certs/etcd/server.crt \
  -noout -dates 2>/dev/null"

# Check CA certificate
minikube ssh "sudo openssl x509 \
  -in /var/lib/minikube/certs/ca.crt \
  -noout -dates 2>/dev/null"

# List all certificates in PKI directory
minikube ssh "sudo ls -la /var/lib/minikube/certs/"
```

---

### Task 3: Node Resource Pressure (10 min)

**Objective:** Monitor and respond to node resource conditions.

```bash
# Check node conditions
kubectl describe nodes | grep -A 10 Conditions

# Check node capacity vs allocatable
kubectl get nodes -o custom-columns=\
"NAME:.metadata.name,\
CPU-CAP:.status.capacity.cpu,\
MEM-CAP:.status.capacity.memory,\
CPU-ALLOC:.status.allocatable.cpu,\
MEM-ALLOC:.status.allocatable.memory"

# Check resource usage per node
kubectl top nodes 2>/dev/null || echo "metrics-server not installed"

# Check what's consuming resources
kubectl top pods -A 2>/dev/null | sort -k3 -rn | head -10 || \
  echo "metrics-server not installed"

# Check node conditions for pressure
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{range .status.conditions[*]}{.type}{": "}{.status}{"\n"}{end}{"\n"}{end}'
```

---

### Task 4: Image and Volume Cleanup (5 min)

**Objective:** Reclaim disk space on nodes.

```bash
# Check disk usage on node
minikube ssh "df -h /"

# List unused images via crictl
minikube ssh "sudo crictl images"

# Remove unused images (careful in production!)
# minikube ssh "sudo crictl rmi --prune"

# Check dangling volumes
kubectl get pv | grep Released

# Clean up completed/failed pods
kubectl get pods -A | grep -E "Completed|Error|OOMKilled" | \
  awk '{print $1 " " $2}' | \
  while read ns pod; do
    echo "Would delete: $ns/$pod"
    # kubectl delete pod $pod -n $ns
  done

# Show namespace resource usage
kubectl get resourcequota -A
```

---

### Task 5: Cluster Component Health Check (10 min)

**Objective:** Comprehensive cluster health verification.

```bash
# Create health check script output
echo "=== Cluster Health Report ==="
echo ""

echo "--- Nodes ---"
kubectl get nodes -o wide

echo ""
echo "--- Control Plane Pods ---"
kubectl get pods -n kube-system | grep -E "etcd|apiserver|scheduler|controller"

echo ""
echo "--- System Pod Health ---"
kubectl get pods -n kube-system | grep -v Running | grep -v Completed || \
  echo "All system pods healthy!"

echo ""
echo "--- Node Conditions ---"
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{" Ready="}{range .status.conditions[?(@.type=="Ready")]}{.status}{end}{"\n"}{end}'

echo ""
echo "--- Certificate Info ---"
minikube ssh "sudo openssl x509 -in /var/lib/minikube/certs/apiserver.crt \
  -noout -subject -dates 2>/dev/null" || echo "Could not read cert"

echo ""
echo "--- Resource Quotas ---"
kubectl get resourcequota -A 2>/dev/null || echo "No quotas set"

echo ""
echo "--- PV Status ---"
kubectl get pv 2>/dev/null | grep -v Bound || echo "All PVs bound"

echo ""
echo "=== Health Check Complete ==="
```

---

## Maintenance Runbook (Production)

### Pre-Maintenance Checklist
```bash
# 1. Check cluster is healthy
kubectl get nodes
kubectl get pods -n kube-system

# 2. Check PodDisruptionBudgets
kubectl get pdb -A

# 3. Take etcd backup
./lab05-etcd-backup-restore/scripts/backup-etcd.sh

# 4. Document current state
kubectl get all -A > pre-maintenance-state.txt

# 5. Notify team (Slack/PagerDuty)
echo "Starting maintenance window..."
```

### Node Maintenance Sequence
```bash
# 1. Cordon
kubectl cordon <node>

# 2. Drain
kubectl drain <node> \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --grace-period=60 \
  --timeout=300s

# 3. Perform maintenance (OS update, etc.)
# ssh <node>
# sudo apt update && sudo apt upgrade -y
# sudo reboot

# 4. Wait for node to come back
kubectl wait --for=condition=Ready node/<node> --timeout=300s

# 5. Uncordon
kubectl uncordon <node>

# 6. Verify workloads rescheduled
kubectl get pods -o wide
```

---

## Exam Tips

⏱️ **Time Management:**
- Drain/cordon/uncordon: 3 minutes
- Check certificates: 2 minutes
- Health check: 2 minutes
- **Total: ~7 minutes**

🎯 **Exam Question Patterns:**

> *"Perform maintenance on node worker1 - drain it, then uncordon"*

> *"Check when the API server certificate expires"*

> *"Mark node worker2 as unschedulable without evicting pods"*
→ `kubectl cordon worker2` (cordon only, NOT drain)

🔑 **Key Commands:**
```bash
# Cordon (mark unschedulable, keep pods)
kubectl cordon <node>

# Drain (evict pods, mark unschedulable)
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data

# Uncordon (return to service)
kubectl uncordon <node>

# Check certificates (kubeadm)
kubeadm certs check-expiration

# Renew certificates (kubeadm)
kubeadm certs renew all
```

---

## ⚠️ Minikube-Specific Notes

### kubeadm not available
```bash
# kubeadm certs check-expiration doesn't work on minikube
# Use openssl directly instead:
minikube ssh "sudo openssl x509 -in /var/lib/minikube/certs/apiserver.crt -noout -dates"
```

### Drain on minikube
```bash
# DaemonSets can't be evicted normally
# Always use --ignore-daemonsets
kubectl drain opscart-m02 --ignore-daemonsets --delete-emptydir-data
```

---

## Next Domain

🎉 **Cluster Architecture domain complete! (18/18 labs)**

Move to **[Domain 2: Services & Networking](../../networking/01-service-types/README.md)**

---

**Author:** Shamsher Khan | **Blog:** opscart.com | **Course:** Production CKA 2026