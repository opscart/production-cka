# Lab 03: kubeadm Cluster Installation - Solution Guide

## Complete Fresh Installation (Step-by-Step)

This solution shows the complete process on fresh Ubuntu 22.04 VMs.

---

## Environment Setup

**Assuming 3 VMs:**
- `control-plane`: 192.168.1.10 (2 CPU, 4GB RAM)
- `worker-1`: 192.168.1.11 (2 CPU, 4GB RAM)
- `worker-2`: 192.168.1.12 (2 CPU, 4GB RAM)

---

## Part 1: Prerequisites (All 3 Nodes - 10 min each)

Run these on **ALL nodes** (control-plane, worker-1, worker-2):

### Step 1.1: Disable Swap

```bash
# Disable swap immediately
sudo swapoff -a

# Disable swap permanently
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Verify
free -h
# Swap line should show 0B
```

**Why:** Kubernetes requires swap to be disabled for proper pod scheduling and resource management.

---

### Step 1.2: Load Required Kernel Modules

```bash
# Create config file
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

# Load modules immediately
sudo modprobe overlay
sudo modprobe br_netfilter

# Verify
lsmod | grep br_netfilter
lsmod | grep overlay
```

**Why:** 
- `overlay`: Required for container storage
- `br_netfilter`: Enables bridge network filtering for pod networking

---

### Step 1.3: Configure sysctl Parameters

```bash
# Create sysctl config
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply settings
sudo sysctl --system

# Verify
sysctl net.bridge.bridge-nf-call-iptables
sysctl net.ipv4.ip_forward
```

**Why:** Enables IP forwarding and bridge filtering for Kubernetes networking.

---

### Step 1.4: Install Container Runtime (containerd)

```bash
# Update package list
sudo apt-get update

# Install containerd
sudo apt-get install -y containerd

# Create containerd config directory
sudo mkdir -p /etc/containerd

# Generate default config
containerd config default | sudo tee /etc/containerd/config.toml

# Edit config to use systemd cgroup driver (important!)
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# Restart containerd
sudo systemctl restart containerd
sudo systemctl enable containerd

# Verify
sudo systemctl status containerd
```

**Why:** Kubernetes needs a container runtime to run containers. Containerd is the recommended choice.

---

### Step 1.5: Install kubeadm, kubelet, kubectl

```bash
# Install prerequisites
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

# Add Kubernetes GPG key
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | \
    sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Add Kubernetes repository
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /' | \
    sudo tee /etc/apt/sources.list.d/kubernetes.list

# Update package list
sudo apt-get update

# Install Kubernetes components
sudo apt-get install -y kubelet kubeadm kubectl

# Prevent automatic updates
sudo apt-mark hold kubelet kubeadm kubectl

# Verify installation
kubeadm version
kubelet --version
kubectl version --client
```

**Why:**
- `kubelet`: Agent that runs on each node
- `kubeadm`: Tool to bootstrap the cluster
- `kubectl`: CLI to manage the cluster

---

## Part 2: Initialize Control Plane (control-plane node only - 5 min)

Run these **ONLY on control-plane node**:

### Step 2.1: Initialize Cluster

```bash
# Initialize with pod network CIDR
sudo kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address=192.168.1.10 \
  --kubernetes-version=v1.34.0

# Expected output:
# ...
# Your Kubernetes control-plane has initialized successfully!
# ...
# To start using your cluster, you need to run the following as a regular user:
#
#   mkdir -p $HOME/.kube
#   sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
#   sudo chown $(id -u):$(id -g) $HOME/.kube/config
# ...
# Then you can join any number of worker nodes by running the following on each as root:
#
# kubeadm join 192.168.1.10:6443 --token <token> \
#     --discovery-token-ca-cert-hash sha256:<hash>
```

**Save the kubeadm join command!** You'll need it to join worker nodes.

---

### Step 2.2: Configure kubectl

```bash
# Create kube config directory
mkdir -p $HOME/.kube

# Copy admin config
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config

# Fix ownership
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Verify
kubectl cluster-info
kubectl get nodes

# Expected output:
# NAME            STATUS     ROLES           AGE   VERSION
# control-plane   NotReady   control-plane   1m    v1.34.0
```

**Note:** Node is `NotReady` because CNI is not installed yet.

---

### Step 2.3: Inspect What kubeadm Created

```bash
# View static pod manifests
sudo ls -la /etc/kubernetes/manifests/

# You should see:
# etcd.yaml
# kube-apiserver.yaml
# kube-controller-manager.yaml
# kube-scheduler.yaml

# View certificates
sudo ls -la /etc/kubernetes/pki/

# View kubeconfig files
sudo ls -la /etc/kubernetes/

# View control plane pods
kubectl get pods -n kube-system

# Expected:
# etcd-control-plane                      1/1     Running
# kube-apiserver-control-plane            1/1     Running
# kube-controller-manager-control-plane   1/1     Running
# kube-scheduler-control-plane            1/1     Running
# kube-proxy-xxxxx                        1/1     Running
# coredns-xxxxx                           0/1     Pending (waiting for CNI)
```

---

## Part 3: Install CNI Plugin (control-plane node - 2 min)

Still on **control-plane node**:

### Option 1: Install Calico (Recommended)

```bash
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

# Wait for calico pods to start
kubectl get pods -n kube-system -w

# Press Ctrl+C when all are running
```

### Option 2: Install Flannel (Alternative)

```bash
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# Verify
kubectl get pods -n kube-system | grep flannel
```

### Verify Node is Ready

```bash
kubectl get nodes

# Expected:
# NAME            STATUS   ROLES           AGE   VERSION
# control-plane   Ready    control-plane   5m    v1.34.0
```

---

