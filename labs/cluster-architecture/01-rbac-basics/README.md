# Lab 01: RBAC Basics - Role-Based Access Control

## Objective
Master Kubernetes RBAC fundamentals by creating roles, service accounts, and role bindings to implement least-privilege access control.

## CKA Exam Relevance
- **Domain:** Cluster Architecture, Installation & Configuration (25%)
- **Topic:** Manage role based access control (RBAC)
- **Exam Weight:** High (appears in 80%+ of exams)
- **Typical Exam Time:** 5-7 minutes

## Time to Complete
30 minutes

## Scenario
You're the Kubernetes administrator at a pharmaceutical company. The development team needs restricted access to deploy applications in the `dev` namespace, but they should NOT be able to:
- Delete deployments (prevents accidental production-like deletions)
- Access secrets (contains sensitive API keys and credentials)
- Access other namespaces

This mirrors real compliance requirements in regulated industries.

## Prerequisites
- Minikube cluster running (3 nodes)
- kubectl configured and working
- Basic understanding of pods, deployments, and namespaces

## Lab Structure

```
lab01-rbac-basics/
├── README.md              # This file
├── manifests/
│   ├── dev-role.yaml      # Role definition
│   └── dev-rolebinding.yaml  # RoleBinding
├── scripts/
│   ├── setup.sh           # Setup script
│   ├── test.sh            # Validation script
│   └── cleanup.sh         # Cleanup script
└── solutions/
    └── SOLUTION.md        # Step-by-step solution
```

## Tasks

### Task 1: Create Namespace and Service Account (5 min)

**Objective:** Set up isolated namespace for dev team with dedicated service account.

```bash
# Create development namespace
kubectl create namespace dev

# Create service account for dev team
kubectl create serviceaccount dev-user -n dev

# Verify creation
kubectl get sa -n dev
kubectl get namespace dev
```

**Expected Output:**
```
NAME       SECRETS   AGE
default    0         10s
dev-user   0         5s
```

**Why this matters:** In production, each team gets isolated namespaces with service accounts that can be mapped to cloud identity providers (Azure AD, AWS IAM, etc.).

---

### Task 2: Create Role with Limited Permissions (10 min)

**Objective:** Define fine-grained permissions that allow development work but prevent dangerous operations.

Create `manifests/dev-role.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: dev
  name: dev-role
rules:
# Allow full access to pods
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
# Allow read and create/update deployments, but NOT delete
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
# Allow viewing deployment replica sets
- apiGroups: ["apps"]
  resources: ["replicasets"]
  verbs: ["get", "list", "watch"]
# Allow reading pod logs
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get", "list"]
# Allow viewing services
- apiGroups: [""]
  resources: ["services"]
  verbs: ["get", "list", "watch"]
```

Apply the role:

```bash
kubectl apply -f manifests/dev-role.yaml

# Verify
kubectl get role -n dev
kubectl describe role dev-role -n dev
```

**Key Points:**
- `apiGroups: [""]` = core API group (pods, services, configmaps)
- `apiGroups: ["apps"]` = apps API group (deployments, statefulsets)
- Notice: `delete` verb is ONLY on pods, NOT on deployments

---

### Task 3: Bind Role to Service Account (5 min)

**Objective:** Connect the role to the service account, activating the permissions.

Create `manifests/dev-rolebinding.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: dev-rolebinding
  namespace: dev
subjects:
# Who gets the permissions
- kind: ServiceAccount
  name: dev-user
  namespace: dev
roleRef:
  # What permissions they get
  kind: Role
  name: dev-role
  apiGroup: rbac.authorization.k8s.io
```

Apply the binding:

```bash
kubectl apply -f manifests/dev-rolebinding.yaml

# Verify
kubectl get rolebinding -n dev
kubectl describe rolebinding dev-rolebinding -n dev
```

**Expected Output:**
```
Name:         dev-rolebinding
Namespace:    dev
Role:
  Kind:  Role
  Name:  dev-role
Subjects:
  Kind            Name      Namespace
  ----            ----      ---------
  ServiceAccount  dev-user  dev
```

---

