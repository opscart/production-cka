# Lab 15: CNI Plugins - Solution Guide

## Run the Scripts
```bash
./scripts/setup.sh
./scripts/test.sh
./scripts/cleanup.sh
```

---

## Complete Manual Solution

### Step 1: Identify CNI Plugin
```bash
# Find CNI pod
kubectl get pods -n kube-system | grep -E "calico|flannel|weave|cilium|kindnet"

# Check config files on node
minikube ssh "ls /etc/cni/net.d/"
minikube ssh "cat /etc/cni/net.d/*.conflist"

# Check binaries
minikube ssh "ls /opt/cni/bin/"
```

### Step 2: Check Node Pod CIDRs
```bash
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.podCIDR}{"\n"}{end}'

# Example output:
# opscart        10.244.0.0/24
# opscart-m02    10.244.1.0/24
# opscart-m03    10.244.2.0/24
```

### Step 3: Create Pods on Different Nodes
```bash
kubectl create namespace lab15-cni

# Pod on node 1
kubectl apply -f manifests/pod-node1.yaml

# Pod on node 2
kubectl apply -f manifests/pod-node2.yaml

# Check IPs and node placement
kubectl get pods -n lab15-cni -o wide
```

### Step 4: Test Cross-Node Connectivity
```bash
POD2_IP=$(kubectl get pod pod-node2 -n lab15-cni -o jsonpath='{.status.podIP}')

# Ping across nodes
kubectl exec pod-node1 -n lab15-cni -- ping -c 3 $POD2_IP
# Should succeed - CNI enables cross-node pod communication
```

### Step 5: Test DNS
```bash
# DNS for service
kubectl create deployment web-app --image=nginx -n lab15-cni
kubectl expose deployment web-app --port=80 -n lab15-cni

kubectl exec pod-node1 -n lab15-cni -- \
  nslookup web-app.lab15-cni.svc.cluster.local

# HTTP via service
kubectl exec pod-node1 -n lab15-cni -- \
  wget -q -O- http://web-app.lab15-cni.svc.cluster.local | head -3
```

---

## How CNI Assigns IPs

```
kubeadm init --pod-network-cidr=10.244.0.0/16
                    │
                    ▼
        Node gets subnet: 10.244.X.0/24
                    │
                    ▼
        CNI assigns pod IPs from subnet
        pod-node1 → 10.244.0.X
        pod-node2 → 10.244.1.X
```

---

## Key Takeaways

✅ CNI must be installed after cluster setup (not built-in)
✅ CNI config lives in `/etc/cni/net.d/`
✅ CNI binaries live in `/opt/cni/bin/`
✅ Each node gets a pod CIDR subnet
✅ Pods on different nodes can communicate (CNI handles routing)
✅ DNS uses service FQDN: `<service>.<namespace>.svc.cluster.local`

---

**Completed Lab 15?** ✅

Move to **[Lab 16: CSI Storage](../16-csi-storage/)**