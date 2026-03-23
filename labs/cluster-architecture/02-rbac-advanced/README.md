# Lab 02: RBAC Advanced - ClusterRoles & ClusterRoleBindings

## Objective
Master cluster-wide RBAC using ClusterRoles and ClusterRoleBindings, understand the difference from namespace-scoped Roles, and implement real production RBAC hierarchies.

## CKA Exam Relevance
- **Domain:** Cluster Architecture, Installation & Configuration (25%)
- **Topic:** Manage role based access control (RBAC)
- **Exam Weight:** High (ClusterRole appears in 60%+ of exams)
- **Typical Exam Time:** 7-10 minutes

## Time to Complete
40 minutes

## Scenario
You're managing a multi-tenant pharmaceutical Kubernetes platform. You need to:

1. **Platform Team** - Full cluster access (nodes, namespaces, CRDs)
2. **Security Team** - Read-only access to everything across all namespaces
3. **Monitoring Team** - Access to metrics and logs cluster-wide
4. **Developers** - Namespace-specific access, but can view nodes

This mirrors real enterprise RBAC where some roles need cluster-wide visibility while maintaining namespace isolation for actual workloads.

## Prerequisites
- Completed Lab 01 (RBAC Basics)
- Minikube cluster running (3 nodes)
- Understanding of Role and RoleBinding
- Basic understanding of cluster-scoped vs namespaced resources

## Key Concepts

### ClusterRole vs Role

| Feature | Role | ClusterRole |
|---------|------|-------------|
| Scope | Single namespace | Entire cluster |
| Resources | Namespaced only | Any resource |
| Binding | RoleBinding | ClusterRoleBinding or RoleBinding |
| Use Case | Team access in namespace | Platform/admin access |

### When to Use ClusterRole

✅ **Use ClusterRole for:**
- Access to cluster-scoped resources (nodes, PVs, namespaces)
- Cross-namespace access (view pods in all namespaces)
- Platform team / admin roles
- Monitoring / security teams

❌ **Don't use ClusterRole for:**
- Team-specific access within one namespace (use Role)
- When namespace isolation is critical

## Lab Structure

```
lab02-rbac-advanced/
├── README.md
├── QUICK-REFERENCE.md
├── manifests/
│   ├── cluster-admin-role.yaml
│   ├── cluster-admin-binding.yaml
│   ├── cluster-viewer-role.yaml
│   ├── cluster-viewer-binding.yaml
│   ├── node-reader-role.yaml
│   ├── node-reader-binding.yaml
│   └── aggregated-monitoring-role.yaml
├── scripts/
│   ├── setup.sh
│   ├── test.sh
│   └── cleanup.sh
└── solutions/
    └── SOLUTION.md
```

---

## Tasks

### Task 1: Create Service Accounts for Different Teams (5 min)

**Objective:** Set up service accounts representing different teams.

```bash
# Create namespaces for testing
kubectl create namespace prod
kubectl create namespace staging

# Platform team (needs cluster-wide access)
kubectl create serviceaccount platform-admin -n kube-system

# Security team (read-only across cluster)
kubectl create serviceaccount security-viewer -n kube-system

# Monitoring team (metrics and logs)
kubectl create serviceaccount monitoring-user -n kube-system

# Developer (namespace access + node viewing)
kubectl create serviceaccount developer -n prod
```

**Verify:**
```bash
kubectl get sa -n kube-system | grep -E 'platform|security|monitoring'
kubectl get sa -n prod
```

---

### Task 2: Create ClusterRole for Platform Admin (10 min)

**Objective:** Grant full cluster access to platform team.

Create `manifests/cluster-admin-role.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: platform-admin
rules:
# Full access to all resources in all namespaces
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
# Full access to cluster-scoped resources
- nonResourceURLs: ["*"]
  verbs: ["*"]
```

Create `manifests/cluster-admin-binding.yaml`:

```yaml
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
```

**Apply:**
```bash
kubectl apply -f manifests/cluster-admin-role.yaml
kubectl apply -f manifests/cluster-admin-binding.yaml
```

**Verify:**
```bash
# Platform admin should be able to do everything
kubectl auth can-i '*' '*' --as=system:serviceaccount:kube-system:platform-admin
# Should return: yes

kubectl auth can-i get nodes --as=system:serviceaccount:kube-system:platform-admin
# Should return: yes

kubectl auth can-i delete namespaces --as=system:serviceaccount:kube-system:platform-admin
# Should return: yes
```

