# Lab 02: LoadBalancer & Headless Services

## Objective
Understand the LoadBalancer service type and its relationship to NodePort/ClusterIP, and master Headless Services — the mechanism StatefulSets rely on for stable per-pod DNS identity.

## CKA Exam Relevance
- **Domain:** Services & Networking (20%)
- **Topic:** Use ClusterIP, NodePort, LoadBalancer service types and selectors
- **Exam Weight:** Medium-High
- **Typical Exam Time:** 4-6 minutes

## Time to Complete
40 minutes

## Prerequisites
- Completed Lab 01 (ClusterIP & NodePort)

---

## LoadBalancer: The Cloud-Integrated Service Type

```
ClusterIP  →  NodePort  →  LoadBalancer
(internal)    (+ node port)  (+ cloud LB)
```

A `LoadBalancer` Service is a **superset** of NodePort — it automatically gets a ClusterIP and a NodePort, and additionally asks the cloud provider's controller to provision an external load balancer pointing at that NodePort on every node.

```
┌──────────────────────────────────────────────────────────┐
│                  LoadBalancer Service                     │
│                                                            │
│  External LB (cloud-provisioned)                          │
│        │  Forwards to NodePort on every node              │
│        ▼                                                   │
│  NodePort (auto-assigned, 30000-32767)                    │
│        │  kube-proxy routes to pod                         │
│        ▼                                                   │
│  ClusterIP (auto-assigned)                                 │
│        │                                                    │
│        ▼                                                   │
│  Pods                                                       │
└──────────────────────────────────────────────────────────┘
```

**On minikube, there's no real cloud provider** — `EXTERNAL-IP` stays `<pending>` forever unless you run `minikube tunnel`.

---

## Headless Services: DNS Without Load Balancing

A Headless Service (`clusterIP: None`) skips proxying entirely. Instead of one virtual IP, DNS returns **all matching pod IPs directly** — and for StatefulSet pods, each pod also gets its own stable DNS name.

```
Normal Service:                    Headless Service:
─────────────────                  ──────────────────────────────
DNS → 1 ClusterIP                  DNS → list of ALL pod IPs
kube-proxy load-balances           Client picks/connects directly
Good for stateless apps            Good for databases, Kafka, etcd
```

```
StatefulSet pod DNS pattern:
<pod-name>.<service-name>.<namespace>.svc.cluster.local

Example:
postgres-0.postgres-headless.lab02-services.svc.cluster.local
postgres-1.postgres-headless.lab02-services.svc.cluster.local
```

---

## Tasks

### Task 1: Create a LoadBalancer Service (10 min)

```bash
kubectl create namespace lab02-services

kubectl create deployment web-app \
  --image=nginx \
  --replicas=3 \
  -n lab02-services

kubectl wait --for=condition=available \
  deployment/web-app -n lab02-services --timeout=60s

kubectl expose deployment web-app \
  --port=80 \
  --target-port=80 \
  --type=LoadBalancer \
  --name=web-app-lb \
  -n lab02-services

# Watch EXTERNAL-IP stay <pending> — expected on minikube
kubectl get service web-app-lb -n lab02-services
```

**Get a usable external IP with `minikube tunnel` (run in a separate terminal):**
```bash
minikube tunnel
# Leave this running, then in another terminal:
kubectl get service web-app-lb -n lab02-services
# EXTERNAL-IP should now show an IP instead of <pending>
```

---

### Task 2: Create a Headless Service (10 min)

```bash
cat > manifests/web-app-headless.yaml << 'EOF'
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

kubectl apply -f manifests/web-app-headless.yaml

# Note: CLUSTER-IP shows "None"
kubectl get service web-app-headless -n lab02-services
```

---

### Task 3: Compare DNS Resolution (10 min)

```bash
kubectl run dns-test --image=busybox -n lab02-services -- sleep 3600
kubectl wait --for=condition=ready pod/dns-test -n lab02-services --timeout=60s

# Normal ClusterIP service → ONE IP
kubectl exec dns-test -n lab02-services -- \
  nslookup web-app-lb.lab02-services.svc.cluster.local

# Headless service → ALL pod IPs
kubectl exec dns-test -n lab02-services -- \
  nslookup web-app-headless.lab02-services.svc.cluster.local
```

You should see a single A record for the LoadBalancer/ClusterIP service, but **multiple A records** (one per pod) for the headless service.

---

### Task 4: Headless Service with a StatefulSet (10 min)

This is where headless services are actually used in production.

```bash
cat > manifests/postgres-statefulset.yaml << 'EOF'
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

kubectl apply -f manifests/postgres-statefulset.yaml

kubectl wait --for=condition=ready pod/postgres-0 \
  -n lab02-services --timeout=120s
kubectl wait --for=condition=ready pod/postgres-1 \
  -n lab02-services --timeout=120s

# Each pod gets its OWN stable DNS name
kubectl exec dns-test -n lab02-services -- \
  nslookup postgres-0.postgres-headless.lab02-services.svc.cluster.local

kubectl exec dns-test -n lab02-services -- \
  nslookup postgres-1.postgres-headless.lab02-services.svc.cluster.local
```

---

## ⚠️ Minikube-Specific Notes

### LoadBalancer EXTERNAL-IP stuck at `<pending>`
This is expected — minikube has no cloud provider to provision a real load balancer.

```bash
# Option 1: minikube tunnel (simulates a cloud LB, needs sudo)
minikube tunnel

# Option 2: just use the NodePort that's auto-assigned
kubectl get svc web-app-lb -n lab02-services
# PORT(S) column shows something like 80:31234/TCP
minikube ssh "curl -s http://localhost:31234"
```

---

## Exam Tips

⏱️ **Time Management:**
- LoadBalancer service: 1 minute
- Headless service: 1 minute
- DNS verification: 1-2 minutes
- **Total: ~4 minutes**

🎯 **Exam Question Patterns:**

> *"Create a LoadBalancer service for deployment X on port 80"*
```bash
kubectl expose deployment X --port=80 --type=LoadBalancer
```

> *"Create a headless service for use with a StatefulSet"*
```yaml
spec:
  clusterIP: None
```

> *"Why does nslookup return multiple IPs for service Y?"*
→ It's a headless service (`clusterIP: None`)

🔑 **Key Facts:**
- `LoadBalancer` = `NodePort` + cloud LB provisioning
- `clusterIP: None` = headless, no virtual IP, no load balancing
- StatefulSet pods get individual DNS names ONLY via a headless service
- `serviceName` in StatefulSet spec must match the headless Service name

---

## Common Issues

### EXTERNAL-IP never appears
```bash
# Expected on minikube without a tunnel/cloud provider
minikube tunnel   # or just use the NodePort
```

### StatefulSet pod has no individual DNS name
```bash
# Check StatefulSet's serviceName matches an actual headless Service
kubectl get statefulset <name> -o jsonpath='{.spec.serviceName}'
kubectl get svc <that-name> -o jsonpath='{.spec.clusterIP}'
# Must be "None"
```

---

## Next Lab

Move to **[Lab 03: Service Discovery & DNS](../03-service-discovery-dns/README.md)**

---

**Author:** Shamsher Khan | **Blog:** opscart.com | **Course:** Production CKA 2026