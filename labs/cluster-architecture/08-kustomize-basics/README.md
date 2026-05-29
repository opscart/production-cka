# Lab 08: Kustomize Basics

## Objective
Master Kustomize for managing Kubernetes configuration across multiple environments without templating. Learn to use bases, overlays, and patches to customize manifests for dev, staging, and production.

## CKA Exam Relevance
- **Domain:** Cluster Architecture, Installation & Configuration (25%)
- **Topic:** Use Kustomize to manage Kubernetes configurations (NEW in 2026)
- **Exam Weight:** Medium (30-40% of exams)
- **Typical Exam Time:** 5-7 minutes

## Time to Complete
40 minutes

## Scenario
Your pharmaceutical company deploys the same application to 3 environments. With plain YAML you maintain 3 copies of every file. With Helm you need templates. Kustomize offers a third approach — **pure YAML with overlays**. No templates, no new syntax, just YAML patches.

**The problem:**
```
Without Kustomize:           With Kustomize:
───────────────────          ──────────────────
dev/deployment.yaml          base/
dev/service.yaml               deployment.yaml  (1 copy)
staging/deployment.yaml        service.yaml     (1 copy)
staging/service.yaml         overlays/
prod/deployment.yaml           dev/
prod/service.yaml              staging/
(6 files, lots of duplication) prod/
                             (base + small patches only)
```

---

## Kustomize vs Helm

```
┌─────────────────┬──────────────────────┬──────────────────────┐
│ Feature         │ Kustomize            │ Helm                 │
├─────────────────┼──────────────────────┼──────────────────────┤
│ Syntax          │ Pure YAML            │ Go templates         │
│ Learning curve  │ Low                  │ Medium               │
│ Templating      │ No (overlays)        │ Yes ({{ .Values }})  │
│ Built into      │ kubectl (built-in!)  │ Separate CLI         │
│ Best for        │ Config variations    │ Complex apps         │
│ CKA exam        │ kubectl -k flag      │ helm commands        │
└─────────────────┴──────────────────────┴──────────────────────┘
```

**Key insight:** Kustomize is built into `kubectl`! No installation needed.

```bash
kubectl apply -k ./overlays/dev/    # -k = kustomize!
```

---

## Kustomize Structure

```
kustomize-demo/
├── base/                        # Shared base configuration
│   ├── kustomization.yaml       # Lists resources to include
│   ├── deployment.yaml
│   └── service.yaml
└── overlays/
    ├── dev/                     # Dev-specific patches
    │   ├── kustomization.yaml
    │   └── patch-replicas.yaml
    ├── staging/
    │   ├── kustomization.yaml
    │   └── patch-replicas.yaml
    └── prod/
        ├── kustomization.yaml
        └── patch-replicas.yaml
```

---

## Tasks

### Task 1: Understand Kustomize (5 min)

**Objective:** Verify kustomize is available and understand its integration with kubectl.

```bash
# Check kustomize version (built into kubectl)
kubectl version --client

# Standalone kustomize (also available)
kustomize version

# Check if kustomize is available
kubectl kustomize --help
```

**Key commands:**
```bash
# Build/render kustomize output
kubectl kustomize <dir>

# Apply kustomize configuration
kubectl apply -k <dir>

# Delete kustomize resources
kubectl delete -k <dir>
```

---

### Task 2: Create Base Configuration (10 min)

**Objective:** Build the shared base manifests.

```bash
# Create directory structure
mkdir -p kustomize-demo/base
mkdir -p kustomize-demo/overlays/{dev,staging,prod}
cd kustomize-demo
```

**Create base deployment:**
```bash
cat > base/deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pharma-api
  labels:
    app: pharma-api
spec:
  replicas: 1
  selector:
    matchLabels:
      app: pharma-api
  template:
    metadata:
      labels:
        app: pharma-api
    spec:
      containers:
      - name: pharma-api
        image: nginx:1.25
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
EOF
```

**Create base service:**
```bash
cat > base/service.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: pharma-api
spec:
  selector:
    app: pharma-api
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF
```

