# Lab 02: ClusterRole & ClusterRoleBinding Quick Reference

## Key Differences

| Aspect | Role | ClusterRole |
|--------|------|-------------|
| Scope | Single namespace | Cluster-wide |
| Resources | Namespaced only | All resources |
| Can access nodes | ❌ No | ✅ Yes |
| Can access PVs | ❌ No | ✅ Yes |
| Binding type | RoleBinding | ClusterRoleBinding OR RoleBinding |

## Common Commands

### Create ClusterRole

```bash
# Basic ClusterRole
kubectl create clusterrole pod-reader \
  --verb=get,list,watch \
  --resource=pods

# ClusterRole for cluster-scoped resources
kubectl create clusterrole node-manager \
  --verb=get,list,watch \
  --resource=nodes

# Multiple resources
kubectl create clusterrole multi-reader \
  --verb=get,list \
  --resource=pods,services,deployments
```

### Create ClusterRoleBinding

```bash
# Bind to ServiceAccount
kubectl create clusterrolebinding reader-binding \
  --clusterrole=pod-reader \
  --serviceaccount=default:reader

# Bind to User
kubectl create clusterrolebinding admin-binding \
  --clusterrole=cluster-admin \
  --user=admin@example.com

# Bind to Group
kubectl create clusterrolebinding dev-binding \
  --clusterrole=view \
  --group=developers
```

### ClusterRole + RoleBinding Pattern

```bash
# ClusterRole: defines permissions
kubectl create clusterrole node-viewer \
  --verb=get,list \
  --resource=nodes

# RoleBinding: limits WHO gets it (namespace-scoped)
kubectl create rolebinding dev-node-viewer \
  --clusterrole=node-viewer \
  --serviceaccount=dev:developer \
  -n dev
```

## Testing Permissions

```bash
# Test cluster-wide access
kubectl auth can-i get pods --all-namespaces \
  --as=system:serviceaccount:default:reader

# Test specific namespace
kubectl auth can-i get pods -n prod \
  --as=system:serviceaccount:prod:developer

# Test cluster-scoped resources
kubectl auth can-i get nodes \
  --as=system:serviceaccount:default:reader

# List all permissions
kubectl auth can-i --list \
  --as=system:serviceaccount:default:reader
```

## Built-in ClusterRoles

Kubernetes provides these ClusterRoles out of the box:

```bash
# View (read-only)
kubectl get clusterrole view -o yaml

# Edit (create/update, no delete)
kubectl get clusterrole edit -o yaml

# Admin (full namespace access)
kubectl get clusterrole admin -o yaml

# Cluster-admin (god mode)
kubectl get clusterrole cluster-admin -o yaml
```

**Use built-in roles when possible:**
```bash
# Give user read-only access
kubectl create clusterrolebinding viewer \
  --clusterrole=view \
  --user=john@example.com

# Give user edit access to namespace
kubectl create rolebinding editor \
  --clusterrole=edit \
  --user=jane@example.com \
  -n dev
```

## Aggregated ClusterRoles

### Create Base Role
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: monitoring
aggregationRule:
  clusterRoleSelectors:
  - matchLabels:
      rbac.authorization.k8s.io/aggregate-to-monitoring: "true"
rules: [] # Auto-filled by aggregation
```

### Create Component Roles
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: monitoring-pods
  labels:
    rbac.authorization.k8s.io/aggregate-to-monitoring: "true"
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
```

## Common Patterns

### Read-Only Cluster Access
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-viewer
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
```

### Node Management
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: node-admin
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list", "watch", "update", "patch"]
```

### Namespace Creator
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: namespace-creator
rules:
- apiGroups: [""]
  resources: ["namespaces"]
  verbs: ["create", "get", "list"]
```

## Exam Tips

### Time-Saving Tricks

```bash
# Generate YAML quickly
kubectl create clusterrole my-role \
  --verb=get,list \
  --resource=pods \
  --dry-run=client -o yaml > role.yaml

# Combine ClusterRole creation and binding
kubectl create clusterrole reader --verb=get --resource=pods
kubectl create clusterrolebinding reader-binding \
  --clusterrole=reader \
  --serviceaccount=default:reader
```

### Common Exam Scenarios

1. **Grant cluster-admin to user**
```bash
kubectl create clusterrolebinding admin \
  --clusterrole=cluster-admin \
  --user=admin@example.com
```

2. **Read-only access everywhere**
```bash
kubectl create clusterrolebinding viewer \
  --clusterrole=view \
  --serviceaccount=monitoring:viewer
```

3. **Node access for developer**
```bash
kubectl create clusterrole node-viewer --verb=get --resource=nodes
kubectl create rolebinding dev-nodes \
  --clusterrole=node-viewer \
  --serviceaccount=dev:developer \
  -n dev
```

## Troubleshooting

```bash
# Check what ClusterRoles exist
kubectl get clusterrole

# Check what ClusterRoleBindings exist
kubectl get clusterrolebinding

# Describe to see rules
kubectl describe clusterrole <name>
kubectl describe clusterrolebinding <name>

# Check if aggregation is working
kubectl get clusterrole monitoring -o yaml
# Look for populated rules[] section

# Debug permission issues
kubectl auth can-i --list --as=system:serviceaccount:ns:sa
```

## Key Exam Points

✅ **ClusterRole** = Cluster-wide permissions
✅ **ClusterRoleBinding** = Bind to anyone, applies everywhere
✅ **ClusterRole + RoleBinding** = Cluster resource access, limited to namespace
✅ **Aggregation** = Modular permission composition
✅ **Built-in roles** = Use `view`, `edit`, `admin` when possible

## Documentation Links

- ClusterRole: kubernetes.io/docs/reference/access-authn-authz/rbac/#role-and-clusterrole
- Aggregation: kubernetes.io/docs/reference/access-authn-authz/rbac/#aggregated-clusterroles
- Built-in roles: kubernetes.io/docs/reference/access-authn-authz/rbac/#default-roles-and-role-bindings