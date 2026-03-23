# Lab 02: RBAC Advanced - Visual Diagrams

## 1. ClusterRole vs Role - Scope Comparison

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Kubernetes Cluster                            │
│                                                                      │
│  ┌────────────────────┐         ┌────────────────────┐             │
│  │  Namespace: prod   │         │ Namespace: staging │             │
│  │                    │         │                    │             │
│  │  ┌──────────┐      │         │  ┌──────────┐     │             │
│  │  │ Pod      │      │         │  │ Pod      │     │             │
│  │  │ Service  │◄─────┼─────────┼──│ Service  │     │             │
│  │  │ ConfigMap│      │    │    │  │ ConfigMap│     │             │
│  │  └──────────┘      │    │    │  └──────────┘     │             │
│  │         ▲          │    │    │                    │             │
│  │         │          │    │    │                    │             │
│  │    Role applies    │    │    │                    │             │
│  │    ONLY here       │    │    │                    │             │
│  └────────────────────┘    │    └────────────────────┘             │
│                            │                                        │
│                     ClusterRole applies                             │
│                     EVERYWHERE (all namespaces                      │
│                     + cluster-scoped resources)                     │
│                            │                                        │
│  ┌─────────────────────────┼────────────────────────┐              │
│  │  Cluster-Scoped Resources                        │              │
│  │                         │                         │              │
│  │  ┌─────────┐      ┌────▼────┐      ┌──────────┐ │              │
│  │  │ Nodes   │◄─────│PersistentVolumes│Namespaces│ │              │
│  │  └─────────┘      └─────────┘      └──────────┘ │              │
│  │                                                   │              │
│  │  Role CANNOT access these                        │              │
│  │  ClusterRole CAN access these                    │              │
│  └───────────────────────────────────────────────────┘              │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 2. Lab 02 Architecture - All 4 Scenarios

