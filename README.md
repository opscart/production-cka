# Production CKA 2026 - Kubernetes Administrator Certification Prep

**Kubernetes v1.35** | **70 Hands-On Labs** | **OpsCart Course**

[![CKA Certified](https://img.shields.io/badge/CKA-2026-blue)](https://www.cncf.io/certification/cka/)
[![Labs](https://img.shields.io/badge/Labs-70-green)](./COURSE-STRATEGY.md)
[![Progress](https://img.shields.io/badge/Progress-20%2F70-orange)](./PROGRESS.md)

70 hands-on labs covering every CKA exam domain, built from real production experience managing 8+ AKS clusters for a Fortune 500 pharmaceutical company. Every lab ships with automated setup/test/cleanup scripts, exam tips, and documented platform limitations (minikube vs kubeadm vs cloud).

**Current progress:** 20/70 labs (28.6%) — see [PROGRESS.md](./PROGRESS.md) for the live breakdown.

---

## Quick Start

```bash
git clone https://github.com/opscart/production-cka
cd production-cka

# 3-node minikube cluster
cd setup
chmod +x minikube-setup.sh
./minikube-setup.sh

kubectl get nodes
# opscart, opscart-m02, opscart-m03 — all Ready

cd ../labs/cluster-architecture/01-rbac-basics
cat README.md
```

**Requirements:** 8GB+ RAM, 4+ CPU cores, Docker, kubectl v1.35+, minikube v1.30+.

---

## How Each Lab Works

```
labXX-topic-name/
├── README.md           # Scenario, tasks, exam tips
├── QUICK-REFERENCE.md  # Command cheat sheet
├── manifests/          # YAML files
├── scripts/
│   ├── setup.sh        # Create lab resources
│   ├── test.sh         # Validate (X/Y checks passed)
│   └── cleanup.sh       # Remove lab resources
└── solutions/
    └── SOLUTION.md      # Step-by-step answer key
```

```bash
cd labs/<domain>/<lab-name>/
cat README.md
./scripts/setup.sh
# ...do the tasks...
./scripts/test.sh
cat solutions/SOLUTION.md   # if stuck
./scripts/cleanup.sh
```

---

## Course Domains

| Domain | Weight | Labs |
|---|---|---|
| Cluster Architecture, Installation & Configuration | 25% | 18 |
| Services & Networking | 20% | 14 |
| Workloads & Scheduling | 15% | 11 |
| Storage | 10% | 7 |
| Troubleshooting | 30% | 20 |

Full roadmap, study plan, and exam logistics → [COURSE-STRATEGY.md](./COURSE-STRATEGY.md)

---

## Author

**Shamsher Khan** — Senior DevOps Engineer @ GlobalLogic (Hitachi), managing 8+ production AKS clusters.
[opscart.com](https://opscart.com) · [GitHub](https://github.com/opscart) · [DZone](https://dzone.com/users/shamsherkhan)

MIT License — free for personal use and learning.