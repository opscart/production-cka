# Lab 12: Admission Controllers

## Objective
Understand Kubernetes admission controllers - what they are, how they work, which ones are active by default, and how to use them to enforce policies. Focus on practical controllers relevant to the CKA exam.

## CKA Exam Relevance
- **Domain:** Cluster Architecture, Installation & Configuration (25%)
- **Topic:** Understand admission controllers
- **Exam Weight:** Medium (30-40% of exams)
- **Typical Exam Time:** 5-8 minutes

## Time to Complete
45 minutes

## Prerequisites
- Completed Labs 01-11
- Running minikube cluster
- Understanding of RBAC (Labs 01-02)

---

## What are Admission Controllers?

Admission controllers are **plugins that intercept API server requests** after authentication and authorization but **before** the object is persisted to etcd.

```
kubectl apply → API Server
                    │
                    ├─ 1. Authentication  (who are you?)
                    ├─ 2. Authorization   (can you do it?)
                    ├─ 3. Admission       (should we allow it?) ← HERE
                    │       │
                    │       ├─ Mutating Webhooks   (modify the request)
                    │       └─ Validating Webhooks (approve/reject)
                    │
                    └─ 4. Persist to etcd
```

### Two Types

```
Mutating Admission:    Changes the object before saving
                       Example: Add default resource limits
                       Example: Inject sidecar containers

Validating Admission:  Approves or rejects the object
                       Example: Reject pods without resource limits
                       Example: Require specific labels
```

---

## Built-in Admission Controllers

```
Controller                  │ Type         │ What it does
────────────────────────────┼──────────────┼──────────────────────────────
NamespaceLifecycle          │ Validating   │ Reject resources in terminating NS
LimitRanger                 │ Mutating     │ Apply default resource limits
ResourceQuota               │ Validating   │ Enforce namespace resource quotas
ServiceAccount              │ Mutating     │ Auto-add service account to pods
DefaultStorageClass         │ Mutating     │ Add default storage class to PVCs
MutatingAdmissionWebhook    │ Mutating     │ Call external webhook
ValidatingAdmissionWebhook  │ Validating   │ Call external webhook
NodeRestriction             │ Validating   │ Limit what kubelets can modify
```

---

## Tasks

### Task 1: Check Active Admission Controllers (5 min)

**Objective:** Find which admission controllers are enabled.

```bash
# Check API server flags
kubectl describe pod kube-apiserver-opscart -n kube-system | \
  grep -E "enable-admission|admission-plugins"

# View static pod manifest
minikube ssh "sudo cat /etc/kubernetes/manifests/kube-apiserver.yaml" | \
  grep -A2 "admission"
```

---

### Task 2: LimitRange - Default Resource Limits (10 min)

**Objective:** Use LimitRange to set default CPU/memory limits for a namespace.

```bash
# Create namespace
kubectl create namespace lab12-admission

# Create LimitRange
cat > manifests/limitrange.yaml << 'EOF'
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

kubectl apply -f manifests/limitrange.yaml

# Verify LimitRange
kubectl describe limitrange default-limits -n lab12-admission
```

**Test: Create pod WITHOUT resource limits:**

```bash
kubectl run no-limits-pod \
  --image=nginx \
  -n lab12-admission

# Check - limits should be automatically applied!
kubectl get pod no-limits-pod -n lab12-admission -o \
  jsonpath='{.spec.containers[0].resources}' | python3 -m json.tool
```

**LimitRange automatically injected default limits!** This is the Mutating Admission Controller in action.

---

### Task 3: ResourceQuota - Namespace Resource Limits (10 min)

**Objective:** Enforce resource quotas on a namespace.

```bash
# Create ResourceQuota
cat > manifests/resourcequota.yaml << 'EOF'
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
    configmaps: "10"
    secrets: "10"
    services: "5"
EOF

kubectl apply -f manifests/resourcequota.yaml

# View quota
kubectl describe resourcequota lab12-quota -n lab12-admission
```

**Test quota enforcement:**

```bash
# Create several pods to approach limit
for i in 1 2 3 4; do
  kubectl run quota-test-$i --image=nginx -n lab12-admission
done

# Check quota usage
kubectl describe resourcequota lab12-quota -n lab12-admission

# Try to exceed pod limit (5 pods max)
kubectl run quota-test-6 --image=nginx -n lab12-admission
# Error: exceeded quota: lab12-quota, requested: pods=1, used: pods=5, limited: pods=5
```