```
┌──────────────────────────────────────────────────────────────────────────┐
│                         Kubernetes Cluster                                │
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │ Scenario 1: Platform Admin (Full Access)                        │    │
│  │                                                                  │    │
│  │  ServiceAccount          ClusterRole         ClusterRoleBinding │    │
│  │  ┌──────────────┐       ┌──────────┐         ┌──────────────┐  │    │
│  │  │platform-admin│──────►│platform- │────────►│  Grants full  │  │    │
│  │  │(kube-system) │       │  admin   │         │  access to *  │  │    │
│  │  └──────────────┘       │  Rules:  │         └──────────────┘  │    │
│  │                         │  - */*/* │              │             │    │
│  │                         └──────────┘              │             │    │
│  │                                                    ▼             │    │
│  │                              Can access EVERYTHING in cluster   │    │
│  └──────────────────────────────────────────────────────────────────┘    │
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │ Scenario 2: Security Viewer (Read-Only Everywhere)              │    │
│  │                                                                  │    │
│  │  ServiceAccount          ClusterRole         ClusterRoleBinding │    │
│  │  ┌──────────────┐       ┌──────────┐         ┌──────────────┐  │    │
│  │  │security-     │──────►│security- │────────►│ Grants read   │  │    │
│  │  │ viewer       │       │ viewer   │         │ to all        │  │    │
│  │  │(kube-system) │       │  Rules:  │         └──────────────┘  │    │
│  │  └──────────────┘       │  - get   │              │             │    │
│  │                         │  - list  │              │             │    │
│  │                         │  - watch │              ▼             │    │
│  │                         └──────────┘    ┌───────────────────┐   │    │
│  │                                         │ All Namespaces    │   │    │
│  │                                         │ prod ✓  staging ✓ │   │    │
│  │                                         │ + Nodes ✓         │   │    │
│  │                                         │ + Secrets ✓       │   │    │
│  │                                         └───────────────────┘   │    │
│  └──────────────────────────────────────────────────────────────────┘    │
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │ Scenario 3: Developer Node Access (Cluster Resource Only)       │    │
│  │                                                                  │    │
│  │  ServiceAccount     ClusterRole      ClusterRoleBinding         │    │
│  │  ┌──────────┐       ┌──────────┐     ┌──────────────┐          │    │
│  │  │developer │──────►│  node-   │────►│ Grants node   │          │    │
│  │  │  (prod)  │       │  reader  │     │ access only   │          │    │
│  │  └──────────┘       │  Rules:  │     └──────────────┘          │    │
│  │                     │  - nodes │              │                 │    │
│  │                     │  - get   │              │                 │    │
│  │                     └──────────┘              ▼                 │    │
│  │                                     ┌──────────────────┐        │    │
│  │                                     │  ✓ Can view nodes│        │    │
│  │                                     │  ✗ No pod access │        │    │
│  │                                     │  ✗ No namespace  │        │    │
│  │                                     │    permissions   │        │    │
│  │                                     └──────────────────┘        │    │
│  └──────────────────────────────────────────────────────────────────┘    │
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │ Scenario 4: Monitoring (Aggregated ClusterRole)                 │    │
│  │                                                                  │    │
│  │  ServiceAccount          ClusterRole (Aggregated)               │    │
│  │  ┌──────────────┐       ┌───────────────────────────────┐      │    │
│  │  │monitoring-   │──────►│  monitoring-aggregated        │      │    │
│  │  │  user        │       │  aggregationRule:             │      │    │
│  │  │(kube-system) │       │    matchLabels:               │      │    │
│  │  └──────────────┘       │      aggregate-to-monitoring  │      │    │
│  │                         └───────────────┬───────────────┘      │    │
│  │                                         │                       │    │
│  │                        ┌────────────────┼────────────────┐     │    │
│  │                        │                │                │     │    │
│  │                        ▼                ▼                ▼     │    │
│  │              ┌──────────────┐  ┌──────────┐  ┌──────────┐    │    │
│  │              │monitoring-   │  │monitoring│  │monitoring│    │    │
│  │              │  metrics     │  │  -logs   │  │ -events  │    │    │
│  │              │              │  │          │  │          │    │    │
│  │              │Rules:        │  │Rules:    │  │Rules:    │    │    │
│  │              │- pods/metrics│  │- pods/log│  │- events  │    │    │
│  │              │- nodes       │  │          │  │          │    │    │
│  │              └──────────────┘  └──────────┘  └──────────┘    │    │
│  │                        │                │                │     │    │
│  │                        └────────────────┴────────────────┘     │    │
│  │                                         │                       │    │
│  │                                         ▼                       │    │
│  │                            Monitoring user gets ALL             │    │
│  │                            aggregated permissions               │    │
│  └──────────────────────────────────────────────────────────────────┘    │
└───────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Permission Flow - How RBAC Works

```
┌─────────────────────────────────────────────────────────────────┐
│  User/ServiceAccount makes a request                            │
│  "Can I get pods in namespace prod?"                            │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
        ┌──────────────────────────────┐
        │   Kubernetes API Server      │
        │   (RBAC Authorization)       │
        └──────────────┬───────────────┘
                       │
                       ▼
        ┌──────────────────────────────┐
        │ Step 1: Who is making        │
        │         the request?         │
        │                              │
        │ Subject identified as:       │
        │ - User: john@example.com     │
        │ - ServiceAccount: prod/dev   │
        │ - Group: developers          │
        └──────────────┬───────────────┘
                       │
                       ▼
        ┌──────────────────────────────┐
        │ Step 2: Find all Bindings    │
        │         for this subject     │
        │                              │
        │ Search:                      │
        │ - RoleBindings (namespace)   │
        │ - ClusterRoleBindings (all)  │
        └──────────────┬───────────────┘
                       │
                       ▼
        ┌──────────────────────────────┐
        │ Step 3: Get Roles/ClusterRoles│
        │         from bindings        │
        │                              │
        │ Found:                       │
        │ - Role: developer (prod ns)  │
        │ - ClusterRole: node-reader   │
        └──────────────┬───────────────┘
                       │
                       ▼
        ┌──────────────────────────────┐
        │ Step 4: Check if any rule    │
        │         allows the action    │
        │                              │
        │ Rules checked:               │
        │ - apiGroups: [""]            │
        │ - resources: ["pods"]        │
        │ - verbs: ["get"]             │
        │ - namespace: prod            │
        └──────────────┬───────────────┘
                       │
           ┌───────────┴───────────┐
           │                       │
           ▼                       ▼
    ┌──────────┐           ┌──────────┐
    │ ALLOWED  │           │ DENIED   │
    │ (200 OK) │           │ (403)    │
    └──────────┘           └──────────┘
