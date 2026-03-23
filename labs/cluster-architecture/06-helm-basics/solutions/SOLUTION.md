# Lab 06: Helm Basics - Solution Guide

## Complete Workflow

This solution walks through all tasks in Lab 06.

---

## Task 1: Install Helm (5 min)

### Solution

```bash
# On macOS
brew install helm

# Verify
helm version
# version.BuildInfo{Version:"v3.14.0", GitCommit:"..."}

# Or use the script
./scripts/install-helm.sh
```

**Verification:**
```bash
helm help
# Should show list of available commands
```

---

## Task 2: Understanding Helm Charts (10 min)

### Solution

```bash
# Add bitnami repository
helm repo add bitnami https://charts.bitnami.com/bitnami

# Update repositories
helm repo update

# Search for nginx
helm search repo nginx

# Show chart information
helm show chart bitnami/nginx

# Show default values
helm show values bitnami/nginx | head -50

# Show all information
helm show all bitnami/nginx | less
```

**What you learned:**
- Charts are packages of Kubernetes resources
- Repositories host charts
- `helm show` reveals chart configuration

---

## Task 3: Install Application with Helm (10 min)

### Solution

```bash
# Install nginx
helm install my-nginx bitnami/nginx

# Wait for deployment
kubectl wait --for=condition=available --timeout=60s deployment/my-nginx

# List releases
helm list

# Check Kubernetes resources
kubectl get all -l app.kubernetes.io/instance=my-nginx

# Port forward to access
kubectl port-forward svc/my-nginx 8080:80

# Test (in another terminal)
curl http://localhost:8080
```

**What happened:**
- Helm created Deployment, Service, ConfigMap
- All tracked as single "release"
- Can manage as one unit

---

## Task 4: Customize Installation (10 min)

### Solution

**Create values file:**

```bash
cat > custom-values.yaml << 'EOF'
replicaCount: 3

service:
  type: NodePort
  nodePorts:
    http: 30080

resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi
EOF
```

**Install with custom values:**

```bash
# Method 1: Using values file
helm install custom-nginx bitnami/nginx -f custom-values.yaml

# Method 2: Inline values
helm install custom-nginx bitnami/nginx \
  --set replicaCount=3 \
  --set service.type=NodePort \
  --set service.nodePorts.http=30080
```

**Verify customization:**

```bash
# Check replicas
kubectl get deployment custom-nginx -o jsonpath='{.spec.replicas}'
# Output: 3

# Check service type
kubectl get svc custom-nginx -o jsonpath='{.spec.type}'
# Output: NodePort

# Check NodePort
kubectl get svc custom-nginx -o jsonpath='{.spec.ports[0].nodePort}'
# Output: 30080

# Test access
minikube service custom-nginx --url
# Or: curl $(minikube ip):30080
```

---

## Task 5: Upgrade and Rollback (15 min)

### Solution

**Upgrade release:**

```bash
# Increase replicas
helm upgrade custom-nginx bitnami/nginx \
  --set replicaCount=5 \
  --set service.type=NodePort

# Verify upgrade
kubectl get pods -l app.kubernetes.io/instance=custom-nginx
# Should see 5 pods

# Check revision history
helm history custom-nginx
# REVISION  UPDATED                  STATUS      DESCRIPTION
# 1         ... deployed      Install complete
# 2         ... superseded    Upgrade complete
```

**Get release information:**

```bash
# Status
helm status custom-nginx

# Values used
helm get values custom-nginx

# Manifest
helm get manifest custom-nginx
```

**Rollback release:**

```bash
# Rollback to previous version
helm rollback custom-nginx

# Or specific revision
helm rollback custom-nginx 1

# Verify rollback
helm history custom-nginx
# REVISION  UPDATED                  STATUS      DESCRIPTION
# 1         ... superseded    Install complete
# 2         ... superseded    Upgrade complete
# 3         ... deployed      Rollback to 1

kubectl get pods -l app.kubernetes.io/instance=custom-nginx
# Should be back to 3 pods
```

---

## Task 6: Uninstall Releases (5 min)

### Solution

```bash
# List all releases
helm list

# Uninstall my-nginx
helm uninstall my-nginx

# Verify it's gone
helm list
kubectl get all -l app.kubernetes.io/instance=my-nginx
# No resources found

# Uninstall but keep history
helm uninstall custom-nginx --keep-history

# History still available
helm history custom-nginx
```

---

## Exam Simulation (5-7 minutes)

**Scenario:** Install nginx with 3 replicas, upgrade to 5, then rollback

```bash
# 1. Add repo (30 sec)
helm repo add bitnami https://charts.bitnami.com/bitnami

# 2. Install with 3 replicas (1 min)
helm install web bitnami/nginx --set replicaCount=3

# 3. Verify (30 sec)
kubectl get pods -l app.kubernetes.io/instance=web
# Should see 3 pods

# 4. Upgrade to 5 replicas (1 min)
helm upgrade web bitnami/nginx --set replicaCount=5

# 5. Verify upgrade (30 sec)
kubectl get pods -l app.kubernetes.io/instance=web
# Should see 5 pods

# 6. Rollback (30 sec)
helm rollback web

# 7. Verify rollback (30 sec)
kubectl get pods -l app.kubernetes.io/instance=web
# Should see 3 pods again

# 8. Cleanup
helm uninstall web
```

**Total time: ~5 minutes**

---

## Common Issues & Solutions

### Issue: Helm Not Found

**Error:**
```
helm: command not found
```

**Solution:**
```bash
# macOS
brew install helm

# Linux
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

---

### Issue: Repository Not Found

**Error:**
```
Error: repo "bitnami" not found
```

**Solution:**
```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

---

### Issue: Release Already Exists

**Error:**
```
Error: cannot re-use a name that is still in use
```

**Solution:**
```bash
# Use different name
helm install my-app-2 bitnami/nginx

# Or uninstall existing
helm uninstall my-app
```

---

### Issue: Upgrade Failed

**Error:**
```
Error: UPGRADE FAILED
```

**Solution:**
```bash
# Check status
helm status my-app

# Check history
helm history my-app

# Rollback
helm rollback my-app

# Or uninstall and reinstall
helm uninstall my-app
helm install my-app bitnami/nginx
```

---

## Key Takeaways

**Helm simplifies deployment** - One command vs many YAML files  
**Values files = configuration** - Same chart, different configs  
**Releases = deployments** - Track versions and history  
**Rollback is easy** - helm rollback in seconds  
**Repositories = distribution** - Share charts easily  

---

## Production Tips

### 1. Always Specify Versions

```bash
# Don't do this (uses latest)
helm install my-app bitnami/nginx

# Do this (locked version)
helm install my-app bitnami/nginx --version 15.0.0
```

### 2. Use Values Files for Environments

```
values-dev.yaml
values-staging.yaml
values-prod.yaml
```

### 3. Test Before Installing

```bash
# Dry run
helm install my-app bitnami/nginx --dry-run --debug

# Generate manifest
helm template my-app bitnami/nginx
```

### 4. Use Namespaces

```bash
helm install my-app bitnami/nginx -n production
```

---

**Completed Lab 06?** ✅

Move to **[Lab 07: Helm Charts](../07-helm-charts/)**

In Lab 07, you'll create your own Helm charts from scratch!