**Create base kustomization.yaml:**
```bash
cat > base/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml
- service.yaml
EOF
```

**Verify base renders correctly:**
```bash
kubectl kustomize base/
# Should output both deployment and service YAML
```

---

### Task 3: Create Environment Overlays (15 min)

**Objective:** Create overlays with environment-specific patches.

#### Dev Overlay (1 replica, debug image tag)

```bash
cat > overlays/dev/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
- ../../base

namePrefix: dev-

patches:
- patch: |-
    - op: replace
      path: /spec/replicas
      value: 1
    - op: replace
      path: /spec/template/spec/containers/0/image
      value: nginx:latest
  target:
    kind: Deployment
    name: pharma-api

commonLabels:
  environment: dev
EOF
```

#### Staging Overlay (2 replicas)

```bash
cat > overlays/staging/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
- ../../base

namePrefix: staging-

patches:
- patch: |-
    - op: replace
      path: /spec/replicas
      value: 2
  target:
    kind: Deployment
    name: pharma-api

commonLabels:
  environment: staging
EOF
```

#### Production Overlay (3 replicas, NodePort)

```bash
cat > overlays/prod/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
- ../../base

namePrefix: prod-

patches:
- patch: |-
    - op: replace
      path: /spec/replicas
      value: 3
  target:
    kind: Deployment
    name: pharma-api
- patch: |-
    - op: replace
      path: /spec/type
      value: NodePort
  target:
    kind: Service
    name: pharma-api

commonLabels:
  environment: prod
EOF
```

**Verify overlays render correctly:**
```bash
# Check dev
kubectl kustomize overlays/dev/

# Check prod (should show 3 replicas, NodePort)
kubectl kustomize overlays/prod/
```

---

### Task 4: Deploy with Kustomize (10 min)

**Objective:** Apply overlays to the cluster.

```bash
# Deploy dev
kubectl apply -k overlays/dev/
kubectl get all -l environment=dev

# Deploy staging
kubectl apply -k overlays/staging/
kubectl get all -l environment=staging

# Verify different replica counts
kubectl get deployments
# dev-pharma-api:     1 replica
# staging-pharma-api: 2 replicas
```

**Verify patches applied correctly:**
```bash
# Dev should have 1 replica
kubectl get deploy dev-pharma-api -o jsonpath='{.spec.replicas}'

# Staging should have 2 replicas
kubectl get deploy staging-pharma-api -o jsonpath='{.spec.replicas}'
```

---

### Task 5: Update Base and Propagate (5 min)

**Objective:** Change base and see it propagate to all environments.

```bash
# Update base image version
# Edit base/deployment.yaml
# Change: image: nginx:1.25
# To:     image: nginx:1.26

# Now render dev - should pick up new image
kubectl kustomize overlays/dev/

# Apply update to all environments
kubectl apply -k overlays/dev/
kubectl apply -k overlays/staging/
```

---

## Exam Tips

⏱️ **Time Management:**
- Create base: 2 minutes
- Create overlays: 2 minutes
- Apply: 1 minute
- **Total: ~5 minutes**

🔑 **Key Commands:**
```bash
# Build (render without applying)
kubectl kustomize <dir>

# Apply
kubectl apply -k <dir>

# Delete
kubectl delete -k <dir>
```

🎯 **Exam Question Patterns:**

> *"Apply the kustomize configuration in /root/kustomize/overlays/prod"*

> *"Create a kustomize overlay that changes replicas to 3"*

> *"Build the kustomize output and redirect to a file"*

---

## Common Issues

### Issue 1: bases vs resources

```yaml
# Old syntax (still works)
bases:
- ../../base

# New syntax (preferred)
resources:
- ../../base
```

### Issue 2: Wrong directory

```bash
# Always run from the lab root
kubectl kustomize overlays/dev/   # ✅
kubectl kustomize dev/            # ❌ (wrong path)
```

---

## Next Lab

Move to **[Lab 09: High Availability Clusters](../09-high-availability/README.md)**

---

**Author:** Shamsher Khan | **Blog:** opscart.com | **Course:** Production CKA 2026
