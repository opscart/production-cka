# Lab 12: Admission Controllers - Solution Guide

## Run the Scripts
```bash
./scripts/setup.sh   # Creates namespace, LimitRange, ResourceQuota, test pod
./scripts/test.sh    # Validates all admission controller behavior
./scripts/cleanup.sh
```

---

## Complete Manual Solution

### Step 1: Create Namespace
```bash
kubectl create namespace lab12-admission
```

### Step 2: Create LimitRange (Mutating Admission)
```bash
kubectl apply -f - << 'EOF'
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: lab12-admission
spec:
  limits:
  - type: Container
    default:
      cpu: 200m
      memory: 256Mi
    defaultRequest:
      cpu: 100m
      memory: 128Mi
    max:
      cpu: 500m
      memory: 512Mi
    min:
      cpu: 50m
      memory: 64Mi
EOF

kubectl describe limitrange default-limits -n lab12-admission
```

### Step 3: Verify LimitRange Injection
```bash
# Create pod WITHOUT resource limits
kubectl run no-limits-pod --image=nginx -n lab12-admission

# Check - LimitRange should have injected defaults!
kubectl get pod no-limits-pod -n lab12-admission \
  -o jsonpath='{.spec.containers[0].resources}' | python3 -m json.tool

# Expected output:
# {
#   "limits": { "cpu": "200m", "memory": "256Mi" },
#   "requests": { "cpu": "100m", "memory": "128Mi" }
# }
```

### Step 4: Create ResourceQuota (Validating Admission)
```bash
kubectl apply -f - << 'EOF'
apiVersion: v1
kind: ResourceQuota
metadata:
  name: lab12-quota
  namespace: lab12-admission
spec:
  hard:
    pods: "5"
    requests.cpu: "1"
    requests.memory: 1Gi
    limits.cpu: "2"
    limits.memory: 2Gi
EOF

kubectl describe resourcequota lab12-quota -n lab12-admission
```

### Step 5: Test Quota Enforcement
```bash
# Create pods up to limit
for i in 2 3 4 5; do
  kubectl run quota-test-$i --image=nginx -n lab12-admission
done

# Check usage
kubectl describe resourcequota lab12-quota -n lab12-admission

# Try to exceed - should fail!
kubectl run quota-test-6 --image=nginx -n lab12-admission
# Error: exceeded quota: lab12-quota, requested: pods=1,
#         used: pods=5, limited: pods=5
```

---

## How LimitRange Works (Mutating)

```
User creates pod (no resource limits)
         │
         ▼
LimitRanger admission controller
         │
         ▼
Injects default limits from LimitRange
         │
         ▼
Pod saved to etcd WITH limits
```

## How ResourceQuota Works (Validating)

```
User creates pod #6
         │
         ▼
ResourceQuota admission controller
         │
         ├─ Count current pods: 5
         ├─ Hard limit: 5
         └─ 5 + 1 > 5 → REJECTED
```

---

## Key Takeaways

✅ **LimitRange** injects defaults into new pods (mutating)
✅ **ResourceQuota** enforces namespace-level limits (validating)
✅ Mutating controllers run before validating controllers
✅ LimitRange only affects NEW pods, not existing ones
✅ Pods need resource requests for quota tracking
✅ Both are namespace-scoped resources

---

**Completed Lab 12?** ✅

Move to **[Lab 13: Service Accounts](../13-service-accounts/)**