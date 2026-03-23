# Lab 01: RBAC Basics - Solution Guide

## Quick Solution (For the Exam)

If you see this in the CKA exam:

> *"Create a serviceaccount named 'dev-user' in namespace 'dev'. Create a role named 'dev-role' that allows get, list, watch, create, update on pods and deployments. Bind the role to the serviceaccount."*

**Speed Solution (5 minutes):**

```bash
# 1. Create namespace (10 seconds)
kubectl create namespace dev

# 2. Create service account (10 seconds)
kubectl create serviceaccount dev-user -n dev

# 3. Create role (1 minute)
kubectl create role dev-role \
  --verb=get,list,watch,create,update,patch \
  --resource=pods,deployments \
  -n dev

# 4. Create rolebinding (30 seconds)
kubectl create rolebinding dev-rolebinding \
  --role=dev-role \
  --serviceaccount=dev:dev-user \
  -n dev

# 5. Verify (30 seconds)
kubectl auth can-i get pods --as=system:serviceaccount:dev:dev-user -n dev
kubectl auth can-i create deployments --as=system:serviceaccount:dev:dev-user -n dev
```

---

## Detailed Step-by-Step Solution

### Step 1: Create Namespace

```bash
kubectl create namespace dev
```

**Verify:**
```bash
kubectl get namespace dev
```

**Expected Output:**
```
NAME   STATUS   AGE
dev    Active   5s
```

---

### Step 2: Create Service Account

```bash
kubectl create serviceaccount dev-user -n dev
```

**Verify:**
```bash
kubectl get sa -n dev
kubectl describe sa dev-user -n dev
```

**Expected Output:**
```
Name:                dev-user
Namespace:           dev
Labels:              <none>
Annotations:         <none>
Image pull secrets:  <none>
Mountable secrets:   <none>
Tokens:              <none>
Events:              <none>
```

---

### Step 3: Create Role

**Method 1: Using YAML (More Control)**

```bash
cat > dev-role.yaml << 'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: dev
  name: dev-role
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
- apiGroups: ["apps"]
  resources: ["replicasets"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get", "list"]
- apiGroups: [""]
  resources: ["services"]
  verbs: ["get", "list", "watch"]
EOF

kubectl apply -f dev-role.yaml
```

**Method 2: Imperative (Faster for Exam)**

```bash
# This creates a basic role - you'd need to add more rules manually
kubectl create role dev-role \
  --verb=get,list,watch,create,update,patch \
  --resource=pods \
  --resource=deployments \
  -n dev
```

**Verify:**
```bash
kubectl get role -n dev
kubectl describe role dev-role -n dev
```

---

### Step 4: Create RoleBinding

**Method 1: Using YAML**

```bash
cat > dev-rolebinding.yaml << 'EOF'
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
EOF

kubectl apply -f dev-rolebinding.yaml
```

**Method 2: Imperative (Exam Speed)**

```bash
kubectl create rolebinding dev-rolebinding \
  --role=dev-role \
  --serviceaccount=dev:dev-user \
  -n dev
```

**Verify:**
```bash
kubectl get rolebinding -n dev
kubectl describe rolebinding dev-rolebinding -n dev
```

---

### Step 5: Test Permissions

**Positive Tests (Should return "yes"):**

```bash
# Can get pods?
kubectl auth can-i get pods \
  --as=system:serviceaccount:dev:dev-user \
  -n dev

# Can create deployments?
kubectl auth can-i create deployments \
  --as=system:serviceaccount:dev:dev-user \
  -n dev

# Can view logs?
kubectl auth can-i get pods/log \
  --as=system:serviceaccount:dev:dev-user \
  -n dev
```

**Negative Tests (Should return "no"):**

```bash
# Can delete deployments?
kubectl auth can-i delete deployments \
  --as=system:serviceaccount:dev:dev-user \
  -n dev

# Can access secrets?
kubectl auth can-i get secrets \
  --as=system:serviceaccount:dev:dev-user \
  -n dev
```

