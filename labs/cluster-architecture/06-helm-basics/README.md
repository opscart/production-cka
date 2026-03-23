# Lab 06: Helm Basics

## Objective
Master Helm package manager fundamentals, understand charts, releases, and repositories. Learn to install, upgrade, and manage applications using Helm on Kubernetes clusters.

## CKA Exam Relevance
- **Domain:** Cluster Architecture, Installation & Configuration (25%)
- **Topic:** Use Helm to manage Kubernetes applications (NEW in 2026)
- **Exam Weight:** Medium-High (appears in 40-50% of exams)
- **Typical Exam Time:** 5-7 minutes

## Time to Complete
40 minutes

## Scenario
Your pharmaceutical company is standardizing application deployment across 8+ AKS clusters. The DevOps team needs to:
- Deploy applications consistently across environments
- Manage configuration variations (dev, staging, prod)
- Version control application releases
- Enable easy rollbacks
- Reduce YAML duplication

Helm is the solution! It's the "package manager for Kubernetes" - like apt/yum for Linux or npm for Node.js.

## Prerequisites
- Completed Labs 01-05
- Running minikube cluster
- Basic understanding of Kubernetes objects
- Familiarity with YAML

## What is Helm?

**Helm** is the package manager for Kubernetes:
- **Charts:** Packages of pre-configured Kubernetes resources
- **Releases:** Deployed instances of charts
- **Repositories:** Collections of charts (like Docker Hub for Helm)

**Why Helm?**
- Package complex applications (all resources in one)
- Manage configurations (values files)
- Version control deployments
- Easy rollbacks
- Share and reuse charts

---

## Helm Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Your Workstation                         │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              helm CLI                                 │  │
│  │                                                       │  │
│  │  Commands:                                            │  │
│  │  - helm install                                       │  │
│  │  - helm upgrade                                       │  │
│  │  - helm rollback                                      │  │
│  │  - helm list                                          │  │
│  └────────────────┬─────────────────────────────────────┘  │
│                   │                                          │
└───────────────────┼──────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│              Kubernetes Cluster                              │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │         Release History (Secrets/ConfigMaps)           │ │
│  │  release-v1, release-v2, release-v3...                 │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │            Deployed Resources                          │ │
│  │  - Deployments                                         │ │
│  │  - Services                                            │ │
│  │  - ConfigMaps                                          │ │
│  │  - Secrets                                             │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘

Helm Chart Structure:
mychart/
├── Chart.yaml        # Chart metadata
├── values.yaml       # Default configuration
├── templates/        # Kubernetes YAML templates
│   ├── deployment.yaml
│   ├── service.yaml
│   └── ingress.yaml
└── charts/           # Dependent charts
```

---

## Lab Structure

```
lab06-helm-basics/
├── README.md
├── QUICK-REFERENCE.md
├── charts/
│   └── demo-app/                # Sample Helm chart
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
├── scripts/
│   ├── install-helm.sh          # Install Helm CLI
│   ├── demo-install.sh          # Install demo chart
│   └── cleanup.sh               # Remove releases
└── solutions/
    └── SOLUTION.md
```

---

## Tasks

### Task 1: Install Helm (5 min)

**Objective:** Install Helm CLI and verify installation.

**Install Helm on macOS:**

```bash
# Using Homebrew (recommended)
brew install helm

# Verify installation
helm version
# version.BuildInfo{Version:"v3.14.0", ...}

# Check available commands
helm help
```

**Verify connection to cluster:**

```bash
# Helm uses your kubeconfig
kubectl config current-context
# opscart

# Helm should see your cluster
helm list
# (empty - no releases yet)
```

---

### Task 2: Understanding Helm Charts (10 min)

**Objective:** Explore chart structure and components.

**Add a Helm repository:**

```bash
# Add the official "stable" charts repo (moved to artifact hub)
helm repo add bitnami https://charts.bitnami.com/bitnami

# Update repo cache
helm repo update

# Search for charts
helm search repo nginx
# Shows all nginx-related charts

# Search specific chart
helm search repo bitnami/nginx
```

**Inspect a chart:**

```bash
# Show chart information
helm show chart bitnami/nginx

# Show default values
helm show values bitnami/nginx | head -30

