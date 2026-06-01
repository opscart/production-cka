# Lab 11: API Server Authentication

## Objective
Master Kubernetes authentication mechanisms including X509 certificates, Service Account tokens, and kubeconfig files. Understand how users and applications authenticate to the API server.

## CKA Exam Relevance
- **Domain:** Cluster Architecture, Installation & Configuration (25%)
- **Topic:** Implement and configure authentication
- **Exam Weight:** High (appears in 60%+ of exams)
- **Typical Exam Time:** 8-10 minutes

## Time to Complete
50 minutes

## Prerequisites
- Completed Labs 01-10
- Running minikube cluster
- Understanding of RBAC (Labs 01-02)

---

## Authentication vs Authorization

```
┌─────────────────────────────────────────────────────────────┐
│                    kubectl apply -f pod.yaml                 │
│                             │                               │
│                             ▼                               │
│              ┌──────────────────────────┐                   │
│              │      kube-apiserver      │                   │
│              │                          │                   │
│              │  1. Authentication       │ ← Who are you?    │
│              │     - X509 certs         │                   │
│              │     - Service Accounts   │                   │
│              │     - OIDC tokens        │                   │
│              │                          │                   │
│              │  2. Authorization        │ ← Can you do it?  │
│              │     - RBAC               │                   │
│              │     - Node               │                   │
│              │                          │                   │
│              │  3. Admission Control    │ ← Should we do it?│
│              └──────────────────────────┘                   │
└─────────────────────────────────────────────────────────────┘
```

---

## Authentication Methods

```
Method              │ Used By          │ Where stored
────────────────────┼──────────────────┼──────────────────────
X509 Certificates   │ kubectl users    │ kubeconfig file
Service Accounts    │ Pods/Apps        │ Kubernetes Secrets
Bearer Tokens       │ CI/CD, scripts   │ Kubernetes Secrets
OIDC               │ Enterprise SSO   │ External provider
```

---

## Tasks

### Task 1: Inspect kubeconfig (10 min)

**Objective:** Understand how kubectl authenticates.

```bash
# View your kubeconfig
kubectl config view

# View full kubeconfig (with certs)
kubectl config view --raw

# Current context
kubectl config current-context

# List all contexts
kubectl config get-contexts

# List clusters
kubectl config get-clusters

# List users
kubectl config get-users
```

**kubeconfig structure:**

```yaml
apiVersion: v1
kind: Config
clusters:              # Cluster connection info
- cluster:
    certificate-authority-data: <base64-ca-cert>
    server: https://192.168.58.2:8443
  name: opscart
contexts:              # Cluster + user combination
- context:
    cluster: opscart
    user: opscart
  name: opscart
current-context: opscart
users:                 # Authentication credentials
- name: opscart
  user:
    client-certificate-data: <base64-cert>
    client-key-data: <base64-key>
```

---

### Task 2: X509 Certificate Authentication (15 min)

**Objective:** Create a new user with X509 certificate authentication.

**Step 1: Generate private key and CSR**

```bash
# Create directory for user certs
mkdir -p certs

# Generate private key
openssl genrsa -out certs/dev-user.key 2048

# Generate Certificate Signing Request
openssl req -new \
  -key certs/dev-user.key \
  -out certs/dev-user.csr \
  -subj "/CN=dev-user/O=dev-team"

# CN = username in Kubernetes
# O = group in Kubernetes
```

**Step 2: Create CertificateSigningRequest in Kubernetes**

```bash
# Encode CSR in base64
CSR=$(cat certs/dev-user.csr | base64 | tr -d '\n')

# Create CSR object
cat > manifests/dev-user-csr.yaml << EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: dev-user
spec:
  request: $CSR
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400
  usages:
  - client auth
EOF

kubectl apply -f manifests/dev-user-csr.yaml

# View CSR status
kubectl get csr
# Status: Pending
```

**Step 3: Approve the CSR**

```bash
# Approve as admin
kubectl certificate approve dev-user

# Verify approved
kubectl get csr
# Status: Approved,Issued

# Extract the signed certificate
kubectl get csr dev-user \
  -o jsonpath='{.status.certificate}' | base64 -d > certs/dev-user.crt

# Verify certificate
openssl x509 -in certs/dev-user.crt -text -noout | grep -E "Subject:|Issuer:"
```

**Step 4: Create kubeconfig for new user**

