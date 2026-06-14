# Lab 13: Service Accounts - Quick Reference

## Core Commands

```bash
# Create service account
kubectl create serviceaccount my-sa -n my-namespace

# List service accounts
kubectl get serviceaccount -n my-namespace

# Describe service account
kubectl describe serviceaccount my-sa -n my-namespace

# Generate token
kubectl create token my-sa -n my-namespace
kubectl create token my-sa -n my-namespace --duration=3600s
```

---

## Bind SA to Role

```bash
# Create RoleBinding for SA
kubectl create rolebinding my-binding \
  --role=my-role \
  --serviceaccount=my-namespace:my-sa \
  -n my-namespace

# Create ClusterRoleBinding for SA
kubectl create clusterrolebinding my-binding \
  --clusterrole=view \
  --serviceaccount=my-namespace:my-sa
```

---

## Use SA in Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
  namespace: my-namespace
spec:
  serviceAccountName: my-sa   # ← specify SA here
  containers:
  - name: app
    image: nginx
```

---

## Disable Token Automount

```yaml
# On ServiceAccount (affects all pods using it)
apiVersion: v1
kind: ServiceAccount
metadata:
  name: restricted-sa
  namespace: my-namespace
automountServiceAccountToken: false

# On Pod (overrides SA setting)
spec:
  automountServiceAccountToken: false
```

---

## Token Locations in Pod

```bash
# Mounted at:
/var/run/secrets/kubernetes.io/serviceaccount/token      # JWT token
/var/run/secrets/kubernetes.io/serviceaccount/ca.crt     # CA cert
/var/run/secrets/kubernetes.io/serviceaccount/namespace  # namespace name

# Use token to call API
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
curl -H "Authorization: Bearer $TOKEN" \
     --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
     https://kubernetes.default.svc/api/v1/namespaces/default/pods
```

---

## Check SA Permissions

```bash
# Can SA list pods?
kubectl auth can-i list pods \
  --as=system:serviceaccount:my-namespace:my-sa \
  -n my-namespace

# Can SA create deployments?
kubectl auth can-i create deployments \
  --as=system:serviceaccount:my-namespace:my-sa \
  -n my-namespace
```

---

## Long-lived Token (Legacy)

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-sa-token
  namespace: my-namespace
  annotations:
    kubernetes.io/service-account.name: my-sa
type: kubernetes.io/service-account-token
```

---

## Exam Scenarios

### Create SA with permissions
```bash
kubectl create serviceaccount deploy-sa -n production
kubectl create rolebinding deploy-binding \
  --role=deployment-manager \
  --serviceaccount=production:deploy-sa \
  -n production
```

### Create pod using SA
```yaml
spec:
  serviceAccountName: deploy-sa
```

### Disable automount
```bash
kubectl patch serviceaccount my-sa -n my-namespace \
  -p '{"automountServiceAccountToken": false}'
```

### Generate expiring token
```bash
kubectl create token my-sa -n my-namespace --duration=3600s
```

---

## Key Facts

- Every namespace has a `default` SA automatically
- Pods use `default` SA if none specified
- SA tokens are auto-mounted at `/var/run/secrets/...`
- Use `automountServiceAccountToken: false` for security
- SA format for `--as` flag: `system:serviceaccount:<namespace>:<name>`
- Tokens generated with `kubectl create token` are short-lived (1 hour default)

---

## Time Budget (Exam)

- Create SA: **30 seconds**
- Create Role + RoleBinding: **2 minutes**
- Create pod with SA: **1 minute**
- Verify: **30 seconds**
- **Total: ~4-5 minutes**