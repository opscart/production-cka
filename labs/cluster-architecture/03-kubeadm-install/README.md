# Lab 03: kubeadm Cluster Installation from Scratch

## Objective
Master Kubernetes cluster installation using kubeadm, understand cluster components, and prepare for cluster lifecycle management questions that make up a significant portion of the CKA exam.

## CKA Exam Relevance
- **Domain:** Cluster Architecture, Installation & Configuration (25%)
- **Topic:** Create and manage Kubernetes clusters using kubeadm
- **Exam Weight:** Very High (appears in 90%+ of exams)
- **Typical Exam Time:** 10-15 minutes

## Time to Complete
60 minutes

## Scenario
You're the platform engineer at a pharmaceutical company. Management wants to move from managed AKS to self-hosted Kubernetes for:
- Full control over cluster configuration
- Custom networking requirements (regulatory compliance)
- Cost optimization (spot instances)
- Multi-cloud strategy (vendor independence)

Your task: Build a production-ready 3-node cluster from scratch using kubeadm.

## Prerequisites
- Completed Lab 01 & 02 (RBAC understanding)
- 3 VMs or use existing minikube nodes
- Basic Linux administration skills
- Understanding of container runtime

## Important Note: Lab Environment

**For this lab, we'll use your existing minikube cluster in a special way:**

Since you already have a 3-node minikube cluster running, we'll:
1. **Simulate** kubeadm installation steps (understand the concepts)
2. **Practice** the actual kubeadm commands in dry-run mode
3. **Verify** cluster components that minikube already created
4. **Focus** on understanding what kubeadm does under the hood

**For real kubeadm practice**, you would need fresh VMs. We'll note where simulation differs from reality.

## Lab Structure

```
lab03-kubeadm-install/
├── README.md
├── QUICK-REFERENCE.md
├── scripts/
│   ├── prerequisites-check.sh    # Check system requirements
│   ├── inspect-cluster.sh        # Inspect existing cluster
│   └── verify-components.sh      # Verify cluster components
└── solutions/
    └── SOLUTION.md
```

---

## Understanding kubeadm

### What is kubeadm?

`kubeadm` is the official Kubernetes tool for bootstrapping clusters. It:
- ✅ Installs control plane components
- ✅ Configures networking
- ✅ Generates certificates
- ✅ Joins worker nodes
- ❌ Does NOT install container runtime (you do this)
- ❌ Does NOT install kubectl/kubelet (you do this)

### kubeadm Workflow

```
┌─────────────────────────────────────────────────────────────┐
│ Step 1: Prerequisites (All Nodes)                           │
│ - Install container runtime (containerd/cri-o)              │
│ - Install kubeadm, kubelet, kubectl                         │
│ - Disable swap                                              │
│ - Configure kernel modules                                  │
└─────────────────────────────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ Step 2: Initialize Control Plane (Master Node)              │
│ - kubeadm init                                              │
│ - Creates certificates                                       │
│ - Starts etcd, API server, scheduler, controller-manager    │
│ - Generates join token                                      │
└─────────────────────────────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ Step 3: Configure kubectl (Control Plane)                   │
│ - Copy admin.conf to ~/.kube/config                         │
│ - Test cluster access                                       │
└─────────────────────────────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ Step 4: Install CNI Plugin (Control Plane)                  │
│ - Apply Calico/Flannel/Weave YAML                          │
│ - Enables pod networking                                    │
└─────────────────────────────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ Step 5: Join Worker Nodes                                   │
│ - kubeadm join <control-plane>:6443 --token <token>        │
│ - Nodes register with API server                            │
│ - Start kubelet, kube-proxy                                 │
└─────────────────────────────────────────────────────────────┘
```

---

## Tasks

### Task 1: Prerequisites Check (15 min)

**Objective:** Understand what must be installed before kubeadm.

**On a fresh VM, you would install:**