---

## Common Exam Variations

### Variation 1: Multiple Resources

> *"Create a role that allows get, list on pods, services, and configmaps"*

```bash
kubectl create role viewer-role \
  --verb=get,list \
  --resource=pods,services,configmaps \
  -n dev
```

### Variation 2: Specific Resource Names

> *"Create a role that allows update only on deployment named 'webapp'"*

```bash
cat > webapp-role.yaml << 'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: dev
  name: webapp-updater
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  resourceNames: ["webapp"]
  verbs: ["update", "patch"]
EOF

kubectl apply -f webapp-role.yaml
```

### Variation 3: Bind to User Instead of ServiceAccount

> *"Bind the role to user 'john@example.com'"*

```bash
kubectl create rolebinding john-binding \
  --role=dev-role \
  --user=john@example.com \
  -n dev
```

---

## Troubleshooting Common Issues

### Issue 1: "Role not found" when creating RoleBinding

**Problem:** Created Role in wrong namespace

**Solution:**
```bash
# Check which namespace the role is in
kubectl get role --all-namespaces | grep dev-role

# Delete and recreate in correct namespace
kubectl delete role dev-role -n wrong-namespace
kubectl create role dev-role -n dev ...
```

### Issue 2: Permissions not working

**Problem:** RoleBinding subject doesn't match ServiceAccount

**Solution:**
```bash
# Check the rolebinding
kubectl describe rolebinding dev-rolebinding -n dev

# Look for exact match:
# Subject: ServiceAccount/dev-user in namespace dev

# Fix if needed
kubectl delete rolebinding dev-rolebinding -n dev
kubectl create rolebinding dev-rolebinding \
  --role=dev-role \
  --serviceaccount=dev:dev-user \
  -n dev
```

### Issue 3: Can't test permissions

**Problem:** Wrong format for --as flag

**Correct Format:**
```bash
# For ServiceAccount
--as=system:serviceaccount:NAMESPACE:SA_NAME

# For User
--as=username@example.com

# For Group
--as-group=system:authenticated
```

---

## Exam Time-Saving Tips

### 1. Use Aliases
```bash
alias k=kubectl
alias kn='kubectl config set-context --current --namespace'

# Switch to dev namespace
kn dev

# Now you don't need -n dev in every command
k get pods
k create sa dev-user
```

### 2. Generate YAML, Then Edit
```bash
# Generate base YAML
kubectl create role dev-role \
  --verb=get \
  --resource=pods \
  -n dev \
  --dry-run=client -o yaml > role.yaml

# Edit to add more rules
vim role.yaml  # or nano role.yaml

# Apply
kubectl apply -f role.yaml
```

### 3. Use kubectl auth can-i with --list
```bash
# See all permissions for a user
kubectl auth can-i --list \
  --as=system:serviceaccount:dev:dev-user \
  -n dev
```

---

## What to Remember for the Exam

**Always specify namespace** for Roles and RoleBindings
**Use correct apiGroups**: `""` for core, `"apps"` for deployments
**ServiceAccount format** in --as: `system:serviceaccount:NAMESPACE:NAME`
**Verify immediately** with `kubectl auth can-i`
**RBAC is namespace-scoped** for Role/RoleBinding
**Use imperative commands** for speed when possible

---

## Next Steps

1. **Practice speed**: Can you complete this in under 5 minutes?
2. **Try variations**: Different resources, different verbs
3. **Move to Lab 02**: Learn ClusterRole for cluster-wide permissions
4. **Read docs**: Bookmark kubernetes.io/docs/reference/access-authn-authz/rbac/

---

## Automated Solution

Run these scripts in order:

```bash
# Setup entire lab
./scripts/setup.sh

# Validate everything
./scripts/test.sh

# Clean up when done
./scripts/cleanup.sh
```

---

**Completed Lab 01?** 

Move to **[Lab 02: RBAC Advanced](../lab02-rbac-advanced/)**