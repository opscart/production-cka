# Lab 14: CRDs and Operators

## Objective
Understand Custom Resource Definitions (CRDs) and the Operator pattern. Learn to create CRDs, work with custom resources, and understand how operators extend Kubernetes functionality.

## CKA Exam Relevance
- **Domain:** Cluster Architecture, Installation & Configuration (25%)
- **Topic:** Understand CRDs and extensibility
- **Exam Weight:** Medium (30-40% of exams)
- **Typical Exam Time:** 5-8 minutes

## Time to Complete
45 minutes

## Prerequisites
- Completed Labs 01-13
- Understanding of Kubernetes API (Lab 10)
- Basic YAML knowledge

---

## What are CRDs?

Kubernetes ships with built-in resource types: Pods, Services, Deployments, etc. **CRDs let you define your own resource types** that Kubernetes manages natively.

```
Built-in Resources:          Custom Resources (via CRD):
────────────────────         ─────────────────────────────
kubectl get pods             kubectl get databases
kubectl get services         kubectl get backuppolicies
kubectl get deployments      kubectl get certificates (cert-manager)
                             kubectl get prometheuses (monitoring)
                             kubectl get kafkas (Strimzi)
```

---

## CRD Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    Kubernetes API Server                      │
│                                                              │
│  Built-in API Groups:        Extended API Groups:            │
│  /api/v1 (pods, services)    /apis/mycompany.com/v1          │
│  /apis/apps/v1 (deploys)     /apis/database.example.com/v1   │
│                                                              │
│  CustomResourceDefinition ──► Registers new API endpoint     │
└──────────────────────────────────────────────────────────────┘

                    CRD defines the schema
                          │
                    Users create instances (CR)
                          │
                    Operator watches and acts
```

---

## Operator Pattern

```
Without Operator:                 With Operator:
──────────────────                ───────────────────────────
Manual steps to deploy DB:        kubectl apply -f database.yaml
1. Create StatefulSet             Operator automatically:
2. Create Service                  - Creates StatefulSet
3. Create ConfigMap                - Creates Service
4. Create PVC                      - Creates ConfigMap
5. Configure backups               - Configures backups
6. Set up monitoring               - Sets up monitoring
7. Handle failover                 - Handles failover
(7 manual steps)                  (1 YAML file)
```

---

## Tasks

### Task 1: Explore Existing CRDs (5 min)

**Objective:** Find CRDs already installed in your cluster.

```bash
# List all CRDs
kubectl get crd

# Get details about a specific CRD
kubectl get crd <crd-name> -o yaml | head -40

# List custom resources of a type
kubectl api-resources | grep -v "^NAME" | grep -v "k8s.io" | head -20
```

---

### Task 2: Create a Simple CRD (15 min)

**Objective:** Define a custom resource type for a backup policy.

```bash
# Create namespace
kubectl create namespace lab14-crds

# Create the CRD
cat > manifests/backuppolicy-crd.yaml << 'EOF'
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: backuppolicies.ops.example.com
spec:
  group: ops.example.com
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            required: ["schedule", "retentionDays"]
            properties:
              schedule:
                type: string
                description: "Cron schedule for backup"
              retentionDays:
                type: integer
                minimum: 1
                maximum: 365
                description: "Days to retain backups"
              target:
                type: string
                description: "Target resource to backup"
              enabled:
                type: boolean
                default: true
          status:
            type: object
            properties:
              lastBackup:
                type: string
              nextBackup:
                type: string
              phase:
                type: string
  scope: Namespaced
  names:
    plural: backuppolicies
    singular: backuppolicy
    kind: BackupPolicy
    shortNames:
    - bp
EOF

kubectl apply -f manifests/backuppolicy-crd.yaml

# Wait for CRD to be established
kubectl wait --for=condition=Established \
  crd/backuppolicies.ops.example.com --timeout=30s

# Verify CRD is registered
kubectl get crd backuppolicies.ops.example.com
kubectl api-resources | grep backuppolic
```

---

### Task 3: Create Custom Resources (10 min)

**Objective:** Create instances of your custom resource.

```bash
# Create a BackupPolicy for database
cat > manifests/db-backup-policy.yaml << 'EOF'
apiVersion: ops.example.com/v1
kind: BackupPolicy
metadata:
  name: database-backup
  namespace: lab14-crds
spec:
  schedule: "0 2 * * *"
  retentionDays: 30
  target: "postgres-db"
  enabled: true
