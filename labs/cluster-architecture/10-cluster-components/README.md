# Lab 10: Cluster Components Deep Dive

## Objective
Deeply understand each Kubernetes cluster component, its role, configuration flags, and how components interact. Learn to inspect, troubleshoot, and verify component health.

## CKA Exam Relevance
- **Domain:** Cluster Architecture, Installation & Configuration (25%)
- **Topic:** Understand Kubernetes cluster components
- **Exam Weight:** High (component troubleshooting appears frequently)
- **Typical Exam Time:** 8-10 minutes

## Time to Complete
45 minutes

## Scenario
A junior engineer asks you: "Why did all our pods stop scheduling after we restarted that node?" Understanding components deeply helps you immediately answer: the **kube-scheduler** is down, likely because its static pod manifest was corrupted. This lab builds that deep knowledge.

---

## Kubernetes Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                     Control Plane Node                           │
│                                                                  │
│  ┌────────────────┐  ┌─────────────────┐  ┌──────────────────┐  │
│  │ kube-apiserver │  │  kube-scheduler │  │kube-controller-  │  │
│  │                │  │                 │  │manager           │  │
│  │ - REST API     │  │ - Watch unbound │  │ - Node controller│  │
│  │ - Auth/AuthZ   │  │   pods          │  │ - RS controller  │  │
│  │ - Admission    │  │ - Assign to     │  │ - Deploy ctrl    │  │
│  │ - Validation   │  │   best node     │  │ - Job controller │  │
│  └───────┬────────┘  └────────┬────────┘  └────────┬─────────┘  │
│          │                    │                    │             │
│          └────────────────────┴────────────────────┘             │
│                               │                                  │
│                    ┌──────────▼──────────┐                       │
│                    │        etcd         │                       │
│                    │  - All cluster state│                       │
│                    │  - Key-value store  │                       │
│                    │  - Source of truth  │                       │
│                    └─────────────────────┘                       │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                       Worker Node                                │
│                                                                  │
│  ┌────────────────┐  ┌─────────────────┐  ┌──────────────────┐  │
│  │    kubelet     │  │   kube-proxy    │  │Container Runtime │  │
│  │                │  │                 │  │                  │  │
│  │ - Registers    │  │ - iptables/IPVS │  │ - containerd     │  │
│  │   node         │  │ - Service       │  │ - CRI-O          │  │
│  │ - Runs pods    │  │   networking    │  │ - Docker         │  │
│  │ - Health checks│  │ - Load balances │  │                  │  │
│  └────────────────┘  └─────────────────┘  └──────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

---

## Tasks

### Task 1: kube-apiserver Deep Dive (10 min)

**Objective:** Understand API server configuration and function.

```bash
# Get API server pod details
kubectl describe pod kube-apiserver-opscart -n kube-system

# Key flags to note:
# --advertise-address        - IP for clients to reach API server
# --etcd-servers             - Where etcd is running
# --service-cluster-ip-range - IP range for services
# --cluster-cidr             - IP range for pods
# --authorization-mode       - Node,RBAC
# --enable-admission-plugins - What admission controllers are active
```

**View API server manifest:**
```bash
minikube ssh "sudo cat /etc/kubernetes/manifests/kube-apiserver.yaml"
```

**Test API server directly:**
```bash
# Get API versions
kubectl api-versions

# Get API resources
kubectl api-resources

# Get raw API response
kubectl get --raw='/api/v1/namespaces' | python3 -m json.tool | head -30
```

---

### Task 2: kube-scheduler Deep Dive (8 min)

**Objective:** Understand how pods get scheduled to nodes.

```bash
# View scheduler details
kubectl describe pod kube-scheduler-opscart -n kube-system

# Key flags:
# --leader-elect    - Enable HA leader election
# --config          - Scheduler profile configuration
```

**How scheduling works:**
1. Pod created (Pending state)
2. Scheduler watches for unbound pods
3. **Filtering:** Remove nodes that can't run the pod
4. **Scoring:** Rank remaining nodes
5. **Binding:** Assign pod to best node

**Watch scheduling in action:**
```bash
# Create a pod and watch scheduling
kubectl run test-schedule --image=nginx

# Watch the events
kubectl describe pod test-schedule | grep -A 5 Events

# Clean up
kubectl delete pod test-schedule
```

**Scheduling factors:**
- Resource requests (cpu/memory)
- Node selectors and affinity
- Taints and tolerations
- Pod affinity/anti-affinity
- Available resources on nodes

---

### Task 3: kube-controller-manager Deep Dive (8 min)