---

### Task 4: NamespaceLifecycle Controller (5 min)

**Objective:** Understand namespace lifecycle enforcement.

```bash
# Create a namespace
kubectl create namespace lifecycle-test

# Start deleting it
kubectl delete namespace lifecycle-test &

# Immediately try to create a resource in it
sleep 1
kubectl run test-pod --image=nginx -n lifecycle-test
# Error: unable to create new content in namespace lifecycle-test
# because it is being terminated
```

**The NamespaceLifecycle admission controller** prevents resources being created in terminating namespaces.

---

### Task 5: NodeRestriction Controller (5 min)

**Objective:** Understand NodeRestriction admission controller.

```bash
# NodeRestriction limits what kubelet can do
# Kubelets can only:
# - Modify their own Node object
# - Modify pods bound to their node
# - Cannot modify other nodes or pods on other nodes

# View node labels (kubelet cannot add arbitrary labels starting with node-restriction.kubernetes.io)
kubectl get node opscart --show-labels

# Check NodeRestriction is enabled
kubectl describe pod kube-apiserver-opscart -n kube-system | \
  grep NodeRestriction
```

---

### Task 6: ValidatingAdmissionPolicy (10 min)

**Objective:** Use the new built-in policy engine (CEL-based).

**ValidatingAdmissionPolicy** is a newer alternative to external webhooks, using Common Expression Language (CEL).

```bash
# Create a policy that requires all pods to have resource limits
cat > manifests/require-limits-policy.yaml << 'EOF'
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: require-resource-limits
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: ["v1"]
      operations: ["CREATE", "UPDATE"]
      resources: ["pods"]
  validations:
  - expression: >
      object.spec.containers.all(c,
        has(c.resources) &&
        has(c.resources.limits) &&
        has(c.resources.limits.cpu) &&
        has(c.resources.limits.memory))
    message: "All containers must have CPU and memory limits"
EOF

kubectl apply -f manifests/require-limits-policy.yaml

# Bind the policy to a namespace
cat > manifests/require-limits-binding.yaml << 'EOF'
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: require-resource-limits-binding
spec:
  policyName: require-resource-limits
  validationActions: [Deny]
  matchResources:
    namespaceSelector:
      matchLabels:
        enforce-limits: "true"
EOF

kubectl apply -f manifests/require-limits-binding.yaml

# Label namespace to enforce policy
kubectl label namespace lab12-admission enforce-limits=true

# Test: pod without limits should be rejected
kubectl run no-limits-test \
  --image=nginx \
  --overrides='{"spec":{"containers":[{"name":"no-limits-test","image":"nginx"}]}}' \
  -n lab12-admission
# Error: All containers must have CPU and memory limits
```

---

## Exam Tips

⏱️ **Time Management:**
- Check active controllers: 1 minute
- Create LimitRange: 2 minutes
- Create ResourceQuota: 2 minutes
- Verify enforcement: 2 minutes
- **Total: ~7 minutes**

🎯 **Exam Question Patterns:**

> *"Create a LimitRange that sets default CPU limit to 500m"*

> *"Create a ResourceQuota limiting the namespace to 10 pods"*

> *"Which admission controller automatically adds default resource limits?"*
→ **LimitRanger**

> *"Which admission controller enforces ResourceQuota objects?"*
→ **ResourceQuota**

🔑 **Key Facts:**
- Admission controllers run **after** auth/authz
- **Mutating** runs before **Validating**
- LimitRanger = default limits (mutating)
- ResourceQuota = namespace quotas (validating)
- NamespaceLifecycle = prevents resources in terminating NS

---

## Common Issues

### Issue: LimitRange not applying defaults

```bash
# Verify LimitRange exists in correct namespace
kubectl get limitrange -n lab12-admission

# Check pod was created AFTER LimitRange
# Existing pods are not affected, only new ones
```

### Issue: ResourceQuota not enforcing

```bash
# Pods need resource requests to count against quota
kubectl describe resourcequota -n lab12-admission
# Check 'Used' vs 'Hard' columns
```

---

## Next Lab

Move to **[Lab 13: Service Accounts](../13-service-accounts/README.md)**

---

**Author:** Shamsher Khan | **Blog:** opscart.com | **Course:** Production CKA 2026