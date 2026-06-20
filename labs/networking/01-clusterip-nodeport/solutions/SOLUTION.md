# Networking Lab 01: ClusterIP & NodePort - Solution Guide

## Run the Scripts
```bash
./scripts/setup.sh
./scripts/test.sh
./scripts/cleanup.sh
```

---

## Complete Manual Solution

### Step 1: Create Deployment
```bash
kubectl create namespace lab01-services

kubectl create deployment web-app \
  --image=nginx \
  --replicas=3 \
  -n lab01-services

kubectl wait --for=condition=available \
  deployment/web-app -n lab01-services --timeout=60s
```

### Step 2: Expose as ClusterIP
```bash
kubectl expose deployment web-app \
  --port=80 \
  --target-port=80 \
  --name=web-app-clusterip \
  -n lab01-services

kubectl get svc web-app-clusterip -n lab01-services
```

### Step 3: Verify Endpoints
```bash
kubectl get endpoints web-app-clusterip -n lab01-services
# Should list 3 pod IPs on port 80

kubectl get endpointslice -n lab01-services \
  -l kubernetes.io/service-name=web-app-clusterip
```

### Step 4: Reproduce the "No Endpoints" Exam Trap
```bash
kubectl apply -f - << 'EOF'
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
# <none>  ← selector doesn't match any pod's labels

# Fix it:
kubectl patch svc broken-service -n lab01-services \
  -p '{"spec":{"selector":{"app":"web-app"}}}'

kubectl get endpoints broken-service -n lab01-services
# Now shows 3 endpoints
```

### Step 5: Create NodePort
```bash
kubectl apply -f - << 'EOF'
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
```

### Step 6: Test Connectivity
```bash
kubectl run test-client --image=busybox -n lab01-services -- sleep 3600
kubectl wait --for=condition=ready pod/test-client -n lab01-services --timeout=60s

# Via ClusterIP
CLUSTER_IP=$(kubectl get svc web-app-clusterip -n lab01-services -o jsonpath='{.spec.clusterIP}')
kubectl exec test-client -n lab01-services -- wget -qO- http://$CLUSTER_IP

# Via DNS name
kubectl exec test-client -n lab01-services -- wget -qO- http://web-app-clusterip

# NodePort from the node
minikube ssh "curl -s http://localhost:30080" | head -3
```

---

## How Service Routing Actually Works

```
1. Client sends request to Service ClusterIP:port
2. kube-proxy (on every node) intercepts via iptables/IPVS rules
3. Rules forward to one of the pod IPs listed in EndpointSlice
4. Pod responds directly back to client (DNAT, not a real proxy hop)
```

---

## Key Takeaways

✅ ClusterIP is the default type — internal only
✅ NodePort = ClusterIP + a port opened on every node (30000-32767)
✅ Service `selector` must exactly match pod `labels` or Endpoints stay empty
✅ EndpointSlice is what kube-proxy actually watches (Endpoints kept for compatibility)
✅ `port` = Service's port, `targetPort` = container's port, `nodePort` = node's port
✅ "Service not reachable" exam questions are almost always a selector mismatch

---

**Completed Lab 01?** ✅

Move to **[Lab 02: LoadBalancer & Headless Services](../02-loadbalancer-headless/)**