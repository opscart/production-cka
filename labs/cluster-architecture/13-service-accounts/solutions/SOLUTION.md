# Lab 13: Service Accounts - Solution Guide

## Run the Scripts
```bash
./scripts/setup.sh   # Creates SA, Role, RoleBinding, pods in lab13-sa
./scripts/test.sh    # 18/18 checks
./scripts/cleanup.sh
```

---

## Complete Manual Solution

### Step 1: Create Namespace and Service Account
```bash
kubectl create namespace lab13-sa
kubectl create serviceaccount monitoring-sa -n lab13-sa
```

### Step 2: Create Role with Permissions
```bash
kubectl apply -f - << 'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: monitoring-role
  namespace: lab13-sa
rules:
- apiGroups: [""]
  resources: ["pods", "services", "endpoints"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch"]
EOF
```

### Step 3: Bind Role to Service Account
```bash
kubectl apply -f - << 'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: monitoring-rolebinding
  namespace: lab13-sa
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: monitoring-role
subjects:
- kind: ServiceAccount
  name: monitoring-sa
  namespace: lab13-sa
EOF

# Or use imperative command:
kubectl create rolebinding monitoring-rolebinding \
  --role=monitoring-role \
  --serviceaccount=lab13-sa:monitoring-sa \
  -n lab13-sa
```

### Step 4: Create Pod Using SA
```bash
kubectl apply -f - << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: monitoring-pod
  namespace: lab13-sa
spec:
  serviceAccountName: monitoring-sa
  containers:
  - name: monitor
    image: nginx
    command: ["sleep", "3600"]
EOF
```

### Step 5: Verify Token Mounted
```bash
kubectl exec monitoring-pod -n lab13-sa -- \
  ls /var/run/secrets/kubernetes.io/serviceaccount/
# ca.crt  namespace  token

# View token
kubectl exec monitoring-pod -n lab13-sa -- \
  cat /var/run/secrets/kubernetes.io/serviceaccount/token
```

### Step 6: Test Permissions
```bash
# Should work
kubectl auth can-i list pods \
  --as=system:serviceaccount:lab13-sa:monitoring-sa \
  -n lab13-sa
# yes

# Should fail
kubectl auth can-i delete pods \
  --as=system:serviceaccount:lab13-sa:monitoring-sa \
  -n lab13-sa
# no

kubectl auth can-i list secrets \
  --as=system:serviceaccount:lab13-sa:monitoring-sa \
  -n lab13-sa
# no
```

### Step 7: Restricted SA (no token automount)
```bash
kubectl apply -f - << 'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: restricted-sa
  namespace: lab13-sa
automountServiceAccountToken: false
EOF

kubectl apply -f - << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: restricted-pod
  namespace: lab13-sa
spec:
  serviceAccountName: restricted-sa
  containers:
  - name: app
    image: nginx
    command: ["sleep", "3600"]
EOF

# Verify no token mounted
kubectl exec restricted-pod -n lab13-sa -- \
  ls /var/run/secrets/ 2>&1 || echo "No secrets - correct!"
```

### Step 8: Generate Token
```bash
# Short-lived (1 hour default)
kubectl create token monitoring-sa -n lab13-sa

# Custom duration
kubectl create token monitoring-sa -n lab13-sa --duration=3600s
```

---

## Key Takeaways

✅ Every namespace gets a `default` SA automatically
✅ Pods use `default` SA unless `serviceAccountName` is set
✅ SA tokens are auto-mounted at `/var/run/secrets/kubernetes.io/serviceaccount/`
✅ `automountServiceAccountToken: false` for security-sensitive workloads
✅ Use `system:serviceaccount:<ns>:<name>` format with `--as` flag
✅ `kubectl create token` generates short-lived tokens (Kubernetes 1.24+)
✅ SA permissions are namespace-scoped (use ClusterRoleBinding for cluster-wide)

---

**Completed Lab 13?** ✅

Move to **[Lab 14: CRDs and Operators](../14-crds-operators/)**