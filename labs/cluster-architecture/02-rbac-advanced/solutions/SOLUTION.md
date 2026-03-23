# Lab 02: RBAC Advanced - Solution Guide

## Quick Exam Solution (7 minutes)

If you see this in the CKA exam:

> *"Create a ClusterRole 'pod-viewer' that allows viewing pods cluster-wide. Bind it to serviceaccount 'viewer' in namespace 'monitoring'."*

**Speed Solution:**

```bash
# 1. Create ClusterRole (1 minute)
kubectl create clusterrole pod-viewer \
  --verb=get,list,watch \
  --resource=pods

# 2. Create ClusterRoleBinding (1 minute)
kubectl create clusterrolebinding viewer-binding \
  --clusterrole=pod-viewer \
  --serviceaccount=monitoring:viewer

# 3. Verify (30 seconds)
kubectl auth can-i get pods --all-namespaces \
  --as=system:serviceaccount:monitoring:viewer
```

---

## Detailed Step-by-Step Solutions

### Task 1: Create Service Accounts

```bash
# Create namespaces
kubectl create namespace prod
kubectl create namespace staging

# Create service accounts
kubectl create serviceaccount platform-admin -n kube-system
kubectl create serviceaccount security-viewer -n kube-system
kubectl create serviceaccount monitoring-user -n kube-system
kubectl create serviceaccount developer -n prod

# Verify
kubectl get sa -n kube-system | grep -E 'platform|security|monitoring'
kubectl get sa -n prod
```

---

### Task 2: Platform Admin ClusterRole

**Using Manifests (More Control):**

```bash
cat > platform-admin.yaml << 'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: platform-admin
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
- nonResourceURLs: ["*"]
  verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: platform-admin-binding
subjects:
- kind: ServiceAccount
  name: platform-admin
  namespace: kube-system
roleRef:
  kind: ClusterRole
  name: platform-admin
  apiGroup: rbac.authorization.k8s.io
EOF

kubectl apply -f platform-admin.yaml
```

**Verify:**
```bash
kubectl auth can-i '*' '*' \
  --as=system:serviceaccount:kube-system:platform-admin
# Should return: yes
```

---

### Task 3: Security Viewer ClusterRole

**Using Built-in Role (Fastest):**

```bash
# Use built-in 'view' ClusterRole
kubectl create clusterrolebinding security-viewer-binding \
  --clusterrole=view \
  --serviceaccount=kube-system:security-viewer
```

**Custom Role (More Control):**

```bash
kubectl apply -f manifests/cluster-viewer-role.yaml
kubectl apply -f manifests/cluster-viewer-binding.yaml
```

**Verify:**
```bash
# Can read
kubectl auth can-i get pods --all-namespaces \
  --as=system:serviceaccount:kube-system:security-viewer
# yes

# Cannot write
kubectl auth can-i create pods \
  --as=system:serviceaccount:kube-system:security-viewer
# no
```

---

### Task 4: Node Reader with RoleBinding

**Key Concept:** ClusterRole + RoleBinding = Cluster resource access limited by namespace.

```bash
# Create ClusterRole
kubectl create clusterrole node-reader \
  --verb=get,list,watch \
  --resource=nodes

# Bind with RoleBinding (not ClusterRoleBinding!)
kubectl create rolebinding developer-node-reader \
  --clusterrole=node-reader \
  --serviceaccount=prod:developer \
  -n prod
```

**Verify:**
```bash
# Can access nodes (cluster-scoped)
kubectl auth can-i get nodes \
  --as=system:serviceaccount:prod:developer
# yes

# Cannot access pods in prod (no namespace permissions)
kubectl auth can-i get pods -n prod \
  --as=system:serviceaccount:prod:developer
# no
```

**Why This Works:**
- ClusterRole defines permissions for cluster-scoped resources (nodes)
- RoleBinding limits who gets it (only developer in prod namespace)
- Developer can view nodes but has no namespace-level permissions

---

### Task 5: Aggregated ClusterRole

```bash
kubectl apply -f manifests/aggregated-monitoring-role.yaml

# Wait a few seconds for aggregation
sleep 5

# Verify aggregation worked
kubectl describe clusterrole monitoring-aggregated

# Should show rules from all component roles:
# - monitoring-metrics
# - monitoring-logs
# - monitoring-events
```