```

---

## 4. Real Production RBAC Hierarchy

```
                    ┌─────────────────────────┐
                    │   cluster-admin         │
                    │   (Emergency Only)      │
                    │   - Break glass access  │
                    │   - MFA required        │
                    └───────────┬─────────────┘
                                │
                                ▼
                    ┌─────────────────────────┐
                    │   platform-admin        │
                    │   (Platform Team)       │
                    │   - Daily operations    │
                    │   - Cluster management  │
                    └───────────┬─────────────┘
                                │
                ┌───────────────┼───────────────┐
                │               │               │
                ▼               ▼               ▼
        ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
        │ security-    │ │ namespace-   │ │ monitoring-  │
        │ viewer       │ │ admin        │ │ aggregated   │
        │              │ │              │ │              │
        │ - Audit      │ │ - Team leads │ │ - Prometheus │
        │ - SOC2       │ │ - Per NS     │ │ - Logs       │
        └──────────────┘ └──────┬───────┘ └──────────────┘
                                │
                    ┌───────────┼───────────┐
                    │           │           │
                    ▼           ▼           ▼
            ┌──────────┐ ┌──────────┐ ┌──────────┐
            │developer │ │developer │ │developer │
            │  (prod)  │ │ (staging)│ │  (dev)   │
            │          │ │          │ │          │
            │- CRUD    │ │- CRUD    │ │- CRUD    │
            │- No del  │ │- Full    │ │- Full    │
            └──────────┘ └──────────┘ └──────────┘
                    │           │           │
                    ▼           ▼           ▼
            ┌──────────┐ ┌──────────┐ ┌──────────┐
            │ viewer   │ │ viewer   │ │ viewer   │
            │ (prod)   │ │(staging) │ │ (dev)    │
            │          │ │          │ │          │
            │- Read    │ │- Read    │ │- Read    │
            │  only    │ │  only    │ │  only    │
            └──────────┘ └──────────┘ └──────────┘
```

---

## 5. ClusterRole + RoleBinding Pattern (Advanced)

```
┌────────────────────────────────────────────────────────────────┐
│  Pattern: ClusterRole + RoleBinding                            │
│  Use Case: Grant cluster-scoped resource access to specific NS │
└────────────────────────────────────────────────────────────────┘

Example: Developer needs to view nodes (capacity planning)
         but should NOT have cluster-wide access


Step 1: Create ClusterRole (cluster-scoped permissions)
┌──────────────────────────────────────┐
│ ClusterRole: node-reader             │
│ rules:                               │
│   - resources: ["nodes"]             │
│   - verbs: ["get", "list", "watch"]  │
└──────────────────────────────────────┘
                │
                │ Defines WHAT can be accessed
                │
                ▼
Step 2: Create ClusterRoleBinding (WHO gets access)
┌──────────────────────────────────────┐
│ ClusterRoleBinding: dev-node-reader  │
│ subjects:                            │
│   - serviceaccount: prod/developer   │
│ roleRef: node-reader                 │
└──────────────────────────────────────┘
                │
                │
                ▼
Result: Developer (prod namespace) can access nodes cluster-wide

┌─────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                    │
│                                                          │
│  ┌────────────────┐                                     │
│  │ Namespace:prod │                                     │
│  │                │                                     │
│  │  developer SA  │─────────┐                          │
│  │                │         │                          │
│  └────────────────┘         │                          │
│         │                   │ ClusterRoleBinding       │
│         │ No access         │                          │
│         │ to pods here      │                          │
│         ▼                   ▼                          │
│  ┌────────────┐      ┌─────────────┐                  │
│  │  ✗ Pods    │      │  ✓ Nodes    │                  │
│  │  ✗ Services│      │  (cluster-  │                  │
│  │  ✗ Secrets │      │   scoped)   │                  │
│  └────────────┘      └─────────────┘                  │
│                                                         │
└─────────────────────────────────────────────────────────┘

Why This Works:
✓ ClusterRole grants access to cluster-scoped resources (nodes)
✓ ClusterRoleBinding determines WHO gets it
✓ Developer has minimal permissions (principle of least privilege)
✓ No namespace access = Can't mess with workloads
```

---

## 6. Aggregated ClusterRole - How It Works

```
┌────────────────────────────────────────────────────────────────┐
│  Aggregated ClusterRole Pattern                                │
│  Modular, composable permissions using label selectors         │
└────────────────────────────────────────────────────────────────┘

