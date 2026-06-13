# Lab 14: CRDs and Operators - Quick Reference

## CRD Commands

```bash
# List all CRDs
kubectl get crd

# Get CRD details
kubectl describe crd <name>
kubectl get crd <name> -o yaml

# Wait for CRD ready
kubectl wait --for=condition=Established crd/<name> --timeout=30s

# Delete CRD (WARNING: deletes all instances!)
kubectl delete crd <name>
```

---

## CRD Definition Structure

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: <plural>.<group>      # e.g. backuppolicies.ops.example.com
spec:
  group: ops.example.com       # API group
  versions:
  - name: v1
    served: true               # this version is served by API
    storage: true              # this version is stored in etcd
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            required: ["field1"]
            properties:
              field1:
                type: string
              field2:
                type: integer
                minimum: 1
  scope: Namespaced            # or Cluster
  names:
    plural: backuppolicies
    singular: backuppolicy
    kind: BackupPolicy
    shortNames:
    - bp
```

---

## Custom Resource

```yaml
apiVersion: ops.example.com/v1    # group/version
kind: BackupPolicy                 # kind from CRD
metadata:
  name: my-backup
  namespace: my-namespace
spec:
  schedule: "0 2 * * *"
  retentionDays: 30
```

---

## Working with Custom Resources

```bash
# List custom resources
kubectl get backuppolicies -n my-namespace
kubectl get bp -n my-namespace           # short name

# Describe
kubectl describe backuppolicy my-backup -n my-namespace

# Get YAML
kubectl get backuppolicy my-backup -n my-namespace -o yaml

# Update
kubectl patch backuppolicy my-backup -n my-namespace \
  --type=merge -p '{"spec":{"retentionDays":60}}'

# Delete
kubectl delete backuppolicy my-backup -n my-namespace
```

---

## Find CRDs in Cluster

```bash
# List all CRDs
kubectl get crd

# Find by group
kubectl get crd | grep example.com

# List all custom resources of a type
kubectl api-resources | grep -v k8s.io

# Get all instances across namespaces
kubectl get backuppolicies -A
```

---

## Exam Scenarios

### Create a CRD
```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: applications.stable.example.com
spec:
  group: stable.example.com
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
            properties:
              version:
                type: string
              replicas:
                type: integer
  scope: Namespaced
  names:
    plural: applications
    singular: application
    kind: Application
    shortNames:
    - app
```

### Create Custom Resource
```yaml
apiVersion: stable.example.com/v1
kind: Application
metadata:
  name: my-app
  namespace: default
spec:
  version: "1.0.0"
  replicas: 3
```

---

## Key Facts

- CRD name format: `<plural>.<group>` e.g. `backuppolicies.ops.example.com`
- CRDs extend the Kubernetes API with custom types
- Custom resources behave like built-in resources (get/apply/delete)
- Schema validation enforces field types and constraints
- Deleting a CRD deletes ALL its instances
- Operators = CRD + Controller (watches and acts on custom resources)

---

## Time Budget (Exam)

- Create CRD: **2 minutes**
- Create custom resource: **1 minute**
- Verify: **30 seconds**
- **Total: ~4 minutes**