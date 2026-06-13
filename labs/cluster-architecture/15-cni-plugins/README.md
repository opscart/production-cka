# Lab 15: CNI Plugins

## Objective
Understand Container Network Interface (CNI) plugins, how pod networking works, and how to inspect and troubleshoot network configuration in Kubernetes clusters.

## CKA Exam Relevance
- **Domain:** Cluster Architecture, Installation & Configuration (25%)
- **Topic:** Understand CNI plugin configuration
- **Exam Weight:** Medium (30-40% of exams)
- **Typical Exam Time:** 5-7 minutes

## Time to Complete
40 minutes

## Prerequisites
- Completed Labs 01-14
- Basic networking knowledge (IP, CIDR, routing)

---

## What is CNI?

**CNI (Container Network Interface)** is a standard that defines how network plugins configure networking for containers.

```
Without CNI:                    With CNI:
────────────                    ──────────────────────────────
Containers can't                Every pod gets:
communicate                     - Unique IP address
                                - Network namespace
                                - Routes to other pods
                                - DNS resolution
```

**CNI is NOT built into Kubernetes** - you must install a CNI plugin after cluster setup. This is why `kubeadm init` says "You should install a pod network add-on."

---

## How CNI Works

```
┌─────────────────────────────────────────────────────────────┐
│                      Worker Node                            │
│                                                             │
│  kubelet creates pod                                        │
│       │                                                     │
│       ▼                                                     │
│  Calls CNI plugin ──► /etc/cni/net.d/                      │
│       │                                                     │
│       ▼                                                     │
│  CNI plugin:                                                │
│  1. Creates network namespace for pod                       │
│  2. Creates virtual ethernet (veth) pair                    │
│  3. Assigns IP from pod CIDR                                │
│  4. Sets up routes                                          │
│  5. Configures iptables rules                               │
│                                                             │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐  │
│  │   Pod A     │     │   Pod B     │     │   Pod C     │  │
│  │ 10.244.0.1  │────►│ 10.244.0.2  │────►│ 10.244.0.3  │  │
│  └─────────────┘     └─────────────┘     └─────────────┘  │
│         │                   │                   │          │
│         └───────────────────┴───────────────────┘          │
│                        cni0 bridge                         │
└─────────────────────────────────────────────────────────────┘
```

---

## Common CNI Plugins

```
Plugin      │ Features                          │ Use Case
────────────┼───────────────────────────────────┼──────────────────────
Calico      │ Network policies, BGP routing      │ Production, security-focused
Flannel     │ Simple overlay, easy setup         │ Development, simple setups
Weave       │ Mesh networking, encryption        │ Multi-cloud
Cilium      │ eBPF-based, advanced policies      │ Performance, observability
kindnet     │ Simple, built for kind/minikube    │ Local development
```

---

## Tasks

### Task 1: Identify CNI Plugin (5 min)

**Objective:** Find which CNI plugin is running.

```bash
# Check CNI plugin pods in kube-system
kubectl get pods -n kube-system | grep -E "calico|flannel|weave|cilium|kindnet"

# Check CNI configuration files (on node)
minikube ssh "ls /etc/cni/net.d/"

# View CNI config
minikube ssh "cat /etc/cni/net.d/*.conf* 2>/dev/null || cat /etc/cni/net.d/*.conflist 2>/dev/null"

# Check CNI binaries
minikube ssh "ls /opt/cni/bin/"
```

---

### Task 2: Inspect Pod Networking (10 min)

**Objective:** Understand how pods get IP addresses.

```bash
# Create namespace for lab
kubectl create namespace lab15-cni

# Create test pods on different nodes
cat > manifests/pod-node1.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: pod-node1
  namespace: lab15-cni
spec:
  nodeSelector:
    kubernetes.io/hostname: opscart
  containers:
  - name: net-test
    image: busybox
    command: ["sleep", "3600"]
EOF

cat > manifests/pod-node2.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: pod-node2
  namespace: lab15-cni
spec:
  nodeSelector:
    kubernetes.io/hostname: opscart-m02
  containers:
  - name: net-test
    image: busybox
    command: ["sleep", "3600"]
EOF

kubectl apply -f manifests/pod-node1.yaml
kubectl apply -f manifests/pod-node2.yaml

kubectl wait --for=condition=ready pod/pod-node1 \
  -n lab15-cni --timeout=60s
kubectl wait --for=condition=ready pod/pod-node2 \
  -n lab15-cni --timeout=60s

# Get pod IPs
kubectl get pods -n lab15-cni -o wide

# Check pod's network interface
kubectl exec pod-node1 -n lab15-cni -- ip addr
kubectl exec pod-node1 -n lab15-cni -- ip route
```