# Show all chart info
helm show all bitnami/nginx | less
```

**Key components:**
- **Chart.yaml:** Metadata (name, version, description)
- **values.yaml:** Default configuration
- **templates/:** Kubernetes YAML with Go templating
- **charts/:** Dependencies

---

### Task 3: Install an Application with Helm (10 min)

**Objective:** Deploy nginx using Helm.

**Install nginx chart:**

```bash
# Syntax: helm install <release-name> <chart>
helm install my-nginx bitnami/nginx

# Output shows:
# - Release name
# - Namespace
# - Status
# - Resources created
# - Notes (how to access app)
```

**What just happened?**

Helm created:
1. Deployment (nginx pods)
2. Service (LoadBalancer type)
3. ConfigMap (nginx config)
4. Secret (if needed)

**Verify the installation:**

```bash
# List Helm releases
helm list

# Check Kubernetes resources
kubectl get all -l app.kubernetes.io/instance=my-nginx

# Check pods
kubectl get pods -l app.kubernetes.io/instance=my-nginx

# Check service
kubectl get svc my-nginx
```

**Access the application:**

```bash
# On minikube, use port-forward
kubectl port-forward svc/my-nginx 8080:80

# Open browser: http://localhost:8080
# Or: curl http://localhost:8080
```

---

### Task 4: Customize Installation with Values (10 min)

**Objective:** Install chart with custom configuration.

**View default values:**

```bash
# Show all configurable values
helm show values bitnami/nginx > nginx-values.yaml

# View the file
cat nginx-values.yaml | less
```

**Create custom values file:**

```bash
cat > custom-values.yaml << 'EOF'
# Custom configuration for nginx
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
# Install with custom config
helm install my-custom-nginx bitnami/nginx -f custom-values.yaml

# Or override specific values inline
helm install my-custom-nginx bitnami/nginx \
  --set replicaCount=3 \
  --set service.type=NodePort

# List releases
helm list
```

**Verify customization:**

```bash
# Check replica count
kubectl get deployment my-custom-nginx -o jsonpath='{.spec.replicas}'
# Should show: 3

# Check service type
kubectl get svc my-custom-nginx -o jsonpath='{.spec.type}'
# Should show: NodePort

# Check resource limits
kubectl get deployment my-custom-nginx -o yaml | grep -A 4 resources
```

---

### Task 5: Upgrade and Rollback Releases (15 min)

**Objective:** Update deployed applications and rollback if needed.

**Upgrade a release:**

```bash
# Change replica count
helm upgrade my-custom-nginx bitnami/nginx \
  --set replicaCount=5

# Verify upgrade
kubectl get pods -l app.kubernetes.io/instance=my-custom-nginx
# Should see 5 pods

# Check revision history
helm history my-custom-nginx
```

**View release status:**

```bash
# Get release details
helm status my-custom-nginx

# Get values used in current release
helm get values my-custom-nginx

# Get manifest (actual Kubernetes YAML)
helm get manifest my-custom-nginx
```

**Rollback a release:**

```bash
# Rollback to previous version
helm rollback my-custom-nginx

# Or rollback to specific revision
helm rollback my-custom-nginx 1

# Verify rollback
helm history my-custom-nginx
kubectl get pods -l app.kubernetes.io/instance=my-custom-nginx
# Should be back to 3 pods
```

---

### Task 6: Uninstall Releases (5 min)

**Objective:** Clean up Helm releases.

**List all releases:**

```bash
helm list
# Shows: my-nginx, my-custom-nginx
```

**Uninstall a release:**

```bash
# Uninstall release
helm uninstall my-nginx

# Verify it's gone
helm list
kubectl get all -l app.kubernetes.io/instance=my-nginx
# No resources found
```

**Keep release history:**

```bash
# Uninstall but keep history (for rollback)
helm uninstall my-custom-nginx --keep-history

# History still available
helm history my-custom-nginx
```

---

## Validation Checklist

**After completing this lab, you should be able to:**

- [ ] Install Helm CLI
- [ ] Add and update Helm repositories
- [ ] Search for charts
- [ ] Install charts with default values
- [ ] Customize installations with values files
- [ ] Use --set for inline value overrides
- [ ] Upgrade releases
- [ ] Rollback releases
- [ ] List and inspect releases
- [ ] Uninstall releases

---

## Common Helm Commands

### Repository Management

```bash
# Add repository
helm repo add <name> <url>

