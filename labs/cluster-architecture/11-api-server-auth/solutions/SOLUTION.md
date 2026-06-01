# Lab 11: API Server Authentication - Solution Guide

## Run the Script
```bash
./scripts/setup.sh   # Creates all resources in lab11-auth namespace
./scripts/test.sh    # 17/17 checks
./scripts/cleanup.sh
```

---

## Manual Step-by-Step

### Step 1: Create Namespace
```bash
kubectl create namespace lab11-auth
```

### Step 2: Generate Key and CSR
```bash
mkdir -p certs
openssl genrsa -out certs/dev-user.key 2048
openssl req -new -key certs/dev-user.key -out certs/dev-user.csr \
  -subj "/CN=dev-user/O=dev-team"
```

### Step 3: Submit and Approve CSR
```bash
CSR=$(cat certs/dev-user.csr | base64 | tr -d '\n')

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
kubectl certificate approve dev-user
kubectl get csr  # Should show: Approved,Issued
```

### Step 4: Extract Certificate
```bash
kubectl get csr dev-user \
  -o jsonpath='{.status.certificate}' | base64 -d > certs/dev-user.crt

openssl x509 -in certs/dev-user.crt -noout -subject
# subject=O=dev-team, CN=dev-user
```

### Step 5: Get CA Cert (Minikube-aware)
```bash
SERVER=$(kubectl config view -o jsonpath='{.clusters[?(@.name=="opscart")].cluster.server}')

CA_FILE=$(kubectl config view --raw -o jsonpath='{.clusters[?(@.name=="opscart")].cluster.certificate-authority}')
CA_DATA=$(kubectl config view --raw -o jsonpath='{.clusters[?(@.name=="opscart")].cluster.certificate-authority-data}')

if [ -n "$CA_FILE" ] && [ -f "$CA_FILE" ]; then
    cp "$CA_FILE" certs/ca.crt
else
    echo "$CA_DATA" | base64 -d > certs/ca.crt
fi
```

### Step 6: Create kubeconfig
```bash
kubectl config set-cluster opscart \
  --certificate-authority=certs/ca.crt \
  --server=$SERVER \
  --embed-certs=true \
  --kubeconfig=certs/dev-user.kubeconfig

kubectl config set-credentials dev-user \
  --client-certificate=certs/dev-user.crt \
  --client-key=certs/dev-user.key \
  --embed-certs=true \
  --kubeconfig=certs/dev-user.kubeconfig

kubectl config set-context dev-user-context \
  --cluster=opscart \
  --user=dev-user \
  --namespace=lab11-auth \
  --kubeconfig=certs/dev-user.kubeconfig

kubectl config use-context dev-user-context \
  --kubeconfig=certs/dev-user.kubeconfig
```

### Step 7: Test Authentication
```bash
kubectl get pods --kubeconfig=certs/dev-user.kubeconfig 2>&1
# Error: pods is forbidden - means authentication WORKED!
# 403 Forbidden = authenticated but no RBAC

# Grant access
kubectl create rolebinding dev-user-view \
  --clusterrole=view \
  --user=dev-user \
  --namespace=lab11-auth

# Now should work
kubectl get pods -n lab11-auth --kubeconfig=certs/dev-user.kubeconfig
```

### Step 8: Service Account
```bash
kubectl create serviceaccount auth-demo-sa -n lab11-auth

kubectl apply -f - << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: auth-demo-pod
  namespace: lab11-auth
spec:
  serviceAccountName: auth-demo-sa
  containers:
  - name: demo
    image: nginx
    command: ["sleep", "3600"]
EOF

kubectl exec auth-demo-pod -n lab11-auth -- \
  ls /var/run/secrets/kubernetes.io/serviceaccount/
# ca.crt  namespace  token
```

---

## Challenges Encountered

### Challenge 1: Multiple Clusters in kubeconfig
**Problem:** `clusters[0]` grabbed AKS cluster instead of minikube
**Solution:** Use `clusters[?(@.name=="opscart")]` to be explicit

### Challenge 2: CA Stored as File Path
**Problem:** minikube stores CA as `/Users/user/.minikube/ca.crt` not inline base64
**Solution:** Check for both `certificate-authority` (file) and `certificate-authority-data` (base64)

### Challenge 3: TLS Certificate Error
**Error:** `x509: "minikube" certificate is not standards compliant`
**Cause:** Empty CA cert in kubeconfig (from failed base64 decode of empty string)
**Solution:** Copy CA file directly instead of decoding empty base64

---

## Key Concepts

### CN and O in Certificates
```
CN (Common Name)  = Kubernetes username
O (Organization)  = Kubernetes group
```

### 401 vs 403
```
401 Unauthorized = Who are you? Authentication failed
403 Forbidden    = I know who you are, but you can't do this
```

### User vs Service Account
```
User Account     → Humans using kubectl (X509/OIDC)
Service Account  → Pods/apps (token auto-mounted)
```

---

## Key Takeaways

- X509 certs identify human users
- CN = username, O = group
- CSR workflow: generate → submit → approve → extract
- Service accounts are for pods, not humans
- Forbidden means auth succeeded!
- Always use cluster name (not index) when multiple clusters exist
- Minikube CA is a file path, not base64

---

**Completed Lab 11?** ✅

Move to **[Lab 12: Admission Controllers](../12-admission-controllers/)**