**Production Note:** In real environments, avoid using wildcards (`*`). Use explicit permissions even for admin roles for auditability.

---

### Task 3: Create ClusterRole for Security Viewer (10 min)

**Objective:** Grant read-only access across entire cluster.

Create `manifests/cluster-viewer-role.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: security-viewer
rules:
# Read access to all namespaced resources
- apiGroups: [""]
  resources:
    - pods
    - services
    - configmaps
    - secrets
    - persistentvolumeclaims
    - serviceaccounts
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources:
    - deployments
    - replicasets
    - statefulsets
    - daemonsets
  verbs: ["get", "list", "watch"]
- apiGroups: ["batch"]
  resources:
    - jobs
    - cronjobs
  verbs: ["get", "list", "watch"]
- apiGroups: ["networking.k8s.io"]
  resources:
    - ingresses
    - networkpolicies
  verbs: ["get", "list", "watch"]
# Read access to cluster-scoped resources
- apiGroups: [""]
  resources:
    - nodes
    - persistentvolumes
    - namespaces
  verbs: ["get", "list", "watch"]
- apiGroups: ["rbac.authorization.k8s.io"]
  resources:
    - roles
    - rolebindings
    - clusterroles
    - clusterrolebindings
  verbs: ["get", "list", "watch"]
# Read pod logs
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get", "list"]
```

Create `manifests/cluster-viewer-binding.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: security-viewer-binding
subjects:
- kind: ServiceAccount
  name: security-viewer
  namespace: kube-system
roleRef:
  kind: ClusterRole
  name: security-viewer
  apiGroup: rbac.authorization.k8s.io
```

**Apply:**
```bash
kubectl apply -f manifests/cluster-viewer-role.yaml
kubectl apply -f manifests/cluster-viewer-binding.yaml
```

**Verify:**
```bash
# Security viewer can read
kubectl auth can-i get pods --all-namespaces --as=system:serviceaccount:kube-system:security-viewer
# Should return: yes

kubectl auth can-i get secrets -n prod --as=system:serviceaccount:kube-system:security-viewer
# Should return: yes

kubectl auth can-i get nodes --as=system:serviceaccount:kube-system:security-viewer
# Should return: yes

# But cannot write
kubectl auth can-i create pods --as=system:serviceaccount:kube-system:security-viewer
# Should return: no

kubectl auth can-i delete deployments -n prod --as=system:serviceaccount:kube-system:security-viewer
# Should return: no
```

---

### Task 4: Create ClusterRole for Node Reader (8 min)

**Objective:** Allow developers to view nodes (for capacity planning) without namespace access.

Create `manifests/node-reader-role.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: node-reader
rules:
# Read access to nodes only
- apiGroups: [""]
  resources:
    - nodes
  verbs: ["get", "list", "watch"]
# Read node metrics (if metrics-server is installed)
- apiGroups: ["metrics.k8s.io"]
  resources:
    - nodes
  verbs: ["get", "list"]
```

**Important:** We'll use RoleBinding (not ClusterRoleBinding) to bind this ClusterRole to developer in prod namespace only.

Create `manifests/node-reader-binding.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developer-node-reader
  namespace: prod
subjects:
- kind: ServiceAccount
  name: developer
  namespace: prod
roleRef:
  kind: ClusterRole  # Note: ClusterRole, not Role!
  name: node-reader
  apiGroup: rbac.authorization.k8s.io
```

**Apply:**
```bash
kubectl apply -f manifests/node-reader-role.yaml
kubectl apply -f manifests/node-reader-binding.yaml
```

**Verify:**
```bash
# Developer can view nodes (cluster-scoped)
kubectl auth can-i get nodes --as=system:serviceaccount:prod:developer
# Should return: yes

# But cannot access pods in prod namespace (no namespace permissions)
kubectl auth can-i get pods -n prod --as=system:serviceaccount:prod:developer
# Should return: no

# Cannot access other cluster resources
kubectl auth can-i get namespaces --as=system:serviceaccount:prod:developer
# Should return: no
```

**Key Learning:** You can bind a ClusterRole with a RoleBinding! This gives cluster-scoped resource access without granting namespace access.

---

### Task 5: Aggregated ClusterRole (Advanced - 7 min)

**Objective:** Create a monitoring role that aggregates multiple permissions using label selectors.

Create `manifests/aggregated-monitoring-role.yaml`:

```yaml
# Base monitoring role (will aggregate others)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: monitoring-aggregated
aggregationRule:
  clusterRoleSelectors:
  - matchLabels:
      rbac.authorization.k8s.io/aggregate-to-monitoring: "true"
rules: [] # Permissions come from aggregated roles

---
# Metrics permissions
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: monitoring-metrics
  labels:
    rbac.authorization.k8s.io/aggregate-to-monitoring: "true"
rules:
- apiGroups: [""]
  resources:
    - pods
    - nodes
  verbs: ["get", "list"]
- apiGroups: ["metrics.k8s.io"]
  resources:
    - pods
    - nodes
  verbs: ["get", "list"]

---
# Logs permissions
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: monitoring-logs
  labels:
    rbac.authorization.k8s.io/aggregate-to-monitoring: "true"
rules:
- apiGroups: [""]
  resources:
    - pods/log
  verbs: ["get", "list"]

---
# Events permissions
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: monitoring-events
  labels:
    rbac.authorization.k8s.io/aggregate-to-monitoring: "true"
rules:
- apiGroups: [""]
  resources:
    - events
  verbs: ["get", "list", "watch"]

---
# Bind to monitoring user
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: monitoring-user-binding
subjects:
- kind: ServiceAccount
  name: monitoring-user
  namespace: kube-system
roleRef:
  kind: ClusterRole
  name: monitoring-aggregated
  apiGroup: rbac.authorization.k8s.io
```

**Apply:**
```bash
kubectl apply -f manifests/aggregated-monitoring-role.yaml
```

**Verify:**
```bash
# Check aggregated permissions
kubectl describe clusterrole monitoring-aggregated

# Test permissions
kubectl auth can-i get pods --as=system:serviceaccount:kube-system:monitoring-user --all-namespaces
# Should return: yes

kubectl auth can-i get pods/log --as=system:serviceaccount:kube-system:monitoring-user --all-namespaces
# Should return: yes

kubectl auth can-i get events --as=system:serviceaccount:kube-system:monitoring-user --all-namespaces
# Should return: yes
```

**Why Aggregation?**
- Modular permissions (add/remove components)
- Reusable across teams
- Easier to maintain than monolithic roles
- Kubernetes uses this for built-in roles (view, edit, admin)

---

## Validation Checklist

Use this checklist to verify your lab completion:

**Service Accounts:**
- [ ] platform-admin exists in kube-system
- [ ] security-viewer exists in kube-system
- [ ] monitoring-user exists in kube-system
- [ ] developer exists in prod namespace

**ClusterRoles:**
- [ ] platform-admin ClusterRole with full access
- [ ] security-viewer ClusterRole with read-only
- [ ] node-reader ClusterRole
- [ ] monitoring-aggregated ClusterRole

**Bindings:**
- [ ] platform-admin-binding (ClusterRoleBinding)
- [ ] security-viewer-binding (ClusterRoleBinding)
- [ ] developer-node-reader (RoleBinding with ClusterRole)
- [ ] monitoring-user-binding (ClusterRoleBinding)

**Permissions Tests:**
- [ ] Platform admin can do everything ✅
- [ ] Security viewer can read everything ✅
- [ ] Security viewer cannot write ❌
- [ ] Developer can view nodes ✅
- [ ] Developer cannot view pods in prod ❌
- [ ] Monitoring user has aggregated permissions ✅

---

## Common Mistakes & Troubleshooting

### Mistake 1: Confusing RoleBinding vs ClusterRoleBinding

```bash
# ❌ Wrong - RoleBinding for cluster-scoped resource access across all namespaces
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: viewer-binding
  namespace: prod  # Only applies to prod!

# ✅ Correct - ClusterRoleBinding for cluster-wide access
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: viewer-binding
# No namespace - applies everywhere
```

### Mistake 2: Forgetting namespace in ServiceAccount subject

```yaml
# ❌ Wrong - missing namespace
subjects:
- kind: ServiceAccount
  name: platform-admin

# ✅ Correct
subjects:
- kind: ServiceAccount
  name: platform-admin
  namespace: kube-system
```

### Mistake 3: Not understanding ClusterRole + RoleBinding

```bash
# This is VALID and useful!
# ClusterRole: defines cluster-scoped permissions (nodes)
# RoleBinding: limits WHO gets it (only developer in prod)

kubectl create clusterrole node-reader --verb=get --resource=nodes
kubectl create rolebinding dev-nodes \
  --clusterrole=node-reader \
  --serviceaccount=prod:developer \
  -n prod
```

### Debugging Commands