**Objective:** Understand what controllers do.

```bash
# View controller manager details
kubectl describe pod kube-controller-manager-opscart -n kube-system

# Key flags:
# --leader-elect          - HA leader election
# --node-monitor-period   - How often to check node health
# --node-eviction-rate    - Rate to evict pods from unhealthy nodes
# --controllers           - List of active controllers
```

**Controllers included:**
```bash
# Test controllers by creating resources
# 1. Deployment controller
kubectl create deployment test-ctrl --image=nginx --replicas=3
kubectl get replicaset  # ReplicaSet automatically created

# 2. Node controller - manages node status
kubectl get nodes -o wide

# 3. Job controller
kubectl create job test-job --image=busybox -- echo "hello"
kubectl get pods | grep test-job
kubectl delete job test-job

# Clean up
kubectl delete deployment test-ctrl
```

---

### Task 4: kubelet Deep Dive (8 min)

**Objective:** Understand kubelet's role on worker nodes.

```bash
# SSH into a node
minikube ssh

# Check kubelet status
sudo systemctl status kubelet

# View kubelet configuration
sudo cat /var/lib/kubelet/config.yaml

# Check kubelet logs
sudo journalctl -u kubelet -n 50

# Exit
exit
```

**Key kubelet responsibilities:**
- Register node with API server
- Watch for pod specs assigned to this node
- Pull container images
- Start/stop containers
- Report node and pod status
- Manage static pods (reads /etc/kubernetes/manifests/)
- Health checks (liveness/readiness probes)

**If kubelet stops:**
```
- Node goes NotReady
- Pods can't start on this node
- Scheduler stops assigning pods here
- Controller evicts existing pods
```

---

### Task 5: kube-proxy Deep Dive (6 min)

**Objective:** Understand service networking.

```bash
# View kube-proxy daemonset
kubectl get daemonset kube-proxy -n kube-system

# View kube-proxy pods (one per node)
kubectl get pods -n kube-system -l k8s-app=kube-proxy -o wide

# Check kube-proxy config
kubectl describe configmap kube-proxy -n kube-system

# View iptables rules created by kube-proxy
minikube ssh "sudo iptables -L -n | grep KUBE | head -20"
```

**How kube-proxy works:**
1. Watches Services and Endpoints
2. Creates iptables/IPVS rules on every node
3. Rules route traffic to correct pods
4. ClusterIP → actual pod IPs

---

### Task 6: etcd Deep Dive (5 min)

**Objective:** Understand etcd's role and explore stored data.

```bash
# etcd stores everything as /registry/resource-type/namespace/name

# List all keys in etcd
kubectl exec -n kube-system etcd-opscart -- \
  etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/var/lib/minikube/certs/etcd/ca.crt \
  --cert=/var/lib/minikube/certs/etcd/server.crt \
  --key=/var/lib/minikube/certs/etcd/server.key \
  get / --prefix --keys-only | head -30

# Get a specific resource from etcd
kubectl exec -n kube-system etcd-opscart -- \
  etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/var/lib/minikube/certs/etcd/ca.crt \
  --cert=/var/lib/minikube/certs/etcd/server.crt \
  --key=/var/lib/minikube/certs/etcd/server.key \
  get /registry/namespaces/default --print-value-only
```

---

## Component Failure Impact

```
Component Failed      │ What Breaks
──────────────────────┼──────────────────────────────────────────────
kube-apiserver        │ Everything! kubectl stops working, no new pods
kube-scheduler        │ New pods stuck in Pending (existing pods OK)
controller-manager    │ Deployments don't self-heal, no new ReplicaSets
etcd                  │ Everything! Cluster state lost/inaccessible
kubelet (worker)      │ That node goes NotReady, pods evicted
kube-proxy (worker)   │ Service networking breaks on that node
```

---

## Exam Tips

⏱️ **Time Management:**
- Inspect components: 3 minutes
- Verify health: 2 minutes
- Check logs: 2 minutes
- **Total: ~7 minutes**

🎯 **Exam Question Patterns:**

> *"The scheduler is not running. Fix it."*
→ Check `/etc/kubernetes/manifests/kube-scheduler.yaml`

> *"Pods are stuck in Pending. What component is responsible?"*
→ kube-scheduler

> *"What port does the API server listen on?"*
→ 6443

---

## Next Lab

Move to **[Lab 11: API Server Authentication](../11-api-server-auth/README.md)**

---

**Author:** Shamsher Khan | **Blog:** opscart.com | **Course:** Production CKA 2026
