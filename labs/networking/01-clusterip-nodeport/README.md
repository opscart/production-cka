# Lab 01: ClusterIP & NodePort Services

## Objective
Understand the two most common Kubernetes Service types — ClusterIP and NodePort — how they route traffic to pods, how Endpoints/EndpointSlices track pod membership, and how to create and verify them using both imperative and declarative methods.

## CKA Exam Relevance
- **Domain:** Services & Networking (20%)
- **Topic:** Understand connectivity between Pods, define and enforce Network Policies, use ClusterIP, NodePort, LoadBalancer service types and selectors
- **Exam Weight:** High (Services appear in nearly every networking question)
- **Typical Exam Time:** 4-6 minutes

## Time to Complete
40 minutes

## Prerequisites
- Completed Cluster Architecture domain (Labs 01-18)
- Lab 15 (CNI Plugins) recommended — Services sit on top of pod networking

---

## What is a Service?

A pod's IP address changes every time it restarts. A **Service** gives a stable virtual IP and DNS name in front of a set of pods, so other workloads never need to track individual pod IPs.

```
Without a Service:                  With a Service:
─────────────────────────           ─────────────────────────────
Client must track pod IPs           Client uses one stable name
Pod restarts → IP changes           Service IP never changes
No load balancing                   Traffic spread across all pods
```

---

## Service Types Covered in This Lab

```
┌──────────────┬─────────────────────────────────────────────────┐
│ Type         │ Behavior                                        │
├──────────────┼─────────────────────────────────────────────────┤
│ ClusterIP    │ Internal-only virtual IP. Default type.          │
│              │ Reachable only from inside the cluster.          │
├──────────────┼─────────────────────────────────────────────────┤
│ NodePort     │ Opens the same port on EVERY node (30000-32767). │
│              │ Reachable from outside via <NodeIP>:<NodePort>.  │
│              │ Includes a ClusterIP automatically.              │
└──────────────┴─────────────────────────────────────────────────┘
```

---

## How a Service Finds Its Pods

```
Service                          Pods
┌─────────────────┐              ┌─────────────┐
│ selector:        │   matches    │ labels:     │
│   app: web-app   │ ───────────► │  app: web-app│
└─────────────────┘              └─────────────┘
        │
        ▼
┌─────────────────┐
│  Endpoints /     │  ← auto-created, lists matching pod IPs
│  EndpointSlice   │
└─────────────────┘
```

If a Service's `selector` doesn't match any pod labels, the Service exists but has **zero Endpoints** — a very common exam trap.

---

## Tasks

### Task 1: Create a Deployment and Expose via ClusterIP (10 min)

```bash
kubectl create namespace lab01-services

kubectl create deployment web-app \
  --image=nginx \
  --replicas=3 \
  -n lab01-services

kubectl wait --for=condition=available \
  deployment/web-app -n lab01-services --timeout=60s

# Imperative: expose as ClusterIP (default type)
kubectl expose deployment web-app \
  --port=80 \
  --target-port=80 \
  --name=web-app-clusterip \
  -n lab01-services

# Verify
kubectl get service web-app-clusterip -n lab01-services
kubectl describe service web-app-clusterip -n lab01-services
```

**Declarative equivalent:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-app-clusterip
  namespace: lab01-services
spec:
  type: ClusterIP
  selector:
    app: web-app
  ports:
  - port: 80
    targetPort: 80
```

---

### Task 2: Inspect Endpoints and EndpointSlices (10 min)

```bash
# Classic Endpoints object (still exists for compatibility)
kubectl get endpoints web-app-clusterip -n lab01-services

# Modern EndpointSlice (what kube-proxy actually watches)
kubectl get endpointslice -n lab01-services
kubectl describe endpointslice -n lab01-services -l kubernetes.io/service-name=web-app-clusterip

# Confirm endpoint IPs match pod IPs
kubectl get pods -n lab01-services -o wide
```

**Exam trap to practice:** Create a Service with a selector that does NOT match any pod, then observe empty Endpoints.

```bash
kubectl expose deployment web-app \
  --port=80 \
  --name=broken-service \
  --overrides='{"spec":{"selector":{"app":"wrong-label"}}}' \
  -n lab01-services 2>/dev/null || \
