# Lab 06: Helm Basics - Quick Reference

## Essential Helm Commands

### Installation

```bash
# macOS
brew install helm

# Verify
helm version
```

---

## Repository Commands

```bash
# Add repository
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add stable https://charts.helm.sh/stable

# Update repos
helm repo update

# List repos
helm repo list

# Remove repo
helm repo remove bitnami

# Search charts
helm search repo nginx
helm search repo bitnami/nginx --versions
```

---

## Chart Information

```bash
# Show chart metadata
helm show chart bitnami/nginx

# Show default values
helm show values bitnami/nginx

# Show README
helm show readme bitnami/nginx

# Show everything
helm show all bitnami/nginx
```

---

## Install Commands

```bash
# Basic install
helm install my-app bitnami/nginx

# Install with custom values file
helm install my-app bitnami/nginx -f values.yaml

# Install with inline values
helm install my-app bitnami/nginx --set replicaCount=3

# Install specific version
helm install my-app bitnami/nginx --version 15.0.0

# Install to namespace
helm install my-app bitnami/nginx -n production

# Dry run (test without installing)
helm install my-app bitnami/nginx --dry-run --debug

# Generate manifest (see YAML)
helm template my-app bitnami/nginx
```

---

## List & Status Commands

```bash
# List all releases
helm list

# List in all namespaces
helm list --all-namespaces

# List in specific namespace
helm list -n production

# Show release status
helm status my-app

# Get deployed values
helm get values my-app

# Get manifest
helm get manifest my-app

# Get all info
helm get all my-app
```

---

## Upgrade Commands

```bash
# Upgrade with new values
helm upgrade my-app bitnami/nginx -f values.yaml

# Upgrade with inline values
helm upgrade my-app bitnami/nginx --set replicaCount=5

# Upgrade and wait for completion
helm upgrade my-app bitnami/nginx --wait

# Upgrade or install if not exists
helm upgrade --install my-app bitnami/nginx
```

---

## Rollback Commands

```bash
# Show history
helm history my-app

# Rollback to previous version
helm rollback my-app

# Rollback to specific revision
helm rollback my-app 2

# Rollback and wait
helm rollback my-app --wait
```

---

## Uninstall Commands

```bash
# Uninstall release
helm uninstall my-app

# Uninstall but keep history
helm uninstall my-app --keep-history

# Uninstall from namespace
helm uninstall my-app -n production
```

---

## Exam Scenarios

### Scenario 1: Install Application

**Question:** Install nginx with Helm, name it "web-server", 3 replicas

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install web-server bitnami/nginx --set replicaCount=3
```

---

### Scenario 2: Customize Configuration

**Question:** Install nginx with NodePort service on port 30080

```bash
helm install my-nginx bitnami/nginx \
  --set service.type=NodePort \
  --set service.nodePorts.http=30080
```

---

### Scenario 3: Upgrade Release

**Question:** Upgrade "web-server" to use 5 replicas

```bash
helm upgrade web-server bitnami/nginx --set replicaCount=5
```

---

### Scenario 4: Rollback Release

**Question:** Rollback "web-server" to previous version

```bash
helm rollback web-server
```

---

### Scenario 5: Install from Values File

**Question:** Install chart using values from production.yaml

```bash
helm install prod-app bitnami/nginx -f production.yaml
```

---

## Common Value Overrides

### Replica Count

```bash
--set replicaCount=3
```

### Service Type

```bash
--set service.type=NodePort
--set service.type=LoadBalancer
--set service.type=ClusterIP
```

### Resource Limits

```bash
--set resources.limits.cpu=200m
--set resources.limits.memory=256Mi
--set resources.requests.cpu=100m
--set resources.requests.memory=128Mi
```

### Image Configuration

```bash
--set image.repository=nginx
--set image.tag=1.21.0
--set image.pullPolicy=IfNotPresent
```

### Environment Variables

```bash
--set env[0].name=ENV_VAR
--set env[0].value=value
```

---

## Helm Release States

```
deployed    - Successfully installed/upgraded
superseded  - Replaced by upgrade
uninstalled - Removed
failed      - Installation/upgrade failed
pending     - Operation in progress
```

---

## Troubleshooting

### Check Release Status

```bash
helm status my-app
kubectl get all -l app.kubernetes.io/instance=my-app
```

### Debug Failed Install

```bash
# Show what would be created
helm install my-app bitnami/nginx --dry-run --debug

# Check rendered templates
helm template my-app bitnami/nginx

# Check logs
kubectl logs -l app.kubernetes.io/instance=my-app
```

### Fix Failed Upgrade

```bash
# Check history
helm history my-app

# Rollback
helm rollback my-app
```

---

## Time Budget (Exam)

- Add repository: **30 seconds**
- Search chart: **30 seconds**
- Install chart: **1 minute**
- Customize values: **1-2 minutes**
- Upgrade: **1 minute**
- Rollback: **30 seconds**
- **Total: ~5-7 minutes**

---

## Documentation Links (Allowed in Exam)

- https://helm.sh/docs/
- https://helm.sh/docs/intro/install/
- https://helm.sh/docs/helm/helm_install/
- https://helm.sh/docs/helm/helm_upgrade/

Search keywords: "helm install", "helm values", "helm rollback"