---

### Task 3: Test Pod-to-Pod Connectivity (10 min)

**Objective:** Verify pods can communicate across nodes.

```bash
# Get IP of pod-node2
POD2_IP=$(kubectl get pod pod-node2 -n lab15-cni \
  -o jsonpath='{.status.podIP}')
echo "Pod 2 IP: $POD2_IP"

# Ping pod-node2 from pod-node1 (cross-node!)
kubectl exec pod-node1 -n lab15-cni -- ping -c 3 $POD2_IP

# Test connectivity both ways
POD1_IP=$(kubectl get pod pod-node1 -n lab15-cni \
  -o jsonpath='{.status.podIP}')
kubectl exec pod-node2 -n lab15-cni -- ping -c 3 $POD1_IP

# Check DNS resolution
kubectl exec pod-node1 -n lab15-cni -- \
  nslookup kubernetes.default.svc.cluster.local
```

---

### Task 4: Inspect Node Network Configuration (10 min)

**Objective:** See how CNI configures node networking.

```bash
# Check pod CIDR assigned to each node
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.podCIDR}{"\n"}{end}'

# Check node network interfaces (on minikube)
minikube ssh "ip addr show"
minikube ssh "ip route show"

# View CNI configuration detail
minikube ssh "cat /etc/cni/net.d/10-kindnet.conflist 2>/dev/null || \
  cat /etc/cni/net.d/*.conf 2>/dev/null | head -30"

# Check which CNI binary is being used
minikube ssh "ls -la /opt/cni/bin/"
```

---

### Task 5: Network Policy (DNS and Services) (5 min)

**Objective:** Test service DNS resolution via CNI.

```bash
# Create a service
kubectl create deployment web-app \
  --image=nginx -n lab15-cni

kubectl expose deployment web-app \
  --port=80 -n lab15-cni

# Test DNS resolution from pod
kubectl exec pod-node1 -n lab15-cni -- \
  nslookup web-app.lab15-cni.svc.cluster.local

# Test HTTP connectivity via service
kubectl exec pod-node1 -n lab15-cni -- \
  wget -q -O- http://web-app.lab15-cni.svc.cluster.local | head -5
```

---

## Exam Tips

⏱️ **Time Management:**
- Identify CNI: 1 minute
- Check pod IPs: 1 minute
- Verify connectivity: 2 minutes
- **Total: ~4 minutes**

🎯 **Exam Question Patterns:**

> *"What CNI plugin is installed in this cluster?"*

> *"What is the pod CIDR range on node worker1?"*

> *"Why can't pods on different nodes communicate?"*
→ CNI plugin not installed or misconfigured

🔑 **Key Locations:**
```bash
/etc/cni/net.d/          # CNI configuration files
/opt/cni/bin/            # CNI binary plugins
```

🔑 **Key Commands:**
```bash
# Find CNI pods
kubectl get pods -n kube-system | grep -E "calico|flannel|weave|cilium|kindnet"

# Check pod CIDRs
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.podCIDR}{"\n"}{end}'

# Pod network info
kubectl get pods -o wide
kubectl exec <pod> -- ip addr
kubectl exec <pod> -- ip route
```

---

## Common Issues

### Pods stuck in Pending - no CNI

**Symptom:**
```
Events: Failed to create pod sandbox: ... network plugin is not ready: cni config uninitialized
```

**Solution:**
```bash
# Install CNI plugin (example: Calico)
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

# Or Flannel
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
```

### Pods can't communicate across nodes

**Debug:**
```bash
# Check CNI pods are running
kubectl get pods -n kube-system | grep -E "calico|flannel|weave|cilium"

# Check node pod CIDRs don't overlap
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.podCIDR}{"\n"}{end}'

# Check routes on node
ip route show
```

---

## Next Lab

Move to **[Lab 16: CSI Storage](../16-csi-storage/README.md)**

---

**Author:** Shamsher Khan | **Blog:** opscart.com | **Course:** Production CKA 2026