## Part 4: Join Worker Nodes (worker-1 and worker-2 - 3 min each)

Run on **each worker node**:

### Step 4.1: Get Join Command

On **control-plane**, if you lost the join command:

```bash
# Generate new join command
kubeadm token create --print-join-command

# Output (example):
# kubeadm join 192.168.1.10:6443 --token abcdef.0123456789abcdef \
#     --discovery-token-ca-cert-hash sha256:1234567890abcdef...
```

### Step 4.2: Join Worker Nodes

On **worker-1** and **worker-2**, run the join command:

```bash
sudo kubeadm join 192.168.1.10:6443 \
    --token abcdef.0123456789abcdef \
    --discovery-token-ca-cert-hash sha256:1234567890abcdef...

# Expected output:
# ...
# This node has joined the cluster:
# * Certificate signing request was sent to apiserver and a response was received.
# * The Kubelet was informed of the new secure connection details.
# ...
```

### Step 4.3: Verify on Control Plane

On **control-plane**:

```bash
kubectl get nodes

# Expected:
# NAME            STATUS   ROLES           AGE   VERSION
# control-plane   Ready    control-plane   10m   v1.34.0
# worker-1        Ready    <none>          2m    v1.34.0
# worker-2        Ready    <none>          1m    v1.34.0

# View all pods
kubectl get pods -A -o wide
```

---

## Part 5: Verify Cluster (control-plane node - 5 min)

### Test 1: Deploy Sample Application

```bash
# Create deployment
kubectl create deployment nginx --image=nginx --replicas=3

# Wait for pods
kubectl get pods -o wide

# Verify pods are on different nodes
kubectl get pods -o wide | grep nginx

# Expected: Pods distributed across nodes
```

### Test 2: Expose Service

```bash
# Create service
kubectl expose deployment nginx --port=80 --type=NodePort

# Get service
kubectl get svc nginx

# Expected:
# NAME    TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
# nginx   NodePort   10.96.123.456   <none>        80:32000/TCP   5s

# Test from control plane
curl http://192.168.1.10:32000  # Should return nginx welcome page
```

### Test 3: DNS Resolution

```bash
# Test DNS
kubectl run test-dns --image=busybox --rm -it --restart=Never -- nslookup kubernetes.default

# Expected:
# Server:    10.96.0.10
# Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local
#
# Name:      kubernetes.default
# Address 1: 10.96.0.1 kubernetes.default.svc.cluster.local
```

### Test 4: Check Component Health

```bash
# API server health
kubectl get --raw='/healthz?verbose'

# Component status
kubectl get componentstatuses  # Deprecated but useful

# View all system pods
kubectl get pods -n kube-system
```

---

## Troubleshooting Common Issues

### Issue 1: kubeadm init Fails - Port Already in Use

**Error:**
```
[ERROR Port-6443]: Port 6443 is in use
```

**Solution:**
```bash
# Find what's using the port
sudo netstat -tulpn | grep 6443

# Kill the process or use different port
sudo kubeadm init --apiserver-bind-port=6444
```

---

### Issue 2: Node Stays NotReady

**Debug:**
```bash
# Check node conditions
kubectl describe node <node-name>

# Check kubelet logs
sudo journalctl -u kubelet -n 50

# Common causes:
# 1. CNI not installed
# 2. CNI misconfigured
# 3. Network issue
```

**Solution:**
```bash
# Install/reinstall CNI
kubectl apply -f <cni-plugin-url>

# Restart kubelet
sudo systemctl restart kubelet
```

---

### Issue 3: Pods Stuck in ContainerCreating

**Debug:**
```bash
kubectl describe pod <pod-name>

# Look for:
# - CNI-related errors
# - Image pull errors
# - Volume mount errors
```

**Solution:**
```bash
# Check CNI pods
kubectl get pods -n kube-system | grep -E 'calico|flannel'

# If CNI pods not running, reinstall CNI
```

---

### Issue 4: Certificate Errors After Some Time

**Error:**
```
Unable to connect to the server: x509: certificate has expired
```

**Solution:**
```bash
# Check certificate expiration
kubeadm certs check-expiration

# Renew certificates
sudo kubeadm certs renew all

# Restart kubelet
sudo systemctl restart kubelet

# Update kubeconfig
sudo cp /etc/kubernetes/admin.conf ~/.kube/config
```

---

## Exam Simulation Scenario

**Question:**
> Install a 3-node Kubernetes cluster using kubeadm. The control plane should be on node `master1` (IP: 10.0.0.10). Worker nodes are `worker1` (10.0.0.11) and `worker2` (10.0.0.12). Use Calico as the CNI plugin with pod network CIDR 10.244.0.0/16.

**Solution (12 minutes):**

```bash
# === On ALL nodes (master1, worker1, worker2) - 3 min ===
sudo swapoff -a
sudo modprobe overlay br_netfilter
sudo apt-get update && sudo apt-get install -y containerd kubeadm kubelet kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# === On master1 only - 3 min ===
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=10.0.0.10
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

# === Generate join command - 1 min ===
kubeadm token create --print-join-command

# === On worker1 and worker2 - 2 min each ===
sudo kubeadm join 10.0.0.10:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>

# === Verify on master1 - 1 min ===
kubectl get nodes
# All nodes should be Ready

kubectl get pods -A
# All pods should be Running
```

---

## What You've Learned

**kubeadm init** - Bootstraps control plane
**Static pods** - How control plane components run
**Certificates** - PKI infrastructure kubeadm creates
**CNI plugins** - Pod networking requirements
**kubeadm join** - How worker nodes join
**Verification** - How to check cluster health

**Completed Lab 03?** ✅

Move to **[Lab 04: Cluster Upgrade](../04-cluster-upgrade/)**