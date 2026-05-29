# Lab 10: Cluster Components - Quick Reference

## Component Summary

```
Component              │ Runs On       │ Role
───────────────────────┼───────────────┼─────────────────────────────
kube-apiserver         │ Control Plane │ REST API, auth, validation
kube-scheduler         │ Control Plane │ Assign pods to nodes
kube-controller-manager│ Control Plane │ Run controllers, self-healing
etcd                   │ Control Plane │ All cluster state storage
kubelet                │ Every Node    │ Run pods, report status
kube-proxy             │ Every Node    │ Service networking (iptables)
Container Runtime      │ Every Node    │ Pull images, run containers
```

---

## Inspect Commands

```bash
# All control plane pods
kubectl get pods -n kube-system | grep -E "etcd|apiserver|scheduler|controller"

# Specific component
kubectl describe pod kube-apiserver-<node> -n kube-system

# Static pod manifests
ls /etc/kubernetes/manifests/

# kubelet status (on node)
systemctl status kubelet
journalctl -u kubelet -n 50

# kube-proxy
kubectl get daemonset kube-proxy -n kube-system
kubectl get pods -n kube-system -l k8s-app=kube-proxy
```

---

## Health Checks

```bash
# API server health
kubectl get --raw='/healthz'    # overall health
kubectl get --raw='/livez'      # liveness
kubectl get --raw='/readyz'     # readiness

# etcd health
kubectl exec -n kube-system etcd-<node> -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=... --cert=... --key=... \
  endpoint health

# Component statuses
kubectl get componentstatuses
```

---

## Component Ports

```
kube-apiserver:          6443 (HTTPS)
etcd:                    2379 (client), 2380 (peer)
kube-scheduler:          10259 (HTTPS)
kube-controller-manager: 10257 (HTTPS)
kubelet:                 10250 (HTTPS)
kube-proxy:              10256 (health)
```

---

## Failure Impact

```
kube-apiserver down    → Everything stops (kubectl fails)
kube-scheduler down    → New pods stuck Pending
controller-mgr down    → No self-healing, no new RS/Deploys
etcd down              → Cluster inaccessible
kubelet down (node)    → Node NotReady, pods evicted
kube-proxy down (node) → Service networking broken on that node
```

---

## Static Pods

```bash
# Location (control plane)
/etc/kubernetes/manifests/

# Files:
etcd.yaml
kube-apiserver.yaml
kube-controller-manager.yaml
kube-scheduler.yaml

# kubelet watches this directory
# Any change → immediate restart
# Delete a static pod → kubelet recreates it!
```

---

## etcd Key Structure

```
/registry/pods/default/my-pod
/registry/deployments/default/my-deploy
/registry/services/default/my-svc
/registry/namespaces/kube-system
/registry/secrets/default/my-secret
```

---

## Exam Scenarios

### Fix Broken Scheduler

```bash
# 1. Check status
kubectl get pods -n kube-system | grep scheduler

# 2. If missing/crashlooping
cat /etc/kubernetes/manifests/kube-scheduler.yaml

# 3. Fix manifest errors
vi /etc/kubernetes/manifests/kube-scheduler.yaml

# 4. kubelet auto-restarts it
kubectl get pods -n kube-system -w | grep scheduler
```

### Find Why Pods Are Pending

```bash
# Check scheduler
kubectl get pods -n kube-system -l component=kube-scheduler

# Check events
kubectl describe pod <pending-pod>
kubectl get events --sort-by='.lastTimestamp'
```

---

## Time Budget (Exam)

- Inspect components: **3 minutes**
- Check logs/health: **2 minutes**
- Fix issues: **3-4 minutes**
- **Total: ~8-10 minutes**