### Task 4: Test Permissions - Positive Tests (5 min)

**Objective:** Verify that allowed operations work correctly.

```bash
# Test 1: Can we view pods? (Should succeed)
kubectl auth can-i get pods --as=system:serviceaccount:dev:dev-user -n dev

# Test 2: Can we create pods? (Should succeed)
kubectl auth can-i create pods --as=system:serviceaccount:dev:dev-user -n dev

# Test 3: Can we view deployments? (Should succeed)
kubectl auth can-i get deployments --as=system:serviceaccount:dev:dev-user -n dev

# Test 4: Can we create deployments? (Should succeed)
kubectl auth can-i create deployments --as=system:serviceaccount:dev:dev-user -n dev

# Test 5: Can we view logs? (Should succeed)
kubectl auth can-i get pods/log --as=system:serviceaccount:dev:dev-user -n dev
```

**All should return:** `yes`

---

### Task 5: Test Permissions - Negative Tests (5 min)

**Objective:** Verify that denied operations are properly blocked.

```bash
# Test 1: Can we delete deployments? (Should FAIL - not in our role)
kubectl auth can-i delete deployments --as=system:serviceaccount:dev:dev-user -n dev

# Test 2: Can we view secrets? (Should FAIL - not in our role)
kubectl auth can-i get secrets --as=system:serviceaccount:dev:dev-user -n dev

# Test 3: Can we create secrets? (Should FAIL)
kubectl auth can-i create secrets --as=system:serviceaccount:dev:dev-user -n dev

# Test 4: Can we access nodes? (Should FAIL - cluster-scoped resource)
kubectl auth can-i get nodes --as=system:serviceaccount:dev:dev-user

# Test 5: Can we access another namespace? (Should FAIL - role is namespace-scoped)
kubectl auth can-i get pods --as=system:serviceaccount:dev:dev-user -n default
```

**All should return:** `no`

---

### Task 6: Real-World Test (Bonus - 5 min)

**Objective:** Simulate actual developer workflow.

```bash
# 1. Create a deployment as the dev-user
kubectl create deployment nginx --image=nginx --replicas=2 -n dev

# 2. Try to view it (should work)
kubectl get deployments -n dev

# 3. Try to scale it (should work - update is allowed)
kubectl scale deployment nginx --replicas=3 -n dev

# 4. Try to delete it (should fail)
kubectl delete deployment nginx -n dev --as=system:serviceaccount:dev:dev-user

# Expected error:
# Error from server (Forbidden): deployments.apps "nginx" is forbidden: 
# User "system:serviceaccount:dev:dev-user" cannot delete resource "deployments"
```

---

## Validation Checklist

Use this checklist to verify your lab completion:

- [ ] Namespace `dev` exists
- [ ] ServiceAccount `dev-user` exists in `dev` namespace
- [ ] Role `dev-role` exists with correct permissions
- [ ] RoleBinding `dev-rolebinding` connects role to service account
- [ ] Can get/create pods ✅
- [ ] Can get/create deployments ✅
- [ ] Cannot delete deployments ❌
- [ ] Cannot access secrets ❌
- [ ] Cannot access other namespaces ❌

---

## Common Mistakes & Troubleshooting

### Mistake 1: Wrong namespace in commands
```bash
# ❌ Wrong - checks default namespace
kubectl get role dev-role

# ✅ Correct - specifies namespace
kubectl get role dev-role -n dev
```

### Mistake 2: Forgot apiGroups
```yaml
# ❌ Wrong - missing apiGroup for deployments
- resources: ["deployments"]
  verbs: ["get"]

# ✅ Correct - includes apps apiGroup
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get"]
```

### Mistake 3: Typo in verbs
```yaml
# ❌ Wrong - "lists" is not a valid verb
verbs: ["get", "lists"]

# ✅ Correct - use "list" (singular)
verbs: ["get", "list"]
```

### Mistake 4: RoleBinding subject mismatch
```yaml
# ❌ Wrong - typo in service account name
subjects:
- kind: ServiceAccount
  name: dev-users  # Wrong!

# ✅ Correct - exact match
subjects:
- kind: ServiceAccount
  name: dev-user
```

