# Lab 03: kubeadm Installation Quick Reference

## Complete Installation Flow (Fresh VMs)

### Step 1: Prerequisites (All Nodes - 5 min)

```bash
# Disable swap
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Load kernel modules
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

# Configure sysctl
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system

# Install containerd
sudo apt-get update
sudo apt-get install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

# Install kubeadm, kubelet, kubectl
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | \
    sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /' | \
    sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

---

### Step 2: Initialize Control Plane (Master Node - 3 min)

```bash
# Initialize cluster
sudo kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address=<MASTER_IP>

# Configure kubectl
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Verify control plane
kubectl get nodes
kubectl get pods -n kube-system
```

---

### Step 3: Install CNI Plugin (Master Node - 1 min)

```bash
# Option 1: Calico (recommended for production)
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

# Option 2: Flannel (simple, good for learning)
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# Option 3: Weave Net
kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml

# Verify CNI
kubectl get pods -n kube-system | grep -E 'calico|flannel|weave'
```

---

### Step 4: Join Worker Nodes (Each Worker - 2 min)

```bash
# On master, get join command
kubeadm token create --print-join-command

# On each worker, run the output (looks like):
sudo kubeadm join <MASTER_IP>:6443 \
  --token <TOKEN> \
  --discovery-token-ca-cert-hash sha256:<HASH>

# Verify on master
kubectl get nodes
```

---

## kubeadm Command Reference

### Initialization

```bash
# Basic init
sudo kubeadm init

# With custom pod network
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

# With custom Kubernetes version
sudo kubeadm init --kubernetes-version=v1.34.0

# With config file
sudo kubeadm init --config=kubeadm-config.yaml

# Dry run (check without applying)
sudo kubeadm init --dry-run
```

### Token Management

```bash
# List tokens
kubeadm token list

# Create new token
kubeadm token create

# Create token with TTL
kubeadm token create --ttl 2h

# Generate join command
kubeadm token create --print-join-command

# Delete token
kubeadm token delete <token>
```

### Certificate Management

```bash
# Check certificate expiration
kubeadm certs check-expiration

# Renew all certificates
sudo kubeadm certs renew all

# Renew specific certificate
sudo kubeadm certs renew apiserver

# Generate new certificate
sudo kubeadm init phase certs all
```

### Cluster Management

```bash
# Reset node (remove from cluster)
sudo kubeadm reset

# Upgrade plan
sudo kubeadm upgrade plan

# Upgrade cluster
sudo kubeadm upgrade apply v1.34.1

# View cluster config
kubectl -n kube-system get cm kubeadm-config -o yaml
```

---

## Control Plane Components

### Static Pod Locations

```bash
# Manifest directory
/etc/kubernetes/manifests/
├── etcd.yaml
├── kube-apiserver.yaml
├── kube-controller-manager.yaml
└── kube-scheduler.yaml

# Certificates
/etc/kubernetes/pki/
├── apiserver.crt
├── apiserver.key
├── ca.crt
├── ca.key
├── etcd/
│   ├── ca.crt
│   └── ca.key
└── ...

# Kubeconfig files
/etc/kubernetes/
├── admin.conf
├── controller-manager.conf
├── kubelet.conf
└── scheduler.conf
```

### Component Ports

```
API Server:          6443  (HTTPS)
etcd:                2379  (client), 2380 (peer)
Scheduler:           10259 (HTTPS)
Controller Manager:  10257 (HTTPS)
kubelet:             10250 (HTTPS)
kube-proxy:          10256 (metrics)
```

---

## Verification Commands

```bash
# Check cluster info
kubectl cluster-info

# Check nodes
kubectl get nodes -o wide

# Check control plane pods
kubectl get pods -n kube-system

# Check component health
kubectl get --raw='/healthz?verbose'

# Check component status (deprecated but useful)
kubectl get componentstatuses

# View logs
kubectl logs -n kube-system <pod-name>

# Check kubelet on node
sudo systemctl status kubelet
sudo journalctl -u kubelet -f
```

---

## Troubleshooting

### kubeadm init Fails

```bash
# Check prerequisites
kubeadm init phase preflight

