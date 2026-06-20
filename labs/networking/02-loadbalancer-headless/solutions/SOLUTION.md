# Networking Lab 02: LoadBalancer & Headless Services - Solution Guide

## Run the Scripts
```bash
./scripts/setup.sh
./scripts/test.sh
./scripts/cleanup.sh
```

---

## Complete Manual Solution

### Step 1: LoadBalancer Service
```bash
kubectl create namespace lab02-services

kubectl create deployment web-app --image=nginx --replicas=3 -n lab02-services
kubectl wait --for=condition=available deployment/web-app -n lab02-services --timeout=60s

kubectl expose deployment web-app \
  --port=80 --target-port=80 \
  --type=LoadBalancer \
  --name=web-app-lb \
  -n lab02-services

kubectl get svc web-app-lb -n lab02-services
# EXTERNAL-IP: <pending>  ← expected on minikube without a tunnel
```

### Step 2: Headless Service
```bash
kubectl apply -f - << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: web-app-headless
  namespace: lab02-services
spec:
  clusterIP: None
  selector:
    app: web-app
  ports:
  - port: 80
    targetPort: 80
EOF

kubectl get svc web-app-headless -n lab02-services
# CLUSTER-IP: None
```

### Step 3: StatefulSet + Headless Service
```bash
kubectl apply -f - << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: postgres-headless
  namespace: lab02-services
spec:
  clusterIP: None
  selector:
    app: postgres
  ports:
  - port: 5432
    targetPort: 5432
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: lab02-services
spec:
  serviceName: postgres-headless
  replicas: 2
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:16-alpine
        env:
        - name: POSTGRES_PASSWORD
          value: "labpassword"
        ports:
        - containerPort: 5432
EOF

kubectl get pods -n lab02-services -l app=postgres
# postgres-0, postgres-1 — predictable, stable names
```

### Step 4: Compare DNS Resolution
```bash
kubectl run dns-test --image=busybox -n lab02-services -- sleep 3600
kubectl wait --for=condition=ready pod/dns-test -n lab02-services --timeout=60s

# Normal service → 1 IP
kubectl exec dns-test -n lab02-services -- \
  nslookup web-app-lb.lab02-services.svc.cluster.local

# Headless service → 3 IPs (one per backing pod)
kubectl exec dns-test -n lab02-services -- \
  nslookup web-app-headless.lab02-services.svc.cluster.local

# Individual StatefulSet pod identity
kubectl exec dns-test -n lab02-services -- \
  nslookup postgres-0.postgres-headless.lab02-services.svc.cluster.local
kubectl exec dns-test -n lab02-services -- \
  nslookup postgres-1.postgres-headless.lab02-services.svc.cluster.local
```

---

## Why StatefulSets Need Headless Services

```
Deployment (stateless):              StatefulSet (stateful):
─────────────────────────            ──────────────────────────────
Pods are interchangeable             Each pod has a fixed identity
Any pod can serve any request        postgres-0 ≠ postgres-1 (different data)
Normal Service load-balances fine    Clients need to reach a SPECIFIC pod
                                      → headless Service + ordinal DNS name
```

A database replica set is the classic example: the primary might be `postgres-0`
and replicas `postgres-1`, `postgres-2`. An app can't just hit a random pod behind
a load-balanced ClusterIP — it needs to know which one is the primary.

---

## Key Takeaways

✅ `LoadBalancer` = `NodePort` + cloud LB request; `<pending>` is normal on minikube
✅ `clusterIP: None` is what makes a Service "headless"
✅ Headless Service DNS returns ALL pod IPs (no load balancing)
✅ StatefulSet `serviceName` must reference an existing headless Service
✅ Each StatefulSet pod gets `<pod-name>.<headless-svc>.<ns>.svc.cluster.local`
✅ Use headless services for databases, message queues, anything needing per-pod identity

---

**Completed Lab 02?** ✅

Move to **[Lab 03: Service Discovery & DNS](../03-service-discovery-dns/)**