# Networking Lab 02: LoadBalancer & Headless - Quick Reference

## LoadBalancer Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-lb
spec:
  type: LoadBalancer
  selector:
    app: web
  ports:
  - port: 80
    targetPort: 80
```

```bash
kubectl expose deployment web --port=80 --type=LoadBalancer

# Get external access (minikube has no real cloud LB)
minikube tunnel                       # run separately, needs sudo
kubectl get svc web-lb                # watch EXTERNAL-IP populate
```

---

## Headless Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-headless
spec:
  clusterIP: None        # ← this is what makes it headless
  selector:
    app: web
  ports:
  - port: 80
```

```bash
kubectl get svc web-headless
# CLUSTER-IP column shows: None
```

---

## StatefulSet + Headless Service Pattern

```yaml
apiVersion: v1
kind: Service
metadata:
  name: db-headless
spec:
  clusterIP: None
  selector:
    app: db
  ports:
  - port: 5432
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: db
spec:
  serviceName: db-headless   # ← MUST match the headless Service name
  replicas: 3
  selector:
    matchLabels:
      app: db
  template:
    metadata:
      labels:
        app: db
    spec:
      containers:
      - name: db
        image: postgres:16-alpine
```

---

## DNS Names

```bash
# Normal/LoadBalancer service → one A record
<service>.<namespace>.svc.cluster.local

# Headless service → multiple A records (one per pod)
<service>.<namespace>.svc.cluster.local

# StatefulSet pod via headless service → individual stable name
<pod-name>.<headless-service>.<namespace>.svc.cluster.local
# e.g. db-0.db-headless.default.svc.cluster.local
```

---

## Compare DNS Resolution

```bash
kubectl run dns-test --image=busybox -- sleep 3600

# Single IP expected
kubectl exec dns-test -- nslookup <normal-service>.<ns>.svc.cluster.local

# Multiple IPs expected
kubectl exec dns-test -- nslookup <headless-service>.<ns>.svc.cluster.local

# Individual pod identity
kubectl exec dns-test -- nslookup <pod-0>.<headless-service>.<ns>.svc.cluster.local
```

---

## Service Type Decision Table

```
Need...                          Use...
─────────────────────────────    ──────────────
Internal-only access              ClusterIP
External access via node IP       NodePort
External access via cloud LB      LoadBalancer
Stable per-pod DNS (DB/Kafka)      Headless + StatefulSet
Load-balanced stateless access    ClusterIP / LoadBalancer
```

---

## Exam Scenarios

### Create LoadBalancer
```bash
kubectl expose deployment web --port=80 --type=LoadBalancer --name=web-lb
```

### Create Headless Service
```bash
kubectl apply -f - << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: db-headless
spec:
  clusterIP: None
  selector:
    app: db
  ports:
  - port: 5432
EOF
```

### Verify StatefulSet pod DNS
```bash
kubectl exec <any-pod> -- nslookup pod-0.headless-svc.namespace.svc.cluster.local
```

---

## Time Budget (Exam)

- LoadBalancer service: **1 minute**
- Headless service: **1 minute**
- DNS verification: **1-2 minutes**
- **Total: ~3-4 minutes**