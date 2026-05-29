# Lab 08: Kustomize Basics - Quick Reference

## Core Commands

```bash
# Render (build) without applying
kubectl kustomize <dir>

# Apply kustomize
kubectl apply -k <dir>

# Delete kustomize resources
kubectl delete -k <dir>

# Pipe output to file
kubectl kustomize <dir> > output.yaml
kubectl apply -f output.yaml
```

---

## kustomization.yaml Fields

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# Include resources (base or local files)
resources:
- deployment.yaml
- service.yaml
- ../../base          # Reference to base

# Add prefix/suffix to all resource names
namePrefix: dev-
nameSuffix: -v2

# Add labels to all resources
commonLabels:
  environment: dev
  team: platform

# Add annotations to all resources
commonAnnotations:
  managed-by: kustomize

# Patches (inline JSON6902)
patches:
- patch: |-
    - op: replace
      path: /spec/replicas
      value: 3
  target:
    kind: Deployment
    name: my-app

# Images (override image tags)
images:
- name: nginx
  newTag: "1.26"
- name: myapp
  newName: myapp-prod
  newTag: "2.0"
```

---

## Patch Operations

```yaml
# Replace a value
- op: replace
  path: /spec/replicas
  value: 3

# Add a value
- op: add
  path: /spec/template/spec/containers/0/env/-
  value:
    name: ENV_VAR
    value: "production"

# Remove a field
- op: remove
  path: /spec/template/spec/containers/0/resources/limits
```

---

## Directory Structure

```
app/
├── base/
│   ├── kustomization.yaml   # lists resources
│   ├── deployment.yaml
│   └── service.yaml
└── overlays/
    ├── dev/
    │   └── kustomization.yaml   # references base + patches
    ├── staging/
    │   └── kustomization.yaml
    └── prod/
        └── kustomization.yaml
```

---

## Exam Scenarios

### Scenario 1: Apply Kustomize Config

```bash
# Apply from directory
kubectl apply -k /root/kustomize/overlays/prod/

# Verify
kubectl get all -l environment=prod
```

### Scenario 2: Change Replicas via Patch

```yaml
# In overlays/prod/kustomization.yaml
patches:
- patch: |-
    - op: replace
      path: /spec/replicas
      value: 5
  target:
    kind: Deployment
    name: my-app
```

### Scenario 3: Override Image Tag

```yaml
images:
- name: nginx
  newTag: "1.26"
```

### Scenario 4: Add Name Prefix

```yaml
namePrefix: prod-
# my-app becomes prod-my-app
```

---

## Kustomize vs Helm

```
Kustomize:
✅ Built into kubectl
✅ Pure YAML (no new syntax)
✅ Simple overlays
❌ No loops or conditionals

Helm:
✅ Full templating (Go)
✅ Package distribution
✅ Release management
❌ Requires separate CLI
```

---

## Time Budget (Exam)

- Create base: **1 minute**
- Create overlay: **1 minute**
- Apply: **30 seconds**
- Verify: **30 seconds**
- **Total: ~3-4 minutes**