```bash
# 1. Disable swap (Kubernetes requirement)
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# 2. Load kernel modules
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# 3. Configure sysctl
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

# 4. Install containerd
sudo apt-get update
sudo apt-get install -y containerd

# Configure containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

# 5. Install kubeadm, kubelet, kubectl
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | \
    sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /' | \
    sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

**What we'll do in this lab:**

Since minikube already has everything, we'll inspect what's running:

```bash
# Run the prerequisites check script
./scripts/prerequisites-check.sh
```

**Expected Output:**
```
✓ Container runtime: containerd running
✓ kubelet: installed and running
✓ kubeadm: installed (version 1.35.1)
✓ kubectl: installed (version 1.35.1)
✓ Swap: disabled
✓ Kernel modules: loaded
```

---

### Task 2: Understanding kubeadm init (20 min)

**Objective:** Understand what happens during cluster initialization.

**On a fresh control plane node, you would run:**

```bash
sudo kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address=<control-plane-ip> \
  --kubernetes-version=1.34.0
```

**What kubeadm init does:**

1. **Preflight Checks**
   - Validates system requirements
   - Checks if ports are available
   - Verifies container runtime

2. **Generates Certificates**
   ```
   /etc/kubernetes/pki/
   ├── apiserver.crt
   ├── apiserver-kubelet-client.crt
   ├── ca.crt
   ├── ca.key
   ├── etcd/
   │   ├── ca.crt
   │   └── ca.key
   ├── front-proxy-ca.crt
   └── sa.key
   ```

3. **Generates kubeconfig Files**
   ```
   /etc/kubernetes/
   ├── admin.conf
   ├── controller-manager.conf
   ├── kubelet.conf
   └── scheduler.conf
   ```

4. **Starts Control Plane Components**
   - etcd (as static pod)
   - kube-apiserver (as static pod)
   - kube-controller-manager (as static pod)
   - kube-scheduler (as static pod)

5. **Creates Bootstrap Token**
   - Used for worker nodes to join

**In our minikube cluster, inspect what kubeadm created:**

```bash
# View static pod manifests (what kubeadm creates)
ls -la /etc/kubernetes/manifests/

# Expected:
# etcd.yaml
# kube-apiserver.yaml
# kube-controller-manager.yaml
# kube-scheduler.yaml
```

**Note:** In minikube, you can access the control plane node:
```bash
minikube ssh
ls -la /etc/kubernetes/manifests/
exit
```

---

### Task 3: Inspect Control Plane Components (15 min)

**Objective:** Understand the control plane architecture.

```bash
# View control plane pods
kubectl get pods -n kube-system

# Expected output:
# coredns-*                  (DNS)
# etcd-*                     (Database)
# kube-apiserver-*           (API Server)
# kube-controller-manager-*  (Controllers)
# kube-proxy-*               (Network proxy)
# kube-scheduler-*           (Scheduler)
```

**Inspect each component:**

```bash
# 1. etcd - The cluster database
kubectl describe pod -n kube-system etcd-opscart

# Key info to look for:
# - Image: registry.k8s.io/etcd:3.5.x
# - Command: etcd --advertise-client-urls=...
# - Volume mounts: /var/lib/etcd

# 2. API Server - The cluster gateway
kubectl describe pod -n kube-system kube-apiserver-opscart

# Key info:
# - Image: registry.k8s.io/kube-apiserver:v1.35.1
# - Command flags: --enable-admission-plugins, --etcd-servers, etc.
# - Ports: 6443 (HTTPS)

# 3. Controller Manager - Manages controllers
kubectl describe pod -n kube-system kube-controller-manager-opscart

# Key info:
# - Controllers: deployment, replicaset, node, service, etc.
# - Leader election

# 4. Scheduler - Places pods on nodes
kubectl describe pod -n kube-system kube-scheduler-opscart

# Key info:
# - Scheduling policies
# - Leader election
```

**Check component health:**

```bash
# API server health
kubectl get --raw='/healthz?verbose'

# Component status (deprecated but useful for learning)
kubectl get componentstatuses
```

---

### Task 4: Understand Worker Node Join Process (10 min)

**Objective:** Learn how worker nodes join the cluster.

**On a fresh worker node, you would run:**

```bash
sudo kubeadm join <control-plane-ip>:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash>
```

**What kubeadm join does:**

1. **Downloads Cluster Info**
   - Connects to API server
   - Validates token
   - Downloads CA certificate

2. **Starts kubelet**
   - Registers node with API server
   - Starts pulling pod images

3. **Starts kube-proxy**
   - Configures network rules

**Generate a join command (for learning):**

```bash
# This would generate the join token (admin access required)
kubeadm token create --print-join-command

