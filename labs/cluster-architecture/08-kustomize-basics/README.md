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

## Prerequisites
- Completed Labs 01-07
- Running minikube cluster
- Basic YAML knowledge

---

## Kustomize vs Helm

```
┌─────────────────┬──────────────────────┬──────────────────────┐
│ Feature         │ Kustomize            │ Helm                 │
├─────────────────┼──────────────────────┼──────────────────────┤
│ Syntax          │ Pure YAML            │ Go templates         │
│ Learning curve  │ Low                  │ Medium               │
│ Templating      │ No (overlays/patches)│ Yes ({{ .Values }})  │
│ Built into      │ kubectl (built-in!)  │ Separate CLI         │
│ Best for        │ Config variations    │ Complex apps         │
│ CKA exam        │ kubectl -k flag      │ helm commands        │
└─────────────────┴──────────────────────┴──────────────────────┘
```

**Key insight:** Kustomize is built into `kubectl`! No extra installation needed.

```bash
kubectl apply -k ./overlays/dev/    # -k = kustomize!
```

---

## Kustomize Structure

```
kustomize-demo/
├── base/                        # Shared base configuration
│   ├── kustomization.yaml
│   ├── deployment.yaml
│   └── service.yaml
└── overlays/
    ├── dev/                     # Dev-specific patches
    │   └── kustomization.yaml
    ├── staging/
    │   └── kustomization.yaml
    └── prod/
        └── kustomization.yaml
```

---

## Tasks

### Task 1: Understand Kustomize (5 min)

```bash
# Verify kustomize is available (built into kubectl)
kubectl kustomize --help

# Key commands
kubectl kustomize <dir>      # render without applying
kubectl apply -k <dir>       # apply kustomize config
kubectl delete -k <dir>      # delete kustomize resources
```

---

### Task 2: Create Base Configuration (10 min)

```bash
mkdir -p kustomize-demo/base
mkdir -p kustomize-demo/overlays/{dev,staging,prod}
cd kustomize-demo

cat > base/deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  labels:
    app: web-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
      - name: web-app
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

cat > base/service.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: web-app
spec:
  selector:
    app: web-app
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF

cat > base/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
- service.yaml
EOF

# Verify base renders
kubectl kustomize base/
```

---

### Task 3: Create Environment Overlays (15 min)

```bash
# Dev overlay - 1 replica, latest image, dev label
cat > overlays/dev/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
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
    name: web-app

labels:
- pairs:
    environment: dev
  includeSelectors: false
EOF

# Staging overlay - 2 replicas
cat > overlays/staging/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base

namePrefix: staging-

patches:
- patch: |-
    - op: replace
      path: /spec/replicas
      value: 2
  target:
    kind: Deployment
    name: web-app

labels:
- pairs:
    environment: staging
  includeSelectors: false
EOF

# Prod overlay - 3 replicas, NodePort
cat > overlays/prod/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

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
    name: web-app
- patch: |-
    - op: replace
      path: /spec/type
      value: NodePort
  target:
    kind: Service
    name: web-app

labels:
- pairs:
    environment: prod
  includeSelectors: false
EOF

# Verify overlays render
kubectl kustomize overlays/dev/
kubectl kustomize overlays/staging/
```

---

### Task 4: Deploy with Kustomize (10 min)

```bash
# Deploy dev
kubectl apply -k overlays/dev/
kubectl get all -l environment=dev

# Deploy staging
kubectl apply -k overlays/staging/
kubectl get deployments | grep -E "dev-|staging-"

# Verify different replicas
kubectl get deployment dev-web-app     -o jsonpath='{.spec.replicas}'   # 1
kubectl get deployment staging-web-app -o jsonpath='{.spec.replicas}'   # 2
```

---

## ⚠️ Minikube-Specific Notes

### Deprecated: commonLabels
Old syntax (still works but shows warning):
```yaml
commonLabels:
  environment: dev
```

New syntax (use this instead):
```yaml
labels:
- pairs:
    environment: dev
  includeSelectors: false
```

The `includeSelectors: false` prevents Kustomize from adding the label to pod selectors, which would break existing deployments.

---

## Exam Tips

⏱️ **Time Management:**
- Create base: 2 minutes
- Create overlay: 1 minute
- Apply: 30 seconds
- **Total: ~4 minutes**

🎯 **Exam Question Patterns:**

> *"Apply the kustomize config in /root/kustomize/overlays/prod"*
```bash
kubectl apply -k /root/kustomize/overlays/prod
```

> *"Build the kustomize output to a file"*
```bash
kubectl kustomize overlays/prod > output.yaml
```

> *"Change the replica count to 3 in the prod overlay"*
```yaml
patches:
- patch: |-
    - op: replace
      path: /spec/replicas
      value: 3
  target:
    kind: Deployment
    name: web-app
```

---

## Common Issues

### Issue: commonLabels deprecated warning
```
Warning: 'commonLabels' is deprecated. Please use 'labels' instead.
```
**Fix:** Replace `commonLabels:` with the `labels:` block shown above.

### Issue: bases vs resources
```yaml
# Old syntax (still works)
bases:
- ../../base

# New syntax (preferred)
resources:
- ../../base
```

---

## Next Lab

Move to **[Lab 09: High Availability Clusters](../09-high-availability/README.md)**

---

**Author:** Shamsher Khan | **Blog:** opscart.com | **Course:** Production CKA 2026