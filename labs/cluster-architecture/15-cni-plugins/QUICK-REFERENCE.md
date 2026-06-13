# Lab 15: CNI Plugins - Quick Reference

## Key Locations

```bash
/etc/cni/net.d/      # CNI configuration files
/opt/cni/bin/        # CNI plugin binaries
```

---

## Identify CNI Plugin

```bash
# Find CNI pods
kubectl get pods -n kube-system | grep -E "calico|flannel|weave|cilium|kindnet"

# Check CNI config on node
ls /etc/cni/net.d/
cat /etc/cni/net.d/*.conflist

# Check CNI binaries
ls /opt/cni/bin/
```

---

## Pod Network Information

```bash
# Get all pod IPs
kubectl get pods -o wide
kubectl get pods -o wide -A

# Get pod IP
kubectl get pod <name> -o jsonpath='{.status.podIP}'

# Pod network interfaces
kubectl exec <pod> -- ip addr
kubectl exec <pod> -- ip route

# Node pod CIDRs
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.podCIDR}{"\n"}{end}'
```

---

## Test Connectivity

```bash
# Ping between pods
kubectl exec pod-a -- ping -c 3 <pod-b-ip>

# DNS resolution
kubectl exec pod-a -- nslookup kubernetes.default.svc.cluster.local
kubectl exec pod-a -- nslookup <service>.<namespace>.svc.cluster.local

# HTTP test
kubectl exec pod-a -- wget -q -O- http://<service>.<namespace>.svc.cluster.local
```

---

## CNI Plugin Comparison

```
Calico   → Network policies, BGP routing, production-grade
Flannel  → Simple VXLAN overlay, easy to set up
Cilium   → eBPF-based, high performance, advanced observability
Weave    → Mesh networking, automatic encryption
kindnet  → Default for kind and minikube (development)
```

---

## Install CNI (kubeadm clusters)

```bash
# Calico
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

# Flannel
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

# Cilium (via Helm)
helm repo add cilium https://helm.cilium.io/
helm install cilium cilium/cilium -n kube-system
```

---

## Troubleshooting

```bash
# Pod stuck Pending - CNI not ready
kubectl describe pod <name> | grep -A5 Events

# Check CNI pods healthy
kubectl get pods -n kube-system | grep -E "calico|flannel|weave|cilium"

# Check node routes
ip route show
bridge link show

# Check pod-to-pod connectivity
kubectl exec pod-a -- ping -c 3 <pod-b-ip>
```

---

## Key Facts for Exam

- CNI must be installed AFTER `kubeadm init`
- Each pod gets a unique IP from the pod CIDR range
- Pod CIDR is set per-node by the CNI plugin
- CNI config: `/etc/cni/net.d/`
- CNI binaries: `/opt/cni/bin/`
- Nodes get pod CIDR from `--pod-network-cidr` flag at init time

---

## Time Budget (Exam)

- Identify CNI: **1 minute**
- Check pod IPs/connectivity: **2 minutes**
- Troubleshoot: **2-3 minutes**
- **Total: ~5 minutes**