# Lab 13: Service Accounts

## Objective
Master Kubernetes Service Accounts - create and manage them, bind RBAC permissions, mount tokens in pods, and understand how applications authenticate to the API server using service account tokens.

## CKA Exam Relevance
- **Domain:** Cluster Architecture, Installation & Configuration (25%)
- **Topic:** Understand and configure Service Accounts
- **Exam Weight:** High (appears in 60%+ of exams)
- **Typical Exam Time:** 5-8 minutes

## Time to Complete
45 minutes

## Prerequisites
- Completed Labs 01-12
- Understanding of RBAC (Labs 01-02)
- Understanding of Authentication (Lab 11)

---

## Service Accounts vs User Accounts

```
┌─────────────────────────────────────────────────────────────┐
│               User Account vs Service Account               │
├──────────────────────┬──────────────────────────────────────┤
│   User Account       │   Service Account                    │
├──────────────────────┼──────────────────────────────────────┤
│ For humans           │ For pods/applications                 │
│ X509 certs / OIDC    │ JWT token (auto-mounted)             │
│ Cluster-wide         │ Namespace-scoped                     │
│ External identity    │ Kubernetes-managed                   │
│ kubectl users        │ In-cluster API access                │
└──────────────────────┴──────────────────────────────────────┘
```

---

## How Service Accounts Work

```
┌─────────────────────────────────────────────────────────┐
│                   Kubernetes Cluster                     │
│                                                          │
│  ┌────────────────────┐                                 │
│  │  Service Account   │                                 │
│  │  "monitoring-sa"   │                                 │
│  └────────┬───────────┘                                 │
│           │ bound to                                     │
│  ┌────────▼───────────┐     ┌──────────────────────┐   │
│  │   Role/ClusterRole │     │       Pod             │   │
│  │   (permissions)    │     │  serviceAccountName:  │   │
│  └────────────────────┘     │    monitoring-sa      │   │
│                              │                      │   │
│                              │  /var/run/secrets/   │   │
│                              │   token (auto-mount) │   │
│                              └──────────────────────┘   │
│                                        │                 │
│                                        │ uses token      │
│                                        ▼                 │
│                              ┌──────────────────────┐   │
│                              │    kube-apiserver    │   │
│                              └──────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

---

## Tasks

### Task 1: Explore Default Service Account (5 min)

**Objective:** Understand the default service account.

```bash
# Every namespace has a default service account
kubectl get serviceaccount -n default
kubectl get serviceaccount -A | head -10

# Describe default service account
kubectl describe serviceaccount default -n default

# Every pod gets default SA if none specified
kubectl run default-sa-pod --image=nginx -n default
kubectl get pod default-sa-pod \
  -o jsonpath='{.spec.serviceAccountName}'
# Output: default

kubectl delete pod default-sa-pod
```

---

### Task 2: Create and Use Custom Service Account (15 min)

**Objective:** Create a service account with specific permissions.

```bash
# Create namespace
kubectl create namespace lab13-sa

# Create service account
kubectl create serviceaccount monitoring-sa -n lab13-sa

# View service account
kubectl describe serviceaccount monitoring-sa -n lab13-sa
```

**Bind RBAC permissions:**

```bash
# Create Role with read permissions
cat > manifests/monitoring-role.yaml << 'EOF'
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

kubectl apply -f manifests/monitoring-role.yaml

# Bind role to service account
cat > manifests/monitoring-rolebinding.yaml << 'EOF'
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

kubectl apply -f manifests/monitoring-rolebinding.yaml
```

**Deploy pod with service account:**

```bash
cat > manifests/monitoring-pod.yaml << 'EOF'
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

kubectl apply -f manifests/monitoring-pod.yaml
kubectl wait --for=condition=ready pod/monitoring-pod \
  -n lab13-sa --timeout=60s
```

---

### Task 3: Use Service Account Token (10 min)

**Objective:** Use the mounted token to call the API server.

```bash
# Exec into pod
kubectl exec -it monitoring-pod -n lab13-sa -- sh

# Inside pod - view mounted token
cat /var/run/secrets/kubernetes.io/serviceaccount/token