**Test permissions:**
```bash
kubectl auth can-i get pods \
  --as=system:serviceaccount:kube-system:monitoring-user \
  --all-namespaces
# yes

kubectl auth can-i get pods/log \
  --as=system:serviceaccount:kube-system:monitoring-user \
  --all-namespaces
# yes

kubectl auth can-i get events \
  --as=system:serviceaccount:kube-system:monitoring-user \
  --all-namespaces
# yes
```

---

## Common Exam Variations

### Variation 1: Grant Cluster-Admin to User

```bash
kubectl create clusterrolebinding admin-binding \
  --clusterrole=cluster-admin \
  --user=admin@example.com
```

### Variation 2: Read-Only Access Everywhere

```bash
kubectl create clusterrolebinding viewer \
  --clusterrole=view \
  --group=viewers
```

### Variation 3: Namespace Creator Role

```bash
cat > namespace-creator.yaml << 'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: namespace-creator
rules:
- apiGroups: [""]
  resources: ["namespaces"]
  verbs: ["create", "get", "list"]
EOF

kubectl apply -f namespace-creator.yaml

kubectl create clusterrolebinding ns-creator-binding \
  --clusterrole=namespace-creator \
  --user=platform-team@example.com
```

---

## Troubleshooting Guide

### Issue 1: ClusterRoleBinding Not Working

**Problem:** Permissions not applying

**Debug:**
```bash
# Check if ClusterRole exists
kubectl get clusterrole <name>

# Check if ClusterRoleBinding exists
kubectl get clusterrolebinding <name>

# Describe the binding to verify subjects
kubectl describe clusterrolebinding <name>

# Look for:
# - Correct ClusterRole reference
# - Correct subject (SA/User/Group)
# - Correct namespace for ServiceAccount
```

### Issue 2: Aggregation Not Working

**Problem:** Aggregated ClusterRole has empty rules

**Debug:**
```bash
# Check component roles have correct labels
kubectl get clusterrole monitoring-metrics -o yaml | grep labels -A 5

# Should see:
#   labels:
#     rbac.authorization.k8s.io/aggregate-to-monitoring: "true"

# Check base role has aggregationRule
kubectl get clusterrole monitoring-aggregated -o yaml | grep aggregationRule -A 5

# Wait a few seconds - aggregation isn't instant
sleep 10
kubectl describe clusterrole monitoring-aggregated
```

### Issue 3: ServiceAccount Format Wrong

**Common mistake:**
```bash
# ❌ Wrong - missing namespace
--as=system:serviceaccount:platform-admin

# ✅ Correct
--as=system:serviceaccount:kube-system:platform-admin
```

---

## Best Practices (Production)

### 1. Avoid Wildcards in Production

```yaml
# ❌ Don't do this in production
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]

# ✅ Be explicit
rules:
- apiGroups: [""]
  resources: ["pods", "services"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "update", "patch"]
```

### 2. Use Built-in Roles When Possible

```bash
# Instead of creating custom read-only role, use:
kubectl create clusterrolebinding viewer \
  --clusterrole=view \
  --serviceaccount=monitoring:viewer
```

### 3. Principle of Least Privilege

```bash
# Give minimum permissions needed
# Start restrictive, expand as needed
# Never give cluster-admin unless absolutely necessary
```

### 4. Document Custom Roles

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: node-manager
  annotations:
    description: "Infrastructure team - manage nodes only"
    owner: "platform-team@company.com"
    created: "2026-01-07"
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list", "watch", "update", "patch"]
```

---

## Comparison: Role vs ClusterRole

| Scenario | Use Role | Use ClusterRole |
|----------|----------|-----------------|
| Team access in one namespace | ✅ | ❌ |
| View nodes | ❌ | ✅ |
| Cluster-wide monitoring | ❌ | ✅ |
| Platform team | ❌ | ✅ |
| Developer in dev namespace | ✅ | ❌ |
| Security audit team | ❌ | ✅ (read-only) |

---

## What to Remember for Exam

**ClusterRole** for cluster-wide or cluster-scoped resources
**ClusterRoleBinding** binds to everyone, everywhere
**ClusterRole + RoleBinding** = limited to namespace
**Aggregation** uses labels to compose permissions
**Built-in roles** (`view`, `edit`, `admin`, `cluster-admin`)
**ServiceAccount format**: `system:serviceaccount:NAMESPACE:NAME`

---

## Automated Solution

```bash
# Full setup
./scripts/setup.sh

# Validate
./scripts/test.sh

# Cleanup
./scripts/cleanup.sh
```

---

**Completed Lab 02?** 

Move to **[Lab 03: kubeadm Cluster Installation](../03-kubeadm-install/)**