Step 1: Create Base ClusterRole (empty rules)
┌──────────────────────────────────────────────┐
│ ClusterRole: monitoring-aggregated           │
│ aggregationRule:                             │
│   clusterRoleSelectors:                      │
│     - matchLabels:                           │
│         rbac.../aggregate-to-monitoring: true│
│ rules: []  ◄── Empty! Filled automatically   │
└──────────────────────────────────────────────┘
                        │
                        │ Watches for matching labels
                        │
        ┌───────────────┼───────────────┐
        │               │               │
        ▼               ▼               ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│ClusterRole:  │ │ClusterRole:  │ │ClusterRole:  │
│monitoring-   │ │monitoring-   │ │monitoring-   │
│ metrics      │ │  logs        │ │  events      │
│              │ │              │ │              │
│labels:       │ │labels:       │ │labels:       │
│  aggregate-  │ │  aggregate-  │ │  aggregate-  │
│  to-monitor  │ │  to-monitor  │ │  to-monitor  │
│    = true    │ │    = true    │ │    = true    │
│              │ │              │ │              │
│rules:        │ │rules:        │ │rules:        │
│- pods        │ │- pods/log    │ │- events      │
│- nodes       │ │              │ │              │
└──────────────┘ └──────────────┘ └──────────────┘
        │               │               │
        └───────────────┴───────────────┘
                        │
                        │ Kubernetes aggregates
                        │ all matching rules
                        ▼
        ┌──────────────────────────────┐
        │ monitoring-aggregated        │
        │ rules: (auto-populated)      │
        │   - pods          (metrics)  │
        │   - nodes         (metrics)  │
        │   - pods/log      (logs)     │
        │   - events        (events)   │
        └──────────────────────────────┘
                        │
                        │
                        ▼
        ┌──────────────────────────────┐
        │ ClusterRoleBinding           │
        │ subjects: monitoring-user    │
        │ roleRef: monitoring-aggregated│
        └──────────────────────────────┘

Benefits:
✓ Modular - Add/remove components easily
✓ Reusable - Same pattern for different teams
✓ Maintainable - Each component is small and focused
✓ Kubernetes built-in roles use this (view, edit, admin)
```

---

## Quick Reference: When to Use What

```
┌──────────────────────────────────────────────────────────────┐
│  Decision Tree: Role vs ClusterRole                          │
└──────────────────────────────────────────────────────────────┘

Question 1: Does the user need access to cluster-scoped resources?
            (nodes, PVs, namespaces, CRDs)

    YES ──► Use ClusterRole + ClusterRoleBinding
            Example: Infrastructure team managing nodes

    NO  ──► Question 2

Question 2: Does the user need access across multiple namespaces?

    YES ──► Use ClusterRole + ClusterRoleBinding
            Example: Security team auditing all namespaces

    NO  ──► Question 3

Question 3: User only works in a single namespace?

    YES ──► Use Role + RoleBinding
            Example: Dev team in 'prod' namespace

Special Case: Need to grant cluster-scoped resource access
              but limit WHO gets it?

    ──► Use ClusterRole + ClusterRoleBinding
        (Not RoleBinding - that was our bug!)
```

---

## Summary Table

```
┌─────────────┬──────────────┬────────────────┬──────────────────┐
│ Scenario    │ Role Type    │ Binding Type   │ Scope            │
├─────────────┼──────────────┼────────────────┼──────────────────┤
│ Team in NS  │ Role         │ RoleBinding    │ Single namespace │
├─────────────┼──────────────┼────────────────┼──────────────────┤
│ Cluster     │ ClusterRole  │ ClusterRole    │ Entire cluster   │
│ Admin       │              │ Binding        │                  │
├─────────────┼──────────────┼────────────────┼──────────────────┤
│ Read-only   │ ClusterRole  │ ClusterRole    │ All namespaces   │
│ Everywhere  │              │ Binding        │ + cluster        │
├─────────────┼──────────────┼────────────────┼──────────────────┤
│ Node access │ ClusterRole  │ ClusterRole    │ Nodes only       │
│ only        │              │ Binding        │                  │
├─────────────┼──────────────┼────────────────┼──────────────────┤
│ Modular     │ ClusterRole  │ ClusterRole    │ Composable       │
│ permissions │ (aggregated) │ Binding        │ permissions      │
└─────────────┴──────────────┴────────────────┴──────────────────┘
```

---

These diagrams should be included in the README for visual learners!