# Note: This might not work in minikube, but shows the concept
```

**View nodes in cluster:**

```bash
kubectl get nodes -o wide

# Expected:
# NAME          STATUS   ROLES           AGE   VERSION   INTERNAL-IP
# opscart       Ready    control-plane   1h    v1.35.1   192.168.58.2
# opscart-m02   Ready    <none>          1h    v1.35.1   192.168.58.3
# opscart-m03   Ready    <none>          1h    v1.35.1   192.168.58.4
```

**Inspect node details:**

```bash
# View node details
kubectl describe node opscart

# Key sections:
# - Conditions: Ready, MemoryPressure, DiskPressure
# - Capacity: CPU, Memory, Pods
# - Allocatable: Available resources
# - System Info: OS, Kernel, Container Runtime
```

---

### Task 5: CNI Plugin Installation (Understanding) (10 min)

**Objective:** Understand how pod networking is configured.

**After kubeadm init, you must install a CNI plugin:**

```bash
# Example: Install Calico
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

# Or Flannel
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# Or Weave Net
kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml
```

**Why CNI is needed:**

- kubeadm does NOT install networking
- Pods need to communicate across nodes
- CNI provides the pod network overlay

**In minikube, check which CNI is running:**

```bash
# View CNI pods
kubectl get pods -n kube-system | grep -E 'calico|flannel|weave|kindnet'

# minikube uses 'kindnet' by default
kubectl get pods -n kube-system -l k8s-app=kindnet

# View CNI configuration
kubectl describe daemonset -n kube-system kindnet
```

**Understanding CNI configuration:**

```bash
# CNI config files location (inside nodes)
# /etc/cni/net.d/

# Example config
minikube ssh
ls -la /etc/cni/net.d/
cat /etc/cni/net.d/10-kindnet.conflist
exit
```

---

## Validation Checklist

Use this to verify a properly installed cluster:

**Control Plane:**
- [ ] All control plane pods running (etcd, api-server, controller-manager, scheduler)
- [ ] API server responding (kubectl cluster-info)
- [ ] Certificates valid (/etc/kubernetes/pki/)
- [ ] kubeconfig accessible (~/.kube/config)

**Nodes:**
- [ ] All nodes in Ready state
- [ ] kubelet running on all nodes
- [ ] Container runtime running

**Networking:**
- [ ] CNI plugin installed and running
- [ ] CoreDNS pods running
- [ ] Pods can communicate across nodes

**Tests:**
- [ ] Can create a deployment
- [ ] Pods get scheduled
- [ ] Services work
- [ ] DNS resolution works

---
## Important Notes About verify-components.sh

**The script automatically cleans up test resources!**

The verification script:
1. Creates test deployment (`nginx-test`)
2. Tests functionality
3. **Automatically deletes everything** (cleanup)

This is by design - the script doesn't leave test resources in your cluster.

**If you want to inspect the test deployment:**
```bash
# Option 1: Comment out cleanup in the script
# Edit scripts/verify-components.sh and comment out the cleanup section

# Option 2: Create manually after running the script
kubectl create deployment nginx-test --image=nginx --replicas=2
kubectl get pods -l app=nginx-test

# Clean up when done
kubectl delete deployment nginx-test
```

**Why you don't see the deployment:**
- The script ran successfully
- The deployment was created and tested
- The script cleaned it up
- This is expected behavior ✅

---

## Common Issues & Troubleshooting

### Issue 1: Pods Stuck in Pending (No CNI)

**Symptom:**
```bash
kubectl get pods -A
# All pods show: Pending or ContainerCreating
```

**Cause:** CNI plugin not installed

**Solution:**
```bash
kubectl apply -f <cni-plugin-yaml>
```

### Issue 2: Nodes Not Ready

**Symptom:**
```bash
kubectl get nodes
# Shows: NotReady
```

**Debug:**
```bash
kubectl describe node <node-name>

