# Lab 09: High Availability Clusters

## Objective
Understand high availability (HA) cluster architecture, control plane redundancy, etcd quorum, and how to verify and maintain HA in production Kubernetes clusters.

## CKA Exam Relevance
- **Domain:** Cluster Architecture, Installation & Configuration (25%)
- **Topic:** Understand HA cluster design and control plane components
- **Exam Weight:** Medium (20-30% of exams)
- **Typical Exam Time:** 5-8 minutes

## Time to Complete
45 minutes

## Scenario
Your pharmaceutical company's Kubernetes cluster runs critical drug tracking and FDA compliance workloads. A **single control plane node failure cannot take down the cluster**. You need to understand how HA clusters are designed and verify their components.

---

## What is HA Kubernetes?

```
Single Control Plane (NOT HA):      HA Control Plane:
────────────────────────────────    ─────────────────────────────────────
┌─────────────────────────────┐     ┌──────────┐ ┌──────────┐ ┌──────────┐
│    control-plane-1          │     │  CP-1    │ │  CP-2    │ │  CP-3    │
│  ┌──────────────────────┐   │     │ API      │ │ API      │ │ API      │
│  │ kube-apiserver       │   │     │ Sched    │ │ Sched    │ │ Sched    │
│  │ kube-scheduler       │   │     │ CM       │ │ CM       │ │ CM       │
│  │ kube-controller-mgr  │   │     │ etcd     │ │ etcd     │ │ etcd     │
│  │ etcd                 │   │     └──────────┘ └──────────┘ └──────────┘
│  └──────────────────────┘   │          │             │             │
└─────────────────────────────┘          └─────────────┴─────────────┘
                                                  Load Balancer
If this fails → cluster is DOWN             If one fails → still running!
```

### HA Requirements

- **Minimum 3 control plane nodes** (etcd quorum requires odd number)
- **Load balancer** in front of API servers
- **etcd cluster** with quorum (needs (n/2)+1 nodes)
- **Worker nodes** unaffected by control plane failures

---

## etcd Quorum

```
etcd nodes  │  Quorum needed  │  Can tolerate
────────────┼─────────────────┼───────────────
     1      │        1        │   0 failures
     2      │        2        │   0 failures ← NOT HA!
     3      │        2        │   1 failure  ← Minimum HA
     5      │        3        │   2 failures ← Better
     7      │        4        │   3 failures ← Enterprise
```

**Rule:** Always use **odd numbers** for etcd!

---

## Lab Structure

```
09-high-availability/
├── README.md
├── QUICK-REFERENCE.md
├── scripts/
│   ├── setup.sh          # Create HA simulation manifests
│   ├── test.sh           # Verify HA components
│   └── cleanup.sh
└── solutions/
    └── SOLUTION.md
```

---

## Tasks

### Task 1: Inspect Control Plane Components (10 min)

**Objective:** Understand what runs on the control plane.

```bash
# List control plane pods
kubectl get pods -n kube-system

# Filter control plane components
kubectl get pods -n kube-system | grep -E "etcd|apiserver|scheduler|controller"

# On your minikube (single node):
# etcd-opscart
# kube-apiserver-opscart
# kube-controller-manager-opscart
# kube-scheduler-opscart
```

**Inspect each component:**

```bash
# API Server - handles all kubectl commands
kubectl describe pod kube-apiserver-opscart -n kube-system | head -30

# Scheduler - assigns pods to nodes
kubectl describe pod kube-scheduler-opscart -n kube-system | head -20

# Controller Manager - runs controllers (deployments, replicasets, etc.)
kubectl describe pod kube-controller-manager-opscart -n kube-system | head -20

# etcd - stores all cluster state
kubectl describe pod etcd-opscart -n kube-system | head -20
```

**Static Pod Manifests:**

```bash
# These pods are managed by kubelet directly (not API server)
minikube ssh "ls -la /etc/kubernetes/manifests/"

# You should see:
# etcd.yaml
# kube-apiserver.yaml
# kube-controller-manager.yaml
# kube-scheduler.yaml
```

---

### Task 2: Understand Leader Election (10 min)

**Objective:** Learn how HA clusters handle multiple control plane nodes.

**Scheduler and Controller Manager use leader election:**

```bash
# Check leader election lease for scheduler
kubectl get lease kube-scheduler -n kube-system -o yaml

# Check leader election for controller-manager
kubectl get lease kube-controller-manager -n kube-system -o yaml

# The holderIdentity shows which node is the leader
kubectl get lease -n kube-system
```