```bash
# Get cluster CA cert
kubectl config view --raw \
  -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | \
  base64 -d > certs/ca.crt

# Get cluster server URL
SERVER=$(kubectl config view -o jsonpath='{.clusters[0].cluster.server}')

# Create kubeconfig for dev-user
kubectl config set-cluster minikube \
  --certificate-authority=certs/ca.crt \
  --server=$SERVER \
  --kubeconfig=certs/dev-user.kubeconfig

kubectl config set-credentials dev-user \
  --client-certificate=certs/dev-user.crt \
  --client-key=certs/dev-user.key \
  --kubeconfig=certs/dev-user.kubeconfig

kubectl config set-context dev-user-context \
  --cluster=minikube \
  --user=dev-user \
  --kubeconfig=certs/dev-user.kubeconfig

kubectl config use-context dev-user-context \
  --kubeconfig=certs/dev-user.kubeconfig

# Test authentication
kubectl get pods --kubeconfig=certs/dev-user.kubeconfig
# Error: Forbidden (authenticated but no RBAC permissions yet)
# This means authentication WORKED!
```

---

### Task 3: Service Account Authentication (10 min)

**Objective:** Understand how pods authenticate to the API server.

```bash
# List service accounts
kubectl get serviceaccounts
kubectl get serviceaccounts -A | head -10

# View default service account
kubectl describe serviceaccount default

# Create a custom service account
kubectl create serviceaccount app-service-account

# View the service account token (Kubernetes 1.24+)
kubectl create token app-service-account

# Create a pod using the service account
cat > manifests/app-pod.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: app-pod
spec:
  serviceAccountName: app-service-account
  containers:
  - name: app
    image: nginx
    command: ["sleep", "3600"]
EOF

kubectl apply -f manifests/app-pod.yaml

# Verify service account is mounted
kubectl exec app-pod -- ls /var/run/secrets/kubernetes.io/serviceaccount/
# ca.crt  namespace  token

# View the mounted token
kubectl exec app-pod -- cat /var/run/secrets/kubernetes.io/serviceaccount/token
```

---

### Task 4: Switch Between Contexts (10 min)

**Objective:** Manage multiple cluster contexts.

```bash
# View all contexts
kubectl config get-contexts

# Switch context
kubectl config use-context opscart

# Create a new context
kubectl config set-context dev-context \
  --cluster=opscart \
  --user=opscart \
  --namespace=dev

# Use specific namespace in context
kubectl config use-context dev-context
kubectl get pods  # Now defaults to dev namespace

# Switch back
kubectl config use-context opscart

# Run one command in different context
kubectl get pods --context=opscart
```

---

### Task 5: Inspect Authentication Configuration (5 min)

**Objective:** Understand API server auth flags.

```bash
# View API server authentication flags
kubectl describe pod kube-apiserver-opscart -n kube-system | \
  grep -E "client-ca|authorization-mode|enable-admission"

# Key flags:
# --client-ca-file          - CA for verifying client certificates
# --authorization-mode      - Node,RBAC
# --enable-admission-plugins- Admission controllers active
```

---

## Exam Tips

⏱️ **Time Management:**
- Create key + CSR: 2 minutes
- Submit + approve CSR: 2 minutes
- Create kubeconfig: 2 minutes
- Verify: 1 minute
- **Total: ~7 minutes**

🎯 **Exam Question Patterns:**

> *"Create a user 'john' with certificate authentication"*

> *"Approve the pending CSR named 'jane'"*

> *"Create a kubeconfig for user 'bob' using these certificates"*

🔑 **Quick Commands:**
```bash
# Generate key + CSR
openssl genrsa -out user.key 2048
openssl req -new -key user.key -out user.csr -subj "/CN=username/O=group"

# Submit CSR
cat user.csr | base64 | tr -d '\n'  # encode
kubectl apply -f csr.yaml

# Approve
kubectl certificate approve <csr-name>

# Extract cert
kubectl get csr <name> -o jsonpath='{.status.certificate}' | base64 -d > user.crt
```

---

## Common Issues

### Issue 1: CSR stays Pending

```bash
# Check CSR status
kubectl describe csr dev-user

# Approve manually
kubectl certificate approve dev-user
```

### Issue 2: Forbidden after authentication

```bash
# Authentication works but no RBAC permissions
# Create RoleBinding for the user
kubectl create rolebinding dev-user-binding \
  --clusterrole=view \
  --user=dev-user \
  --namespace=default
```

### Issue 3: Certificate expired

```bash
# Check expiry
openssl x509 -in user.crt -noout -dates

# Re-create CSR and get new cert
```

---

## Next Lab

Move to **[Lab 12: Admission Controllers](../12-admission-controllers/README.md)**

---

**Author:** Shamsher Khan | **Blog:** opscart.com | **Course:** Production CKA 2026