kubectl create -f - << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: broken-service
  namespace: lab01-services
spec:
  selector:
    app: wrong-label
  ports:
  - port: 80
    targetPort: 80
EOF

kubectl get endpoints broken-service -n lab01-services
# <none> — this is the #1 cause of "service not reachable" exam questions
```

---

### Task 3: Test ClusterIP Connectivity from Inside the Cluster (5 min)

```bash
kubectl run test-client --image=busybox -n lab01-services -- sleep 3600
kubectl wait --for=condition=ready pod/test-client -n lab01-services --timeout=60s

CLUSTER_IP=$(kubectl get service web-app-clusterip -n lab01-services \
  -o jsonpath='{.spec.clusterIP}')

kubectl exec test-client -n lab01-services -- \
  wget -q -O- --timeout=5 http://$CLUSTER_IP | head -3

# Also works via DNS name
kubectl exec test-client -n lab01-services -- \
  wget -q -O- --timeout=5 http://web-app-clusterip | head -3
```

---

### Task 4: Create and Test a NodePort Service (10 min)

```bash
cat > manifests/web-app-nodeport.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: web-app-nodeport
  namespace: lab01-services
spec:
  type: NodePort
  selector:
    app: web-app
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
EOF

kubectl apply -f manifests/web-app-nodeport.yaml

# Verify
kubectl get service web-app-nodeport -n lab01-services

# Get a node IP
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

# Test from minikube host (or via minikube ssh on the node)
minikube ssh "curl -s http://localhost:30080" | head -3

echo "External access pattern: http://$NODE_IP:30080"
```

---

### Task 5: Compare Service Port Fields (5 min)

```bash
kubectl get service web-app-nodeport -n lab01-services -o yaml | grep -A5 ports

# port       → port the Service itself listens on (ClusterIP:port)
# targetPort → port on the POD that traffic is forwarded to
# nodePort   → port opened on EVERY node (NodePort type only)
```

---

## ⚠️ Minikube-Specific Notes

### NodePort access from your Mac
On cloud Kubernetes, NodePort is reachable from any node's external IP. On minikube, the "node" is a VM, so from your Mac you need:
```bash
minikube service web-app-nodeport -n lab01-services --url
# or
minikube ssh "curl -s http://localhost:30080"
```
Plain `curl http://<minikube-ip>:30080` from the Mac host may not work depending on your minikube driver (docker driver routes differently than hyperkit/VM drivers).

---

## Exam Tips

⏱️ **Time Management:**
- Create + expose: 1 minute
- Verify endpoints: 1 minute
- Test connectivity: 1-2 minutes
- **Total: ~4 minutes**

🎯 **Exam Question Patterns:**

> *"Expose deployment X as a ClusterIP service on port 80"*
```bash
kubectl expose deployment X --port=80 --target-port=80
```

> *"The service Y is not returning any endpoints. Fix it."*
→ Check `kubectl get svc Y -o yaml` selector vs `kubectl get pods --show-labels`

> *"Create a NodePort service exposing port 8080 on nodePort 30080"*
→ Use the YAML pattern from Task 4

🔑 **Key Commands:**
```bash
kubectl expose deployment <name> --port=<p> --target-port=<tp> --type=<Type>
kubectl get svc,endpoints,endpointslice -n <namespace>
kubectl describe svc <name> -n <namespace>
```

---

## Common Issues

### Service has no endpoints
```bash
# Compare selector to pod labels exactly
kubectl get svc <name> -o jsonpath='{.spec.selector}'
kubectl get pods --show-labels
```

### NodePort out of range
```bash
# Valid range is 30000-32767 by default
# Error: provided port is not in the valid range
```

### targetPort mismatch
```bash
# targetPort must match the container's actual listening port
kubectl get pod <pod> -o jsonpath='{.spec.containers[0].ports}'
```

---

## Next Lab

Move to **[Lab 02: LoadBalancer & Headless Services](../02-loadbalancer-headless/README.md)**

---

**Author:** Shamsher Khan | **Blog:** opscart.com | **Course:** Production CKA 2026