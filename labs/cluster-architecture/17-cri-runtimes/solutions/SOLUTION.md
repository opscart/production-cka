# Lab 17: CRI Container Runtimes - Solution Guide

## Run the Scripts
```bash
./scripts/setup.sh
./scripts/test.sh
./scripts/cleanup.sh
```

---

## Complete Manual Solution

### Step 1: Identify Runtime
```bash
# Quick check
kubectl get nodes -o wide
# CONTAINER-RUNTIME column: docker://24.0.7 (minikube) or containerd://1.7.x (kubeadm)

# Per node
kubectl get nodes -o \
  jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.nodeInfo.containerRuntimeVersion}{"\n"}{end}'
```

### Step 2: SSH and Use crictl
```bash
minikube ssh

# List running containers
sudo crictl ps

# List pod sandboxes
sudo crictl pods

# List images
sudo crictl images

# Get container details
CONTAINER_ID=$(sudo crictl ps | grep nginx | awk '{print $1}')
sudo crictl inspect $CONTAINER_ID | head -30

# View logs
sudo crictl logs $CONTAINER_ID

exit
```

### Step 3: Create Test Pod and Find via crictl
```bash
kubectl create namespace lab17-cri
kubectl run cri-test-pod --image=nginx -n lab17-cri
kubectl wait --for=condition=ready pod/cri-test-pod -n lab17-cri --timeout=60s

# Find which node
NODE=$(kubectl get pod cri-test-pod -n lab17-cri -o jsonpath='{.spec.nodeName}')

# See container via crictl
minikube ssh -n $NODE -- "sudo crictl ps | grep nginx"
```

### Step 4: Runtime Configuration
```bash
# kubelet config
minikube ssh "sudo cat /var/lib/kubelet/config.yaml | grep -i runtime"

# containerd config
minikube ssh "sudo cat /etc/containerd/config.toml 2>/dev/null | head -20"

# Runtime socket
minikube ssh "ls -la /var/run/containerd/containerd.sock 2>/dev/null || \
  ls -la /var/run/docker.sock 2>/dev/null"
```

---

## Key Differences: minikube vs kubeadm

```
Feature          │ Minikube              │ kubeadm
─────────────────┼───────────────────────┼──────────────────────
Default runtime  │ docker://XX.X.X       │ containerd://1.7.x
Runtime socket   │ /var/run/docker.sock  │ /var/run/containerd/
crictl available │ Yes                   │ Yes
docker available │ Yes (inside VM)       │ Usually not
```

---

## Key Takeaways

✅ CRI is a gRPC API between kubelet and container runtimes
✅ containerd is the default runtime for most production clusters
✅ Docker was removed as CRI in Kubernetes 1.24+
✅ `crictl` is the CLI for CRI-compatible runtimes
✅ Runtime info available via `kubectl get nodes -o wide`
✅ Runtime socket: `/var/run/containerd/containerd.sock`
✅ Use crictl when API server is down for debugging

---

**Completed Lab 17?** ✅

Move to **[Lab 18: Cluster Maintenance](../18-cluster-maintenance/)**