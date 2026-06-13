# Lab 14: CRDs and Operators - Solution Guide

## Run the Scripts
```bash
./scripts/setup.sh   # Creates CRD and custom resources in lab14-crds
./scripts/test.sh    # Validates CRD registration and custom resources
./scripts/cleanup.sh
```

---

## Complete Manual Solution

### Step 1: Create Namespace
```bash
kubectl create namespace lab14-crds
```

### Step 2: Create CRD
```bash
kubectl apply -f - << 'EOF'
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
              retentionDays:
                type: integer
                minimum: 1
                maximum: 365
              target:
                type: string
              enabled:
                type: boolean
  scope: Namespaced
  names:
    plural: backuppolicies
    singular: backuppolicy
    kind: BackupPolicy
    shortNames:
    - bp
EOF

# Wait for CRD to be ready
kubectl wait --for=condition=Established \
  crd/backuppolicies.ops.example.com --timeout=30s

# Verify
kubectl get crd backuppolicies.ops.example.com
kubectl api-resources | grep backuppolic
```

### Step 3: Create Custom Resources
```bash
kubectl apply -f - << 'EOF'
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

# List using kind name and short name
kubectl get backuppolicies -n lab14-crds
kubectl get bp -n lab14-crds
```

### Step 4: Describe and Get Details
```bash
kubectl describe backuppolicy database-backup -n lab14-crds
kubectl get backuppolicy database-backup -n lab14-crds -o yaml
```

### Step 5: Update Custom Resource
```bash
kubectl patch backuppolicy database-backup \
  -n lab14-crds \
  --type=merge \
  -p '{"spec":{"retentionDays":60}}'

# Verify
kubectl get backuppolicy database-backup \
  -n lab14-crds \
  -o jsonpath='{.spec.retentionDays}'
# 60
```

### Step 6: Test Schema Validation
```bash
# This should FAIL (retentionDays below minimum)
kubectl apply -f - << 'EOF'
apiVersion: ops.example.com/v1
kind: BackupPolicy
metadata:
  name: invalid-backup
  namespace: lab14-crds
spec:
  schedule: "0 2 * * *"
  retentionDays: -1
EOF
# Error: spec.retentionDays: Invalid value: -1: should be >= 1
```

---

## Key Takeaways

✅ CRD name format: `<plural>.<group>`
✅ Custom resources work like built-in resources (`get`, `apply`, `delete`)
✅ Schema validation enforces field constraints
✅ Short names make CLI usage faster
✅ Deleting CRD deletes ALL instances - be careful!
✅ Operators extend CRDs with automated controllers
✅ Wait for `Established` condition before creating instances

---

**Completed Lab 14?** ✅

Move to **[Lab 15: CNI Plugins](../15-cni-plugins/)**