# Check ports
sudo netstat -tulpn | grep -E '6443|2379|2380|10250'

# Check swap
free -h

# Check container runtime
sudo systemctl status containerd

# View detailed logs
sudo journalctl -xeu kubelet
```

### Node Not Ready

```bash
# Check node conditions
kubectl describe node <node-name>

# Check kubelet
sudo systemctl status kubelet
sudo journalctl -u kubelet -n 50

# Check CNI
kubectl get pods -n kube-system -o wide

# Check network
ip addr
ip route
```

### Pods Not Starting

```bash
# Check CNI installation
kubectl get pods -n kube-system | grep -E 'calico|flannel|weave'

# Check pod events
kubectl describe pod <pod-name>

# Check logs
kubectl logs <pod-name>

# Check node resources
kubectl top nodes
kubectl describe node <node-name>
```

---

## Common Exam Scenarios

### Scenario 1: Fresh Cluster Install

```bash
# On master
sudo kubeadm init --pod-network-cidr=10.244.0.0/16
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl apply -f <cni-plugin-url>

# Get join command
kubeadm token create --print-join-command

# On workers (run output from above)
sudo kubeadm join ...

# Verify
kubectl get nodes
```

### Scenario 2: Add Worker Node

```bash
# On master
kubeadm token create --print-join-command

# On new worker
# First: Install prerequisites (containerd, kubeadm, kubelet)
# Then: Run join command
sudo kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>

# Verify on master
kubectl get nodes
```

### Scenario 3: Certificate Renewal

```bash
# Check expiration
kubeadm certs check-expiration

# Renew all
sudo kubeadm certs renew all

# Restart kubelet
sudo systemctl restart kubelet

# Verify
kubectl get nodes
```

### Scenario 4: Reset and Reinstall

```bash
# On all nodes
sudo kubeadm reset -f
sudo rm -rf /etc/kubernetes/
sudo rm -rf /var/lib/etcd/
sudo rm -rf ~/.kube/

# Then start fresh with kubeadm init
```

---

## Production Best Practices

### 1. HA Control Plane

```bash
# Use 3 or 5 control plane nodes (odd number for quorum)
# Use external load balancer for API server
# Consider external etcd cluster

sudo kubeadm init \
  --control-plane-endpoint="loadbalancer.example.com:6443" \
  --upload-certs
```

### 2. Resource Requirements

```
Minimum per node:
- 2 CPU cores
- 2 GB RAM
- 20 GB disk

Recommended:
- 4+ CPU cores
- 8+ GB RAM
- 100+ GB disk
```

### 3. Network Requirements

```
Pod network:     10.244.0.0/16 (or similar)
Service network: 10.96.0.0/12 (default)
DNS:             10.96.0.10 (default)
```

### 4. Security Hardening

```bash
# Restrict API server access
--authorization-mode=Node,RBAC

# Enable audit logging
--audit-log-path=/var/log/kubernetes/audit.log
--audit-policy-file=/etc/kubernetes/audit-policy.yaml

# Rotate certificates regularly
kubeadm certs renew all

# Use encryption at rest
--encryption-provider-config=/etc/kubernetes/encryption-config.yaml
```

---

## Exam Tips

✅ **Must Know:**
- kubeadm init command and flags
- How to configure kubectl after init
- CNI installation (at least one plugin)
- kubeadm join process
- Certificate management basics

✅ **Practice:**
- Complete cluster setup in < 10 minutes
- Troubleshoot failed init
- Add worker nodes
- Check certificate expiration

✅ **Documentation:**
- Bookmark: kubernetes.io/docs/setup/production-environment/tools/kubeadm/
- Know how to search for CNI plugin URLs
- Understand kubeadm config structure

---

## Quick Cheat Sheet

```bash
# Install cluster
sudo kubeadm init --pod-network-cidr=10.244.0.0/16
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
kubectl apply -f <cni-yaml>

# Join node
kubeadm token create --print-join-command  # On master
sudo kubeadm join ...                      # On worker

# Verify
kubectl get nodes
kubectl get pods -A

# Troubleshoot
kubectl describe node <name>
sudo journalctl -u kubelet -f
kubectl get --raw='/healthz?verbose'
```