### Debugging Commands

```bash
# Check if role exists and its permissions
kubectl describe role dev-role -n dev

# Check if rolebinding is correct
kubectl describe rolebinding dev-rolebinding -n dev

# Check all permissions for a user
kubectl auth can-i --list --as=system:serviceaccount:dev:dev-user -n dev

# View RBAC denials in audit logs (if enabled)
kubectl logs -n kube-system -l component=kube-apiserver | grep RBAC
```

---

## Cleanup

```bash
# Delete everything created in this lab
kubectl delete namespace dev

# Or delete individual resources
kubectl delete role dev-role -n dev
kubectl delete rolebinding dev-rolebinding -n dev
kubectl delete serviceaccount dev-user -n dev
kubectl delete namespace dev
```

---

## Exam Tips

⏱️ **Time Management:**
- Should complete RBAC tasks in 5-7 minutes during exam
- Use imperative commands for speed (see below)
- Only use YAML for complex permissions

🔑 **Quick Commands (Exam Speed Tricks):**

```bash
# Generate role YAML quickly
kubectl create role dev-role \
  --verb=get,list,watch,create \
  --resource=pods,deployments \
  -n dev \
  --dry-run=client -o yaml > role.yaml

# Generate rolebinding YAML
kubectl create rolebinding dev-binding \
  --role=dev-role \
  --serviceaccount=dev:dev-user \
  -n dev \
  --dry-run=client -o yaml > binding.yaml

# Quick validation
kubectl auth can-i get pods --as=system:serviceaccount:dev:dev-user -n dev
```

📖 **Documentation Reference (Allowed in Exam):**
- https://kubernetes.io/docs/reference/access-authn-authz/rbac/
- Search tip: Use Ctrl+F for "Role" and "RoleBinding" examples

🎯 **What Exam Questions Look Like:**

> *"Create a serviceaccount named 'developer' in namespace 'production'. Create a role named 'dev-role' that allows get, list, watch on pods and deployments. Bind the role to the serviceaccount."*

---

## Production Notes from Real Enterprise Experience

**At our pharmaceutical company with 8+ production clusters:**

1. **Namespace Isolation:** Each team (Clinical Trials, Manufacturing, Supply Chain) gets isolated namespaces with strict RBAC
2. **No Direct Delete:** Developers can't delete deployments in production - only update via CI/CD
3. **Secrets Access:** Secrets access is audited and requires justification (FDA compliance)
4. **ServiceAccount Mapping:** ServiceAccounts are mapped to Azure AD groups for SSO
5. **Regular Audits:** We run quarterly audits using `kubectl auth can-i` matrix across all service accounts
6. **Break Glass:** Admin team has ClusterRole for emergency access (MFA required)

**Common Production RBAC Patterns:**
- Read-only role for monitoring teams
- CI/CD role for automated deployments
- DBA role with special PVC permissions
- Security team role for scanning/auditing

---

## Going Deeper (Post-Lab Reading)

**Want to master RBAC?**

1. **ClusterRole vs Role:** Learn the difference (next lab!)
2. **Aggregated ClusterRoles:** Advanced permission composition
3. **RBAC Testing Tools:** Use `kubectl-who-can` plugin
4. **Audit Logging:** Track who did what in your cluster
5. **Service Account Tokens:** How they work and security implications

**Related CKA Topics:**
- Lab 02: ClusterRole and ClusterRoleBinding
- Lab 03: Service Account Token Management
- Lab 17: Certificate-based Authentication

---

## Next Lab

Ready to level up? Move to **[Lab 02: RBAC Advanced - ClusterRoles and Aggregation](../lab02-rbac-advanced/README.md)**

In Lab 02, you'll learn:
- ClusterRole for cluster-wide permissions
- Aggregated ClusterRoles
- Group-based RBAC
- Real production RBAC hierarchy

---

## Feedback & Improvements

Found an issue or have suggestions? 
- Open an issue: https://github.com/opscart/production-cka/issues
- Contribute: PRs welcome!

---

**Author:** Shamsher Singh | **Blog:** opscart.com | **Course:** Production CKA 2026