# Look for:
# - Container runtime not running
# - kubelet not running
# - Network plugin issues
```

**Solution:**
```bash
# Check kubelet
sudo systemctl status kubelet
sudo journalctl -u kubelet -f

# Restart if needed
sudo systemctl restart kubelet
```

### Issue 3: kubeadm init Fails

**Common causes:**
```bash
# Port already in use
sudo netstat -tulpn | grep -E '6443|2379|2380|10250|10251|10252'

# Swap not disabled
free -h

# Container runtime not running
sudo systemctl status containerd
```

### Issue 4: Certificate Errors

**Symptom:**
```
Unable to connect to the server: x509: certificate has expired
```

**Solution:**
```bash
# Check certificate expiration
kubeadm certs check-expiration

# Renew certificates
sudo kubeadm certs renew all

# Restart control plane
sudo systemctl restart kubelet
```

---

## Exam Tips

⏱️ **Time Management:**
- kubeadm init: 3-5 minutes
- CNI installation: 1 minute
- Node join: 2 minutes per node
- Verification: 2 minutes
- **Total: ~10 minutes for 3-node cluster**

🔑 **Quick Commands (Exam Speed):**

```bash
# Initialize cluster
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

# Configure kubectl (after init)
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Install CNI (Calico example)
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

# Generate join command (on control plane)
kubeadm token create --print-join-command

# Join worker node (run output from above on worker)
sudo kubeadm join <output-from-above>

# Verify
kubectl get nodes
kubectl get pods -A
```

📖 **Documentation Reference (Allowed in Exam):**
- kubeadm install: kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
- kubeadm init: kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/
- CNI plugins: kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/network-plugins/

🎯 **Exam Question Patterns:**

> *"Install a 3-node Kubernetes cluster using kubeadm. Control plane should use pod-network-cidr 10.244.0.0/16. Install Calico as the CNI plugin."*

> *"Add a new worker node to the existing cluster."*

> *"Check certificate expiration and renew if needed."*

---

## Production Notes from Real Enterprise

**At our pharmaceutical company:**

1. **Custom kubeadm Config:**
   ```yaml
   apiVersion: kubeadm.k8s.io/v1beta3
   kind: ClusterConfiguration
   kubernetesVersion: v1.34.0
   networking:
     podSubnet: 10.244.0.0/16
   apiServer:
     extraArgs:
       audit-log-path: /var/log/kubernetes/audit.log
       audit-policy-file: /etc/kubernetes/audit-policy.yaml
   ```

2. **HA Control Plane:**
   - 3 control plane nodes (odd number for etcd quorum)
   - Load balancer in front of API servers
   - Separate etcd cluster (external)

3. **Worker Node Pools:**
   - General workloads: n1-standard-4
   - Database workloads: n1-highmem-8
   - Batch processing: preemptible instances
   - GPU workloads: n1-standard-8 with GPUs

4. **Certificate Management:**
   - Automated renewal with cert-manager
   - Alerts 30 days before expiration
   - Annual manual verification

5. **Monitoring:**
   - Prometheus scrapes kubelet metrics
   - Alerts on control plane component failures
   - Dashboard shows node capacity

---

## Going Deeper (Post-Lab Reading)

**Advanced kubeadm Topics:**
1. **HA Control Plane** - Multiple masters with etcd cluster
2. **External etcd** - Separate etcd cluster for production
3. **Custom Certificates** - Using your own CA
4. **Kubeadm Config Files** - Advanced configuration
5. **Air-Gapped Installation** - Offline cluster setup

**Related Topics:**
- Container runtime comparison (containerd vs CRI-O)
- CNI plugin performance (Calico vs Cilium vs Flannel)
- kubelet configuration deep dive
- Static pods vs DaemonSets

---

## Next Lab

Ready for the next step? Move to **[Lab 04: Cluster Upgrade](../04-cluster-upgrade/README.md)**

In Lab 04, you'll learn:
- Upgrade control plane with kubeadm
- Upgrade worker nodes
- Handle upgrade failures
- Zero-downtime upgrades

---

**Author:** Shamsher Khan | **Blog:** opscart.com | **Course:** Production CKA 2026