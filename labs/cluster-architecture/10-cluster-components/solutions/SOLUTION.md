# Lab 10: Cluster Components - Solution Guide

## Quick Reference (Exam Speed)

```bash
# Check all control plane components
kubectl get pods -n kube-system | grep -E "etcd|apiserver|scheduler|controller"

# Check API health
kubectl get --raw='/healthz'

# Check kube-proxy
kubectl get daemonset kube-proxy -n kube-system

# Check kubelet on node
minikube ssh "sudo systemctl status kubelet"
```

---

## Complete Solution

### Step 1: Inspect API Server

```bash
kubectl describe pod kube-apiserver-opscart -n kube-system

# Key flags:
# --etcd-servers=https://127.0.0.1:2379
# --service-cluster-ip-range=10.96.0.0/12
# --authorization-mode=Node,RBAC
# --enable-admission-plugins=...

# View static pod manifest
minikube ssh "sudo cat /etc/kubernetes/manifests/kube-apiserver.yaml"

# Test API server
kubectl api-versions
kubectl api-resources | wc -l
```

### Step 2: Inspect Scheduler

```bash
kubectl describe pod kube-scheduler-opscart -n kube-system

# Test scheduling - create pod and watch it get assigned
kubectl run sched-test --image=nginx
kubectl get pod sched-test -o wide  # shows which node it was assigned to
kubectl delete pod sched-test
```

### Step 3: Inspect Controller Manager

```bash
kubectl describe pod kube-controller-manager-opscart -n kube-system

# Test controllers
kubectl create deployment ctrl-test --image=nginx --replicas=2
kubectl get replicaset -l app=ctrl-test    # RS auto-created
kubectl get pods -l app=ctrl-test          # Pods auto-created
kubectl delete deployment ctrl-test
```

### Step 4: Inspect kubelet

```bash
minikube ssh "sudo systemctl status kubelet"
minikube ssh "sudo cat /var/lib/kubelet/config.yaml | head -20"
minikube ssh "sudo journalctl -u kubelet -n 20"
exit
```

### Step 5: Inspect kube-proxy

```bash
kubectl get daemonset kube-proxy -n kube-system
kubectl get pods -n kube-system -l k8s-app=kube-proxy -o wide
kubectl describe configmap kube-proxy -n kube-system | head -30
```

### Step 6: Explore etcd Data

```bash
# List registry keys
kubectl exec -n kube-system etcd-opscart -- \
  etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/var/lib/minikube/certs/etcd/ca.crt \
  --cert=/var/lib/minikube/certs/etcd/server.crt \
  --key=/var/lib/minikube/certs/etcd/server.key \
  get / --prefix --keys-only | head -20
```

### Run Automated Tests

```bash
./scripts/setup.sh
./scripts/test.sh
# Should show 12/12 checks passed
```

---

## Component Failure Impact

```
Component Failed        │ Impact
────────────────────────┼───────────────────────────────────────
kube-apiserver          │ kubectl fails, NO cluster management
kube-scheduler          │ New pods stuck in Pending
controller-manager      │ No self-healing, no new RS/Deployments
etcd                    │ Complete cluster failure
kubelet (node)          │ Node NotReady, pods evicted
kube-proxy (node)       │ Service networking broken on that node
```

## Static Pod Manifest Locations

```bash
/etc/kubernetes/manifests/etcd.yaml
/etc/kubernetes/manifests/kube-apiserver.yaml
/etc/kubernetes/manifests/kube-controller-manager.yaml
/etc/kubernetes/manifests/kube-scheduler.yaml
```

## Key Takeaways

✅ **kube-apiserver** is the central hub - everything talks to it  
✅ **kube-scheduler** assigns pods to nodes  
✅ **controller-manager** runs all controllers (self-healing)  
✅ **etcd** stores ALL cluster state  
✅ **kubelet** runs on every node, manages pods  
✅ **kube-proxy** handles service networking on each node  
✅ **Static pods** in `/etc/kubernetes/manifests/` restart automatically  

---

**Completed Lab 10?** ✅

Move to **[Lab 11: API Server Authentication](../11-api-server-auth/)**