**How it works:**
- All scheduler instances run, but only **one is active**
- Leader is determined by acquiring a **lease lock**
- If leader fails, another takes over within seconds
- etcd does NOT use leader election (uses Raft consensus instead)

---

### Task 3: Verify Component Health (10 min)

**Objective:** Check health of all control plane components.

```bash
# Check component statuses
kubectl get componentstatuses
# OR (newer clusters)
kubectl get --raw='/readyz?verbose'

# Check API server health
kubectl get --raw='/healthz'
kubectl get --raw='/livez'
kubectl get --raw='/readyz'

# Check etcd health (via pod exec)
kubectl exec -n kube-system etcd-opscart -- \
  etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/var/lib/minikube/certs/etcd/ca.crt \
  --cert=/var/lib/minikube/certs/etcd/server.crt \
  --key=/var/lib/minikube/certs/etcd/server.key \
  endpoint health

# Check etcd cluster members
kubectl exec -n kube-system etcd-opscart -- \
  etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/var/lib/minikube/certs/etcd/ca.crt \
  --cert=/var/lib/minikube/certs/etcd/server.crt \
  --key=/var/lib/minikube/certs/etcd/server.key \
  member list
```

---

### Task 4: HA Design for Workloads (10 min)

**Objective:** Configure workloads to be HA-aware.

**Pod Disruption Budget (PDB) - prevent too many pods going down:**

```bash
# Create a PDB for web-app
kubectl create deployment web-app --image=nginx --replicas=3

cat > manifests/web-app-pdb.yaml << 'EOF'
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: web-app-pdb
spec:
  minAvailable: 2    # At least 2 pods must be running
  selector:
    matchLabels:
      app: web-app
EOF

kubectl apply -f manifests/web-app-pdb.yaml

# Verify PDB
kubectl get pdb
# NAME             MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS
# web-app-pdb   2               N/A               1
```

**Pod Anti-Affinity - spread pods across nodes:**

```bash
cat > manifests/web-app-ha.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app-ha
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web-app-ha
  template:
    metadata:
      labels:
        app: web-app-ha
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  app: web-app-ha
              topologyKey: kubernetes.io/hostname
      containers:
      - name: web-app
        image: nginx
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
EOF

kubectl apply -f manifests/web-app-ha.yaml

# Check which nodes pods are on
kubectl get pods -l app=web-app-ha -o wide
# Should be spread across different nodes
```

---

### Task 5: Simulate Component Recovery (5 min)

**Objective:** Understand how static pods restart automatically.

```bash
# View static pod manifest
minikube ssh "sudo cat /etc/kubernetes/manifests/kube-scheduler.yaml" | head -20

# Static pods restart automatically if they crash
# kubelet monitors /etc/kubernetes/manifests/
# If you delete a static pod, it restarts!

# Try deleting the scheduler pod
kubectl delete pod kube-scheduler-opscart -n kube-system

# Watch it come back
kubectl get pods -n kube-system -w | grep scheduler
# It restarts within seconds
```

---

## What HA Looks Like in Production (Your AKS Clusters)

**AKS HA Architecture:**
```
                    ┌─────────────────────┐
Users/Apps ──────── │   Azure Load         │
                    │   Balancer           │
                    └──────────┬──────────┘
                               │
            ┌──────────────────┼──────────────────┐
            ▼                  ▼                  ▼
    ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
    │ Control      │  │ Control      │  │ Control      │
    │ Plane 1      │  │ Plane 2      │  │ Plane 3      │
    │ (AKS managed)│  │ (AKS managed)│  │ (AKS managed)│
    └──────────────┘  └──────────────┘  └──────────────┘
            │                  │                  │
    ┌───────────────────────────────────────────────────┐
    │                  Worker Nodes                      │
    │  node-1    node-2    node-3    node-4    node-5   │
    └───────────────────────────────────────────────────┘
```

**In AKS:** Control plane is fully managed by Azure - you don't manage it!

---

## Exam Tips

⏱️ **Time Management:**
- Inspect components: 2 minutes
- Check health: 2 minutes
- Configure PDB: 2 minutes
- **Total: ~6 minutes**

🎯 **Exam Question Patterns:**

> *"Check the health of all control plane components"*

> *"Create a PodDisruptionBudget that ensures at least 2 replicas are available"*

> *"How many etcd nodes are needed to tolerate 2 failures?"* → **5 nodes**

---

## Next Lab

Move to **[Lab 10: Cluster Components Deep Dive](../10-cluster-components/README.md)**

---

**Author:** Shamsher Khan | **Blog:** opscart.com | **Course:** Production CKA 2026