# Update repositories
helm repo update

# List repositories
helm repo list

# Remove repository
helm repo remove <name>
```

### Chart Management

```bash
# Search charts
helm search repo <keyword>

# Show chart info
helm show chart <chart>
helm show values <chart>
helm show all <chart>
```

### Release Management

```bash
# Install chart
helm install <release-name> <chart>
helm install <release-name> <chart> -f values.yaml
helm install <release-name> <chart> --set key=value

# List releases
helm list
helm list --all-namespaces

# Get release info
helm status <release-name>
helm get values <release-name>
helm get manifest <release-name>

# Upgrade release
helm upgrade <release-name> <chart>
helm upgrade <release-name> <chart> -f values.yaml

# Rollback release
helm rollback <release-name>
helm rollback <release-name> <revision>

# Uninstall release
helm uninstall <release-name>
helm uninstall <release-name> --keep-history

# Release history
helm history <release-name>
```

---

## Production Best Practices

### 1. Version Everything

```bash
# Always specify chart version
helm install my-app bitnami/nginx --version 15.0.0

# Check chart versions
helm search repo bitnami/nginx --versions
```

### 2. Use Values Files

```bash
# Separate values per environment
values-dev.yaml
values-staging.yaml
values-prod.yaml

# Deploy to specific environment
helm install my-app ./chart -f values-prod.yaml
```

### 3. Namespace Isolation

```bash
# Create namespace
kubectl create namespace production

# Install to namespace
helm install my-app bitnami/nginx -n production

# List releases in namespace
helm list -n production
```

### 4. Dry Run Before Install

```bash
# Test rendering (don't install)
helm install my-app bitnami/nginx --dry-run --debug

# See what will be created
helm template my-app bitnami/nginx
```

### 5. Monitor Releases

```bash
# Watch release status
helm status my-app

# Check upgrade in progress
kubectl rollout status deployment/my-app
```

---

## Exam Tips

⏱️ **Time Management:**
- Install Helm: 1 minute
- Add repo: 1 minute
- Install chart: 2-3 minutes
- Customize values: 2 minutes
- **Total: ~5-7 minutes**

🔑 **Quick Commands (Exam Speed):**

```bash
# Install with inline values
helm install app repo/chart --set key=value

# Upgrade release
helm upgrade app repo/chart --set key=newvalue

# Rollback
helm rollback app

# Uninstall
helm uninstall app
```

📖 **Documentation Reference (Allowed in Exam):**
- Helm docs: helm.sh/docs
- Search: "helm install", "helm values"

🎯 **Exam Question Patterns:**

> *"Install nginx using Helm with 3 replicas"*

> *"Upgrade the release to use NodePort service type"*

> *"Rollback the application to previous version"*

---

## Troubleshooting

### Issue 1: Helm Not Found

**Error:**
```
helm: command not found
```

**Solution:**
```bash
# Install Helm
brew install helm  # macOS
# Or download from: https://helm.sh/docs/intro/install/
```

---

### Issue 2: Repository Not Found

**Error:**
```
Error: repo not found
```

**Solution:**
```bash
# Add repository first
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

---

### Issue 3: Release Already Exists

**Error:**
```
Error: cannot re-use a name that is still in use
```

**Solution:**
```bash
# Use different release name
helm install my-app-2 bitnami/nginx

# Or uninstall existing
helm uninstall my-app
```

---

### Issue 4: Upgrade Failed

**Error:**
```
Error: UPGRADE FAILED
```

**Solution:**
```bash
# Check release status
helm status my-app

# Rollback
helm rollback my-app

# Check history
helm history my-app
```

---

## Next Lab

Ready to continue? Move to **[Lab 07: Helm Charts](../07-helm-charts/README.md)**

In Lab 07, you'll learn:
- Create custom Helm charts
- Chart templating with Go templates
- Dependencies and subcharts
- Package and distribute charts

---

**Author:** Shamsher Khan | **Blog:** opscart.com | **Course:** Production CKA 2026