EOF

kubectl apply -f manifests/db-backup-policy.yaml

# Create another for config files
cat > manifests/config-backup-policy.yaml << 'EOF'
apiVersion: ops.example.com/v1
kind: BackupPolicy
metadata:
  name: config-backup
  namespace: lab14-crds
spec:
  schedule: "0 */6 * * *"
  retentionDays: 7
  target: "app-config"
  enabled: true
EOF

kubectl apply -f manifests/config-backup-policy.yaml

# List custom resources - just like built-in resources!
kubectl get backuppolicies -n lab14-crds
kubectl get bp -n lab14-crds   # short name!

# Describe a custom resource
kubectl describe backuppolicy database-backup -n lab14-crds

# Get as YAML
kubectl get backuppolicy database-backup -n lab14-crds -o yaml
```

---

### Task 4: Update and Delete Custom Resources (5 min)

**Objective:** Manage lifecycle of custom resources.

```bash
# Update a custom resource
kubectl patch backuppolicy database-backup \
  -n lab14-crds \
  --type=merge \
  -p '{"spec":{"retentionDays":60}}'

# Verify update
kubectl get backuppolicy database-backup \
  -n lab14-crds \
  -o jsonpath='{.spec.retentionDays}'
# Output: 60

# Delete a custom resource
kubectl delete backuppolicy config-backup -n lab14-crds

# List remaining
kubectl get bp -n lab14-crds
```

---

### Task 5: Understand Operator Pattern (10 min)

**Objective:** Understand how operators work with CRDs.

**Operators = CRD + Controller**

A controller watches for changes to custom resources and takes action.

```bash
# Simulate what an operator would do
# 1. Watch for BackupPolicy resources
kubectl get backuppolicies -n lab14-crds -w &
WATCH_PID=$!

# 2. Create a new BackupPolicy (operator would react to this)
cat > manifests/logs-backup-policy.yaml << 'EOF'
apiVersion: ops.example.com/v1
kind: BackupPolicy
metadata:
  name: logs-backup
  namespace: lab14-crds
spec:
  schedule: "0 4 * * 0"
  retentionDays: 14
  target: "app-logs"
  enabled: true
EOF

kubectl apply -f manifests/logs-backup-policy.yaml

# Stop watching
sleep 3
kill $WATCH_PID 2>/dev/null || true

# A real operator would:
# - See the new BackupPolicy
# - Create a CronJob to run backups
# - Update the BackupPolicy status
# - Monitor backup execution
```

**Real-world operators you'll encounter:**
```bash
# cert-manager: manages TLS certificates
kubectl get certificates,certificaterequests -A 2>/dev/null || \
  echo "cert-manager not installed"

# Prometheus Operator: manages monitoring
kubectl get prometheuses,alertmanagers -A 2>/dev/null || \
  echo "prometheus-operator not installed"
```

---

## Exam Tips

⏱️ **Time Management:**
- Create CRD: 2 minutes
- Create custom resources: 2 minutes
- List/describe/delete: 1 minute
- **Total: ~5 minutes**

🎯 **Exam Question Patterns:**

> *"Create a CRD for resource type 'Application' in group 'stable.example.com'"*

> *"Create a custom resource of type BackupPolicy"*

> *"List all custom resource definitions in the cluster"*

> *"What is the API group for the 'certificates' CRD?"*

🔑 **Key Commands:**
```bash
# List all CRDs
kubectl get crd

# List resources of custom type
kubectl get <plural-name> -n <namespace>

# Describe CRD schema
kubectl describe crd <crd-name>

# Delete CRD (also deletes all instances!)
kubectl delete crd <crd-name>
```

---

## Common Issues

### CRD not ready yet
```bash
# Wait for establishment
kubectl wait --for=condition=Established crd/<name> --timeout=30s
```

### Custom resource validation fails
```bash
# Check schema
kubectl describe crd <name> | grep -A 20 "Validation"

# Check error message
kubectl apply -f cr.yaml
# Error: spec.retentionDays: Invalid value: -1: should be >= 1
```

### Deleting CRD deletes all instances
```bash
# WARNING: This deletes ALL BackupPolicy instances!
kubectl delete crd backuppolicies.ops.example.com
```

---

## Next Lab

Move to **[Lab 15: CNI Plugins](../15-cni-plugins/README.md)**

---

**Author:** Shamsher Khan | **Blog:** opscart.com | **Course:** Production CKA 2026