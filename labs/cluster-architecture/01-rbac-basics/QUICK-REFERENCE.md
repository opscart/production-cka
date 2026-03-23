# Lab 01: RBAC Quick Reference Card

## Exam Cheat Sheet (2 minutes read)

### Common RBAC Commands

```bash
# Create namespace
kubectl create namespace <name>

# Create service account
kubectl create serviceaccount <name> -n <namespace>

# Create role (basic)
kubectl create role <role-name> \
  --verb=get,list,watch \
  --resource=pods \
  -n <namespace>

# Create rolebinding (to ServiceAccount)
kubectl create rolebinding <binding-name> \
  --role=<role-name> \
  --serviceaccount=<namespace>:<sa-name> \
  -n <namespace>

# Create rolebinding (to User)
kubectl create rolebinding <binding-name> \
  --role=<role-name> \
  --user=<username> \
  -n <namespace>

# Test permissions
kubectl auth can-i <verb> <resource> \
  --as=system:serviceaccount:<namespace>:<sa-name> \
  -n <namespace>

# List all permissions
kubectl auth can-i --list \
  --as=system:serviceaccount:<namespace>:<sa-name> \
  -n <namespace>
```

---

## API Groups Reference

| Resource | API Group | Example |
|----------|-----------|---------|
| pods | `""` (core) | `apiGroups: [""]` |
| services | `""` (core) | `apiGroups: [""]` |
| configmaps | `""` (core) | `apiGroups: [""]` |
| secrets | `""` (core) | `apiGroups: [""]` |
| deployments | `apps` | `apiGroups: ["apps"]` |
| replicasets | `apps` | `apiGroups: ["apps"]` |
| statefulsets | `apps` | `apiGroups: ["apps"]` |
| daemonsets | `apps` | `apiGroups: ["apps"]` |
| jobs | `batch` | `apiGroups: ["batch"]` |
| cronjobs | `batch` | `apiGroups: ["batch"]` |
| ingresses | `networking.k8s.io` | `apiGroups: ["networking.k8s.io"]` |
| networkpolicies | `networking.k8s.io` | `apiGroups: ["networking.k8s.io"]` |

---

## Common Verbs

| Verb | Meaning |
|------|---------|
| `get` | Read single resource |
| `list` | List all resources |
| `watch` | Watch for changes |
| `create` | Create new resource |
| `update` | Update existing resource |
| `patch` | Patch existing resource |
| `delete` | Delete resource |
| `deletecollection` | Delete multiple resources |
| `*` | All verbs (use carefully!) |

---

## Role vs ClusterRole

| Feature | Role | ClusterRole |
|---------|------|-------------|
| Scope | Namespace | Cluster-wide |
| Resources | Namespaced resources | All resources |
| Binding | RoleBinding | ClusterRoleBinding |
| Example Use | Dev team in 'dev' namespace | Cluster admin |

---

## Quick YAML Templates

### Role Template
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: NAMESPACE
  name: ROLE-NAME
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
```

### RoleBinding Template
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: BINDING-NAME
  namespace: NAMESPACE
subjects:
- kind: ServiceAccount
  name: SA-NAME
  namespace: NAMESPACE
roleRef:
  kind: Role
  name: ROLE-NAME
  apiGroup: rbac.authorization.k8s.io
```

---

## Common Exam Scenarios

### Read-only access to pods
```bash
kubectl create role pod-reader \
  --verb=get,list,watch \
  --resource=pods \
  -n dev
```

### Full access to deployments (except delete)
```yaml
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
```

### Access to specific deployment
```yaml
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  resourceNames: ["my-app"]
  verbs: ["update", "patch"]
```

### Multiple resources, same verbs
```bash
kubectl create role multi-reader \
  --verb=get,list \
  --resource=pods,services,configmaps \
  -n dev
```

---

## Troubleshooting Quick Checks

```bash
# Does the role exist?
kubectl get role <role-name> -n <namespace>

# Does the rolebinding exist?
kubectl get rolebinding <binding-name> -n <namespace>

# What can this SA do?
kubectl auth can-i --list \
  --as=system:serviceaccount:<ns>:<sa> \
  -n <namespace>

# Describe for details
kubectl describe role <role-name> -n <namespace>
kubectl describe rolebinding <binding-name> -n <namespace>
```

---

## Exam Time Budget

- Create namespace: **10 seconds**
- Create ServiceAccount: **10 seconds**
- Create Role: **1-2 minutes**
- Create RoleBinding: **30 seconds**
- Verify: **30 seconds**
- **Total: ~3-4 minutes**

---

## Documentation Links (Allowed in Exam)

- RBAC Overview: `kubernetes.io/docs/reference/access-authn-authz/rbac/`
- Role Examples: Search for "Role Example"
- RoleBinding Examples: Search for "RoleBinding Example"

---

**Print this and keep it handy during practice!**