# Use token to call API server
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
CACERT=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
NS=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)

# Call API server (should work - has list pods permission)
curl -s --cacert $CACERT \
  -H "Authorization: Bearer $TOKEN" \
  https://kubernetes.default.svc/api/v1/namespaces/$NS/pods | \
  python3 -m json.tool | grep '"name"' | head -5

# Try something not allowed (should fail)
curl -s --cacert $CACERT \
  -H "Authorization: Bearer $TOKEN" \
  https://kubernetes.default.svc/api/v1/namespaces/$NS/secrets

exit
```

---

### Task 4: Disable Service Account Token Automount (5 min)

**Objective:** Disable automatic token mounting for security.

```bash
# Create SA with automount disabled
cat > manifests/restricted-sa.yaml << 'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: restricted-sa
  namespace: lab13-sa
automountServiceAccountToken: false
EOF

kubectl apply -f manifests/restricted-sa.yaml

# Create pod with restricted SA
cat > manifests/restricted-pod.yaml << 'EOF'
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

kubectl apply -f manifests/restricted-pod.yaml
kubectl wait --for=condition=ready pod/restricted-pod \
  -n lab13-sa --timeout=60s

# Verify no token mounted
kubectl exec restricted-pod -n lab13-sa -- \
  ls /var/run/secrets/ 2>&1 || echo "No secrets mounted!"
```

---

### Task 5: Generate Service Account Token (5 min)

**Objective:** Generate tokens for external use.

```bash
# Generate short-lived token (Kubernetes 1.24+)
kubectl create token monitoring-sa -n lab13-sa

# Generate token with custom expiry (1 hour)
kubectl create token monitoring-sa -n lab13-sa \
  --duration=3600s

# Generate long-lived token via Secret (legacy method)
cat > manifests/sa-token-secret.yaml << 'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: monitoring-sa-token
  namespace: lab13-sa
  annotations:
    kubernetes.io/service-account.name: monitoring-sa
type: kubernetes.io/service-account-token
EOF

kubectl apply -f manifests/sa-token-secret.yaml

# View the token
kubectl get secret monitoring-sa-token -n lab13-sa \
  -o jsonpath='{.data.token}' | base64 -d
```

---

## Exam Tips

⏱️ **Time Management:**
- Create SA: 30 seconds
- Create Role + RoleBinding: 2 minutes
- Create pod with SA: 1 minute
- Verify permissions: 1 minute
- **Total: ~5 minutes**

🎯 **Exam Question Patterns:**

> *"Create a service account 'deploy-sa' and bind it to the 'deployment-manager' role"*

> *"Create a pod that uses the 'monitoring-sa' service account"*

> *"Disable token automounting for service account 'restricted-sa'"*

> *"Generate a token for service account 'ci-sa' that expires in 1 hour"*

🔑 **Quick Commands:**
```bash
# Create SA
kubectl create serviceaccount my-sa -n my-namespace

# Bind to existing role
kubectl create rolebinding my-binding \
  --role=my-role \
  --serviceaccount=my-namespace:my-sa \
  -n my-namespace

# Generate token
kubectl create token my-sa -n my-namespace

# Check SA permissions
kubectl auth can-i list pods \
  --as=system:serviceaccount:my-namespace:my-sa \
  -n my-namespace
```

---

## Common Issues

### SA token not working
```bash
# Check SA exists in correct namespace
kubectl get sa my-sa -n my-namespace

# Check RoleBinding references correct SA
kubectl describe rolebinding my-binding -n my-namespace

# Test permissions
kubectl auth can-i list pods \
  --as=system:serviceaccount:ns:sa-name -n ns
```

### Pod not using correct SA
```bash
# Check pod spec
kubectl get pod my-pod -o jsonpath='{.spec.serviceAccountName}'

# SA must exist BEFORE pod creation
```

---

## Next Lab

Move to **[Lab 14: CRDs and Operators](../14-crds-operators/README.md)**

---

**Author:** Shamsher Khan | **Blog:** opscart.com | **Course:** Production CKA 2026