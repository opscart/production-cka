# Networking Lab 01: ClusterIP & NodePort - Quick Reference

## Service Types

```
ClusterIP   → Internal only, default type
NodePort    → ClusterIP + opens port on every node (30000-32767)
LoadBalancer→ NodePort + cloud LB (Lab 02)
ExternalName→ DNS CNAME, no proxying (not covered here)
```

---

## Imperative Commands

```bash
# Expose existing deployment
kubectl expose deployment <name> \
  --port=80 --target-port=8080 \
  --type=ClusterIP

kubectl expose deployment <name> \
  --port=80 --type=NodePort

# Create service from scratch (no deployment needed)
kubectl create service clusterip my-svc --tcp=80:8080
kubectl create service nodeport my-svc --tcp=80:8080 --node-port=30080
```

---

## Declarative YAML

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-svc
spec:
  type: ClusterIP            # or NodePort, LoadBalancer
  selector:
    app: my-app               # MUST match pod labels exactly
  ports:
  - port: 80                  # Service's own port
    targetPort: 8080          # Port on the POD
    nodePort: 30080           # NodePort type only, 30000-32767
```

---

## Inspect Services

```bash
kubectl get svc -n <namespace>
kubectl describe svc <name> -n <namespace>

# Endpoints (classic)
kubectl get endpoints <name> -n <namespace>

# EndpointSlice (modern, what kube-proxy uses)
kubectl get endpointslice -n <namespace>
kubectl get endpointslice -l kubernetes.io/service-name=<name> -n <namespace>
```

---

## Debug: Service Has No Endpoints

```bash
# 1. Compare selector to pod labels
kubectl get svc <name> -o jsonpath='{.spec.selector}'
kubectl get pods --show-labels -n <namespace>

# 2. Check pod readiness (NotReady pods are excluded from Endpoints)
kubectl get pods -n <namespace>

# 3. Check targetPort matches container's actual port
kubectl get pod <pod> -o jsonpath='{.spec.containers[0].ports}'
```

---

## Test Connectivity

```bash
# From inside cluster (need a test pod)
kubectl run test-client --image=busybox -- sleep 3600
kubectl exec test-client -- wget -qO- http://<service-name>
kubectl exec test-client -- wget -qO- http://<cluster-ip>

# NodePort from minikube node
minikube ssh "curl http://localhost:<nodeport>"
minikube service <name> --url     # gets the right URL for your driver
```

---

## Port Field Cheat Sheet

```
port        → what clients connect to (ClusterIP:port)
targetPort  → what the container is actually listening on
nodePort    → what's opened on every node (NodePort only)
```

---

## Exam Scenarios

### Expose deployment on a specific port
```bash
kubectl expose deployment web --port=80 --target-port=8080
```

### Create NodePort with a fixed port
```bash
kubectl create -f - << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: web-nodeport
spec:
  type: NodePort
  selector:
    app: web
  ports:
  - port: 80
    targetPort: 8080
    nodePort: 30080
EOF
```

### Fix a service with no endpoints
```bash
# Check actual pod labels
kubectl get pods --show-labels

# Patch the service selector to match
kubectl patch svc <name> -p '{"spec":{"selector":{"app":"correct-label"}}}'
```

---

## Time Budget (Exam)

- Expose deployment: **30 seconds**
- Verify endpoints: **30 seconds**
- Fix broken selector: **1 minute**
- **Total: ~2-3 minutes**