```bash
# View all ClusterRoles
kubectl get clusterrole

# View all ClusterRoleBindings
kubectl get clusterrolebinding

# Check what a user can do cluster-wide
kubectl auth can-i --list --as=system:serviceaccount:kube-system:security-viewer

# Check specific permission
kubectl auth can-i get nodes --as=system:serviceaccount:prod:developer

# Describe ClusterRole to see rules
kubectl describe clusterrole security-viewer

# Check aggregated role
kubectl describe clusterrole monitoring-aggregated
```

---

## Cleanup

```bash
# Delete all resources created in this lab
kubectl delete namespace prod staging
kubectl delete sa platform-admin security-viewer monitoring-user -n kube-system
kubectl delete clusterrole platform-admin security-viewer node-reader monitoring-aggregated monitoring-metrics monitoring-logs monitoring-events
kubectl delete clusterrolebinding platform-admin-binding security-viewer-binding monitoring-user-binding
kubectl delete rolebinding developer-node-reader -n prod
```

Or use the cleanup script:
```bash
./scripts/cleanup.sh
```

---

## Exam Tips

⏱️ **Time Management:**
- ClusterRole creation: 2-3 minutes
- ClusterRoleBinding: 1 minute
- Verification: 1 minute
- Total: 4-5 minutes

🔑 **Quick Commands (Exam Speed):**

```bash
# Create ClusterRole (basic)
kubectl create clusterrole pod-reader \
  --verb=get,list \
  --resource=pods

# Create ClusterRoleBinding
kubectl create clusterrolebinding reader-binding \
  --clusterrole=pod-reader \
  --serviceaccount=default:reader

# Verify cluster-wide
kubectl auth can-i get pods --all-namespaces \
  --as=system:serviceaccount:default:reader

# ClusterRole + RoleBinding pattern
kubectl create rolebinding dev-clusterrole \
  --clusterrole=view \
  --serviceaccount=dev:developer \
  -n dev
```

📖 **Documentation Reference (Allowed in Exam):**
- ClusterRole: Search "ClusterRole example" on kubernetes.io/docs
- Aggregation: Search "aggregated ClusterRole"

🎯 **Exam Question Patterns:**

> *"Create a ClusterRole 'pod-viewer' that allows viewing pods cluster-wide. Bind it to serviceaccount 'viewer' in namespace 'monitoring'."*

> *"Grant user 'admin@example.com' cluster-admin privileges."*

> *"Create a read-only role for all resources across all namespaces."*

---

## Production Notes from Real Enterprise

**At our pharmaceutical company (8+ AKS clusters):**

1. **Platform Team:** Has cluster-admin via Azure AD group
2. **Security Team:** Read-only ClusterRole for SOC2 auditing
3. **Developers:** Namespace-specific Roles + node-reader ClusterRole
4. **CI/CD:** Limited ClusterRole for deployment management
5. **Monitoring (Prometheus):** Aggregated ClusterRole for metrics/logs

**RBAC Hierarchy Pattern:**
```
cluster-admin (Emergency only, MFA required)
    ↓
platform-admin (Platform team, daily ops)
    ↓
namespace-admin (Team leads per namespace)
    ↓
developer (Team members, CRUD in namespace)
    ↓
viewer (Read-only, external auditors)
```

See [DIAGRAMS.md](DIAGRAMS.md) for visual explanations!

**Common Production ClusterRoles:**
- `cluster-reader` - Security/audit teams
- `node-manager` - Infrastructure team
- `namespace-creator` - Platform automation
- `pv-manager` - Storage admins
- `cert-manager` - Certificate automation

---

## Going Deeper (Post-Lab Reading)

**Advanced RBAC Topics:**
1. **User vs Group vs ServiceAccount** - When to use each
2. **Impersonation** - `--as` and `--as-group` flags
3. **Admission Controllers** - PodSecurityPolicy, OPA
4. **RBAC + Network Policy** - Defense in depth
5. **Azure AD Integration** - Cloud identity providers

**Built-in ClusterRoles to Study:**
```bash
kubectl get clusterrole view -o yaml
kubectl get clusterrole edit -o yaml
kubectl get clusterrole admin -o yaml
kubectl get clusterrole cluster-admin -o yaml
```

---

## Next Lab

Ready for the next topic? Move to **[Lab 03: kubeadm Cluster Installation](../03-kubeadm-install/README.md)**

In Lab 03, you'll learn:
- Install Kubernetes from scratch with kubeadm
- Configure control plane and worker nodes
- Understand cluster components
- Prepare for cluster lifecycle questions (25% of exam!)

---

**Author:** Shamsher Khan | **Blog:** opscart.com | **Course:** Production CKA 2026