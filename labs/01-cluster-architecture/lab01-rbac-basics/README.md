# Lab 01: RBAC Basics - Role-Based Access Control

## Objective
Master Kubernetes RBAC fundamentals by creating roles, service accounts, and role bindings.

## CKA Exam Relevance
- **Domain:** Cluster Architecture, Installation & Configuration (25%)
- **Topic:** Manage role based access control (RBAC)
- **Exam Weight:** High (appears in 80%+ of exams)

## Time to Complete
30 minutes

## Scenario
You're the Kubernetes administrator at a pharmaceutical company. The development team needs restricted access to deploy applications in the `dev` namespace, but they should NOT be able to delete deployments or access secrets.

## Prerequisites
- Minikube cluster running (3 nodes)
- kubectl configured
- Basic understanding of pods and namespaces

## Tasks

### Task 1: Create Namespace and Service Account (5 min)
```bash
# Create development namespace
kubectl create namespace dev

# Create service account for dev team
kubectl create serviceaccount dev-user -n dev

# Verify
kubectl get sa -n dev
```

**Expected Output:**
```
NAME       SECRETS   AGE
default    0         10s
dev-user   0         5s
```

### Task 2: Create Role with Limited Permissions (10 min)

Create a Role that allows:
- ✅ Get, list, watch pods
- ✅ Get, list, watch deployments
- ✅ Create, update pods and deployments
- ❌ Delete deployments
- ❌ Access secrets
```bash
cat > dev-role.yaml << 'YAML'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: dev
  name: dev-role
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get", "list"]
YAML

kubectl apply -f dev-role.yaml
```

**Verify:**
```bash
kubectl get role -n dev
kubectl describe role dev-role -n dev
```

### Task 3: Bind Role to Service Account (5 min)
```bash
cat > dev-rolebinding.yaml << 'YAML'
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: dev-rolebinding
  namespace: dev
subjects:
- kind: ServiceAccount
  name: dev-user
  namespace: dev
roleRef:
  kind: Role
  name: dev-role
  apiGroup: rbac.authorization.k8s.io
YAML

kubectl apply -f dev-rolebinding.yaml
```

**Verify:**
```bash
kubectl get rolebinding -n dev
kubectl describe rolebinding dev-rolebinding -n dev
```

### Task 4: Test Permissions (10 min)

**Test allowed operations:**
```bash
# Create a test pod
kubectl run nginx --image=nginx -n dev

# Can we view pods? (Should succeed)
kubectl auth can-i get pods --as=system:serviceaccount:dev:dev-user -n dev

# Can we view deployments? (Should succeed)
kubectl auth can-i get deployments --as=system:serviceaccount:dev:dev-user -n dev

# Can we create deployments? (Should succeed)
kubectl auth can-i create deployments --as=system:serviceaccount:dev:dev-user -n dev
```

**Test denied operations:**
```bash
# Can we delete deployments? (Should fail)
kubectl auth can-i delete deployments --as=system:serviceaccount:dev:dev-user -n dev

# Can we view secrets? (Should fail)
kubectl auth can-i get secrets --as=system:serviceaccount:dev:dev-user -n dev

# Can we access nodes? (Should fail - not in our namespace)
kubectl auth can-i get nodes --as=system:serviceaccount:dev:dev-user
```

**Expected Results:**
```
get pods: yes
get deployments: yes
create deployments: yes
delete deployments: no
get secrets: no
get nodes: no
```

## Validation

Run the validation script:
```bash
# All should return 'yes'
kubectl auth can-i get pods --as=system:serviceaccount:dev:dev-user -n dev
kubectl auth can-i create deployments --as=system:serviceaccount:dev:dev-user -n dev

# All should return 'no'
kubectl auth can-i delete deployments --as=system:serviceaccount:dev:dev-user -n dev
kubectl auth can-i get secrets --as=system:serviceaccount:dev:dev-user -n dev
```

## Common Mistakes

1. **Wrong namespace** - RBAC is namespace-scoped for Roles
2. **Forgot apiGroups** - `apps` for deployments, `""` for core resources
3. **Typo in verbs** - Use exact: `get`, `list`, `watch`, `create`, etc.
4. **RoleBinding subject mismatch** - ServiceAccount name must match exactly

## Cleanup
```bash
kubectl delete namespace dev
rm dev-role.yaml dev-rolebinding.yaml
```

## Exam Tips

⏱️ **Time Management:** Should complete RBAC tasks in 5-7 minutes during exam

🔑 **Quick Commands:**
```bash
# Generate role YAML quickly
kubectl create role dev-role --verb=get,list --resource=pods --dry-run=client -o yaml > role.yaml

# Generate rolebinding YAML
kubectl create rolebinding dev-binding --role=dev-role --serviceaccount=dev:dev-user --dry-run=client -o yaml > binding.yaml
```

📖 **Doc Reference:** https://kubernetes.io/docs/reference/access-authn-authz/rbac/

## Production Notes

In our pharmaceutical production environment:
- Each team has dedicated namespaces
- ServiceAccounts tied to Azure AD groups
- Secrets access is heavily restricted (compliance)
- All RBAC changes require peer review
- Regular audits using `kubectl auth can-i` matrix

## Next Lab

[Lab 02: RBAC Advanced - ClusterRoles](../lab02-rbac-advanced/README.md)
