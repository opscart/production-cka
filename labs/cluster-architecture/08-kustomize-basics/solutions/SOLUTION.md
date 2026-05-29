# Lab 08: Kustomize Basics - Solution Guide

## Quick Solution (Exam Speed)

```bash
# 1. Create structure (30 sec)
mkdir -p myapp/{base,overlays/{dev,prod}}

# 2. Create base (1 min)
cat > myapp/base/kustomization.yaml << 'EOF'
resources:
- deployment.yaml
- service.yaml
EOF

# 3. Create overlay (1 min)
cat > myapp/overlays/prod/kustomization.yaml << 'EOF'
resources:
- ../../base
namePrefix: prod-
patches:
- patch: |-
    - op: replace
      path: /spec/replicas
      value: 3
  target:
    kind: Deployment
    name: my-app
EOF

# 4. Apply (30 sec)
kubectl apply -k myapp/overlays/prod/
```

---

## Complete Solution

### Run the Setup Script

```bash
./scripts/setup.sh
```

This creates:
- `kustomize-demo/base/` - shared deployment and service
- `kustomize-demo/overlays/dev/` - 1 replica, latest image
- `kustomize-demo/overlays/staging/` - 2 replicas
- `kustomize-demo/overlays/prod/` - 3 replicas, NodePort

### Verify Rendering

```bash
# Base
kubectl kustomize kustomize-demo/base/

# Dev (1 replica, dev- prefix, environment=dev label)
kubectl kustomize kustomize-demo/overlays/dev/

# Prod (3 replicas, NodePort service)
kubectl kustomize kustomize-demo/overlays/prod/
```

### Deploy and Verify

```bash
# Deploy dev
kubectl apply -k kustomize-demo/overlays/dev/

# Deploy staging
kubectl apply -k kustomize-demo/overlays/staging/

# Check deployments
kubectl get deployments
# dev-pharma-api:     1/1 Ready
# staging-pharma-api: 2/2 Ready

# Check labels
kubectl get deployments -l environment=dev
kubectl get deployments -l environment=staging
```

### Run Automated Tests

```bash
./scripts/test.sh
# Should show 10/10 checks passed
```

---

## Key Takeaways

✅ `kubectl apply -k` applies kustomize configs  
✅ `kubectl kustomize` renders without applying  
✅ `resources:` replaces old `bases:` syntax  
✅ `namePrefix:` prefixes all resource names  
✅ `commonLabels:` adds labels to all resources  
✅ `patches:` modifies specific fields  
✅ `images:` overrides image tags cleanly  

---

**Completed Lab 08?** ✅

Move to **[Lab 09: High Availability Clusters](../09-high-availability/)**
