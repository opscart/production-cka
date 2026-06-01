# Lab 12: Admission Controllers - Quick Reference

## What Admission Controllers Do

```
kubectl apply → Auth → Authz → Admission → etcd
                                    │
                              Mutating (modify)
                              Validating (approve/reject)
```

---

## Key Controllers

```
LimitRanger              → Injects default resource limits (mutating)
ResourceQuota            → Enforces namespace quotas (validating)
NamespaceLifecycle       → Blocks resources in terminating NS
ServiceAccount           → Auto-adds default SA to pods
NodeRestriction          → Limits kubelet permissions
DefaultStorageClass      → Adds default storage class to PVCs
```

---

## LimitRange

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: my-namespace
spec:
  limits:
  - type: Container
    default:           # injected if not specified
      cpu: 200m
      memory: 256Mi
    defaultRequest:    # injected if not specified
      cpu: 100m
      memory: 128Mi
    max:               # cannot exceed
      cpu: 500m
      memory: 512Mi
    min:               # cannot go below
      cpu: 50m
      memory: 64Mi
```

```bash
# Create
kubectl apply -f limitrange.yaml

# View
kubectl describe limitrange <name> -n <namespace>
kubectl get limitrange -n <namespace>
```

---

## ResourceQuota

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: my-quota
  namespace: my-namespace
spec:
  hard:
    pods: "10"
    requests.cpu: "2"
    requests.memory: 4Gi
    limits.cpu: "4"
    limits.memory: 8Gi
    configmaps: "20"
    secrets: "20"
    services: "10"
    persistentvolumeclaims: "5"
```

```bash
# Create
kubectl apply -f quota.yaml

# View usage
kubectl describe resourcequota <name> -n <namespace>

# Quick check
kubectl get resourcequota -n <namespace>
```

---

## Check Active Controllers

```bash
# View API server flags
kubectl describe pod kube-apiserver-<node> -n kube-system | \
  grep -E "admission-plugins|enable-admission"

# Default enabled controllers include:
# NamespaceLifecycle, LimitRanger, ServiceAccount,
# DefaultStorageClass, ResourceQuota, NodeRestriction
```

---

## Exam Scenarios

### Create LimitRange
```bash
kubectl apply -f - << 'EOF'
apiVersion: v1
kind: LimitRange
metadata:
  name: my-limits
  namespace: target-ns
spec:
  limits:
  - type: Container
    default:
      cpu: 500m
      memory: 256Mi
    defaultRequest:
      cpu: 200m
      memory: 128Mi
EOF
```

### Create ResourceQuota
```bash
kubectl apply -f - << 'EOF'
apiVersion: v1
kind: ResourceQuota
metadata:
  name: my-quota
  namespace: target-ns
spec:
  hard:
    pods: "10"
    requests.cpu: "4"
    limits.memory: 8Gi
EOF
```

### Verify LimitRange Applied to Pod
```bash
# Create pod without limits
kubectl run test-pod --image=nginx -n target-ns

# Check injected limits
kubectl get pod test-pod -n target-ns \
  -o jsonpath='{.spec.containers[0].resources}'
```

---

## Key Facts for Exam

- **LimitRanger** injects defaults (mutating)
- **ResourceQuota** enforces counts/limits (validating)
- Mutating runs **before** Validating
- LimitRange only affects **new** pods, not existing ones
- ResourceQuota requires resource **requests** to track usage
- Both are **namespace-scoped**

---

## Time Budget (Exam)

- Create LimitRange: **1 minute**
- Create ResourceQuota: **1 minute**
- Verify injection/enforcement: **1 minute**
- **Total: ~3-4 minutes**