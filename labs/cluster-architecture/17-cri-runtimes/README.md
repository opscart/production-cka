# Lab 17: CRI Container Runtimes

## Objective
Understand the Container Runtime Interface (CRI), identify and inspect container runtimes, and understand how Kubernetes interacts with container runtimes to run pods.

## CKA Exam Relevance
- **Domain:** Cluster Architecture, Installation & Configuration (25%)
- **Topic:** Understand CRI and container runtimes
- **Exam Weight:** Low-Medium (20-30% of exams)
- **Typical Exam Time:** 3-5 minutes

## Time to Complete
35 minutes

## Prerequisites
- Completed Labs 01-16
- Basic understanding of containers

---

## What is CRI?

**CRI (Container Runtime Interface)** is a plugin interface that lets kubelet use different container runtimes without recompiling Kubernetes.

```
Before CRI:                    After CRI:
───────────────────────        ──────────────────────────────
kubelet had Docker code        kubelet uses CRI gRPC API
built in - hard to change      Any CRI-compliant runtime works
Docker-only                    containerd, CRI-O, etc.
```

---

## CRI Architecture

```
kubelet
   │  CRI gRPC API
   ▼
Container Runtime (CRI-compliant):
   containerd  │  CRI-O  │  Docker (removed 1.24+)
        │
        ▼
   runc (OCI low-level runtime)
        │
        ▼
   Container (process in namespaces + cgroups)
```

---

## Common Runtimes

```
containerd  → Default in kubeadm, k3s, most clusters
CRI-O       → OpenShift, RHEL-based clusters
Docker      → Legacy, removed as CRI in Kubernetes 1.24+
gVisor      → Security sandboxing
Kata        → VM-level isolation
```

---

## Tasks

### Task 1: Identify Container Runtime (5 min)

```bash
# Check runtime in node info
kubectl get nodes -o wide
# CONTAINER-RUNTIME column shows runtime

# Get runtime version per node
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.nodeInfo.containerRuntimeVersion}{"\n"}{end}'

# Describe node
kubectl describe node opscart | grep -i runtime
```

---

### Task 2: Inspect Runtime on Node (10 min)

**crictl** is the CRI-compatible CLI tool (like docker but for CRI runtimes):

```bash
minikube ssh

# List running containers
sudo crictl ps

# List all containers (including stopped)
sudo crictl ps -a

# List pod sandboxes
sudo crictl pods

# List cached images
sudo crictl images

# Container details
sudo crictl inspect <container-id>

# Container logs
sudo crictl logs <container-id>

exit
```

---

### Task 3: Runtime Configuration (5 min)

```bash
# kubelet runtime config
minikube ssh "sudo cat /var/lib/kubelet/config.yaml | grep -i runtime"

# containerd config
minikube ssh "sudo cat /etc/containerd/config.toml 2>/dev/null | head -20"

# Runtime socket location
minikube ssh "ls -la /var/run/containerd/containerd.sock 2>/dev/null || \
  ls -la /var/run/crio/crio.sock 2>/dev/null || \
  ls -la /var/run/docker.sock 2>/dev/null"
```

---

### Task 4: Container Operations with crictl (10 min)

```bash
# Create test pod
kubectl create namespace lab17-cri
kubectl run cri-test-pod --image=nginx -n lab17-cri
kubectl wait --for=condition=ready pod/cri-test-pod -n lab17-cri --timeout=60s

# Find which node it's on
NODE=$(kubectl get pod cri-test-pod -n lab17-cri -o jsonpath='{.spec.nodeName}')
echo "Pod on node: $NODE"

# View container on node via crictl
minikube ssh -n $NODE -- "sudo crictl ps | grep nginx"

# Get container ID
minikube ssh -n $NODE -- "sudo crictl ps" | grep nginx | awk '{print $1}'
```

---

### Task 5: Image Management (5 min)

```bash
minikube ssh

# List images
sudo crictl images

# Pull image
sudo crictl pull busybox:latest

# Verify
sudo crictl images | grep busybox

# Image inspect
sudo crictl inspecti nginx:latest 2>/dev/null | head -20

exit
```

---

## crictl vs kubectl vs docker

```
kubectl   → Kubernetes API layer (pods, deployments, services)
crictl    → CRI runtime (containers, images at node level)
docker    → Docker daemon (legacy, not CRI)
ctr       → Low-level containerd CLI
```

**Use crictl when:**
- API server is down
- Debugging at container level
- Checking image cache on specific node
- Troubleshooting CRI issues

---

## ⚠️ Minikube-Specific Notes

Minikube uses **Docker** as its runtime by default:

```bash
# Runtime shows as docker://XX.X.X on minikube
kubectl get nodes -o wide | grep CONTAINER

# Both work on minikube:
minikube ssh "sudo docker ps | grep nginx"
minikube ssh "sudo crictl ps"
```

On kubeadm clusters:
```
containerd://1.7.x   ← typical production
```

---

## Exam Tips

🔑 **Key Commands:**
```bash
# Find runtime
kubectl get nodes -o wide
kubectl get node <name> -o jsonpath='{.status.nodeInfo.containerRuntimeVersion}'

# crictl on node
crictl ps              # running containers
crictl ps -a           # all containers
crictl pods            # pod sandboxes
crictl images          # cached images
crictl logs <id>       # container logs
crictl inspect <id>    # container details
```

⏱️ **Time Budget:** ~3-4 minutes

---

## Next Lab

Move to **[Lab 18: Cluster Maintenance](../18-cluster-maintenance/README.md)**

---

**Author:** Shamsher Khan | **Blog:** opscart.com | **Course:** Production CKA 2026