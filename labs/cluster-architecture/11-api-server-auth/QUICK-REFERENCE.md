# Lab 11: API Server Authentication - Quick Reference

## X509 Certificate Authentication

### Generate Key + CSR
```bash
openssl genrsa -out user.key 2048
openssl req -new -key user.key -out user.csr -subj "/CN=username/O=groupname"
```

### Submit + Approve + Extract
```bash
CSR=$(cat user.csr | base64 | tr -d '\n')
kubectl apply -f csr.yaml           # submit
kubectl certificate approve <name>  # approve
kubectl get csr                     # verify Approved,Issued
kubectl get csr <name> -o jsonpath='{.status.certificate}' | base64 -d > user.crt
openssl x509 -in user.crt -noout -subject -dates  # verify
```

---

## Create kubeconfig

```bash
# Get server - always use cluster name, not index[0]!
SERVER=$(kubectl config view -o jsonpath='{.clusters[?(@.name=="opscart")].cluster.server}')

# CA cert - minikube uses file path, kubeadm uses inline base64
CA_FILE=$(kubectl config view --raw -o jsonpath='{.clusters[?(@.name=="opscart")].cluster.certificate-authority}')
CA_DATA=$(kubectl config view --raw -o jsonpath='{.clusters[?(@.name=="opscart")].cluster.certificate-authority-data}')

if [ -n "$CA_FILE" ] && [ -f "$CA_FILE" ]; then
    cp "$CA_FILE" ca.crt
else
    echo "$CA_DATA" | base64 -d > ca.crt
fi

kubectl config set-cluster opscart --certificate-authority=ca.crt --server=$SERVER --embed-certs=true --kubeconfig=user.kubeconfig
kubectl config set-credentials username --client-certificate=user.crt --client-key=user.key --embed-certs=true --kubeconfig=user.kubeconfig
kubectl config set-context user-ctx --cluster=opscart --user=username --namespace=lab11-auth --kubeconfig=user.kubeconfig
kubectl config use-context user-ctx --kubeconfig=user.kubeconfig
```

---

## Service Accounts

```bash
kubectl create serviceaccount my-sa -n my-namespace
kubectl create token my-sa -n my-namespace
kubectl exec <pod> -n <ns> -- cat /var/run/secrets/kubernetes.io/serviceaccount/token
```

---

## Authentication vs Authorization

```
401 Unauthorized → Authentication FAILED (wrong cert/token)
403 Forbidden    → Authenticated OK, but no RBAC permission
```

---

## Debugging

```bash
kubectl auth whoami
kubectl auth can-i get pods -n lab11-auth --as=dev-user
kubectl get csr
kubectl get pods --kubeconfig=user.kubeconfig 2>&1
# Forbidden = auth works ✅  |  tls/host error = kubeconfig problem ❌
```

---

## Minikube Challenges (vs kubeadm)

```
Issue                    │ Minikube                    │ kubeadm
─────────────────────────┼─────────────────────────────┼──────────────────
CA cert location         │ File path in .minikube/     │ Inline base64
clusters[0] problem      │ May grab wrong AKS cluster  │ Usually only 1
```

---

## Exam Time Budget

- Generate key + CSR: **1 min**
- Submit + approve + extract: **1 min**
- Create kubeconfig: **2 min**
- Verify: **30 sec**
- **Total: ~5 min**