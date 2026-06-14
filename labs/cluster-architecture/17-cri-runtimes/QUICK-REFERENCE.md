# Lab 17: CRI Container Runtimes - Quick Reference

## Identify Runtime

```bash
# Runtime column in node list
kubectl get nodes -o wide

# Runtime per node
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.nodeInfo.containerRuntimeVersion}{"\n"}{end}'

# Full node info
kubectl describe node <name> | grep -i runtime
```

---

## crictl Commands

```bash
# List running containers
crictl ps

# List all containers (including stopped)
crictl ps -a

# List pod sandboxes
crictl pods

# List images
crictl images

# Pull image
crictl pull nginx:latest

# Container logs
crictl logs <container-id>

# Container details
crictl inspect <container-id>

# Image details
crictl inspecti <image>

# Remove image
crictl rmi <image-id>

# Stats
crictl stats
```

---

## Runtime Socket Locations

```bash
# containerd
/var/run/containerd/containerd.sock

# CRI-O
/var/run/crio/crio.sock

# Docker (legacy)
/var/run/docker.sock
```

---

## Set crictl Endpoint

```bash
# Environment variable
export CONTAINER_RUNTIME_ENDPOINT=unix:///var/run/containerd/containerd.sock

# Config file
cat > /etc/crictl.yaml << 'EOF'
runtime-endpoint: unix:///var/run/containerd/containerd.sock
image-endpoint: unix:///var/run/containerd/containerd.sock
timeout: 10
EOF
```

---

## Minikube Access

```bash
# SSH into specific node
minikube ssh                # control plane
minikube ssh -n opscart-m02 # worker node

# Run crictl remotely
minikube ssh -- "sudo crictl ps"
minikube ssh -n opscart-m02 -- "sudo crictl ps"
```

---

## Runtime Comparison

```
crictl    → CRI-compatible, works with containerd/CRI-O
docker    → Docker daemon only (legacy)
ctr       → Low-level containerd CLI
nerdctl   → Docker-compatible CLI for containerd
```

---

## Node Info Fields

```bash
kubectl get nodes -o custom-columns=\
"NAME:.metadata.name,\
RUNTIME:.status.nodeInfo.containerRuntimeVersion,\
KERNEL:.status.nodeInfo.kernelVersion,\
OS:.status.nodeInfo.osImage"
```

---

## Exam Scenarios

### Find runtime on node
```bash
kubectl get node worker1 \
  -o jsonpath='{.status.nodeInfo.containerRuntimeVersion}'
# containerd://1.7.2
```

### List containers on node
```bash
# SSH to node first, then:
crictl ps
crictl ps -a | grep <pod-name>
```

### Find container ID for pod
```bash
crictl ps | grep <container-name>
# Copy the ID from first column
```

---

## Time Budget (Exam)

- Identify runtime: **30 seconds**
- Use crictl: **2 minutes**
- **Total: ~3 minutes**