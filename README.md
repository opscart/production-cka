# Production CKA 2026 - Kubernetes Administrator Certification

**Kubernetes v1.34** | **70 Hands-On Labs** | **Production-Grade** | **OpsCart Course**

[![CKA Certified](https://img.shields.io/badge/CKA-v1.34-blue)](https://www.cncf.io/certification/cka/)
[![Labs](https://img.shields.io/badge/Labs-70-green)](./COURSE-STRATEGY.md)
[![Progress](https://img.shields.io/badge/Progress-5%2F70-orange)](./COURSE-STRATEGY.md)

---

## 🎯 What You'll Build

A **complete CKA exam preparation** course with 70 hands-on labs covering real production scenarios from managing Fortune 500 Kubernetes clusters in a regulated pharmaceutical environment.

**Current Status:** 5/70 labs complete (7.1%) | **Next:** Lab 06 - Helm Basics

---

## 🌟 What Makes This Course Unique

### 1. **Production Experience Built-In**
- Real scenarios from managing 8+ production AKS clusters
- Fortune 500 pharmaceutical compliance requirements
- Security-first approach (HIPAA, SOC2, FDA)
- Cost optimization strategies from $50K/month spend

### 2. **Platform Compatibility**
- ✅ **Works on minikube** (local, no cloud costs)
- ✅ **Works on kubeadm** (self-hosted clusters)
- ✅ **Addresses AKS/EKS/GKE** differences
- ✅ **Documents platform challenges** (like distroless containers)

### 3. **2026 Curriculum Updates**
- ⭐ **Helm & Kustomize** (NEW requirement)
- ⭐ **Gateway API** (replacing classic Ingress focus)
- ⭐ **CRDs & Operators** (increased emphasis)
- ⭐ **CNI/CSI/CRI** interfaces (NEW additions)

### 4. **Real Troubleshooting**
- Actual issues encountered and solved
- Step-by-step debugging methodology
- Common gotchas documented
- Platform limitations explained (see Lab 05!)

### 5. **Complete Lab Structure**
Every lab includes:
- 📖 Comprehensive README with scenarios
- 📋 Quick reference commands
- 🔧 Automated setup/test/cleanup scripts
- ✅ Validation tests
- 💡 Solutions and explanations
- ⏱️ Exam time management tips

---

## 📚 Course Structure (70 Labs)

### Domain 1: Cluster Architecture, Installation & Configuration (25%)
**Labs:** 18 | **Progress:** 5/18 (27.8%) | **Status:** In Progress

```
✅ Lab 01: RBAC Basics (30 min)
✅ Lab 02: RBAC Advanced + Diagrams (40 min)
✅ Lab 03: kubeadm Installation (60 min)
✅ Lab 04: Cluster Upgrade (50 min)
✅ Lab 05: etcd Backup & Restore + Challenges (45 min)
📝 Lab 06: Helm Basics (40 min) ← NEXT
⏸️ Labs 07-18: Helm, Kustomize, HA, CRDs, CNI/CSI/CRI
```

[View complete course strategy →](./COURSE-STRATEGY.md)

### Domain 2: Services & Networking (20%)
**Labs:** 14 | **Status:** Pending

Service types, Ingress, Gateway API, NetworkPolicies, CoreDNS

### Domain 3: Workloads & Scheduling (15%)
**Labs:** 11 | **Status:** Pending

Deployments, StatefulSets, Jobs, Scheduling, Autoscaling

### Domain 4: Storage (10%)
**Labs:** 7 | **Status:** Pending

Volumes, PV/PVC, StorageClasses, Dynamic provisioning

### Domain 5: Troubleshooting (30%) ⚠️ Highest Weight
**Labs:** 20 | **Status:** Pending

Pod/Node/Cluster troubleshooting, debugging, monitoring

---

## 🚀 Quick Start

### Prerequisites

**Experience:**
- 6+ months working with Kubernetes
- Comfortable with Linux command line
- Basic understanding of containers

**Hardware:**
- 8GB+ RAM (16GB recommended)
- 4+ CPU cores
- 50GB free disk space

**Software:**
- Docker Desktop (or Docker)
- kubectl (v1.34+)
- minikube (v1.30+)

### Setup (5 minutes)

```bash
# 1. Clone repository
git clone https://github.com/opscart/production-cka
cd production-cka

# 2. Set up 3-node minikube cluster
cd setup
chmod +x minikube-setup.sh
./minikube-setup.sh

# 3. Verify setup
kubectl get nodes
# Should show: opscart, opscart-m02, opscart-m03 (all Ready)

# 4. Start with Lab 01
cd ../labs/cluster-architecture/01-rbac-basics
cat README.md
```

---

## 📖 How to Use This Course

### Self-Paced Learning

```bash
# Each lab follows this pattern:
cd labs/cluster-architecture/XX-lab-name/

# 1. Read the lab
cat README.md

# 2. Run setup
./scripts/setup.sh

# 3. Complete tasks manually
# Follow README.md instructions

# 4. Validate your work
./scripts/test.sh

# 5. Check solution if needed
cat solutions/SOLUTION.md

# 6. Clean up
./scripts/cleanup.sh
```

### Lab Structure

```
labXX-topic-name/
├── README.md              # Main instructions (scenarios, tasks, tips)
├── QUICK-REFERENCE.md     # Command cheat sheet
├── manifests/             # YAML files
├── scripts/
│   ├── setup.sh           # Automated setup
│   ├── test.sh            # Validation (automated tests)
│   └── cleanup.sh         # Remove lab resources
└── solutions/
    └── SOLUTION.md        # Step-by-step solutions
```

---

## 📊 Exam Information

### CKA v1.34 Details

- **Format:** Performance-based (hands-on tasks)
- **Duration:** 2 hours
- **Questions:** 15-20 tasks
- **Passing Score:** ~74%
- **Cost:** $445 (includes 2 attempts + 2 killer.sh simulations)
- **Valid:** 3 years from passing

### Allowed Resources During Exam

✅ kubernetes.io/docs  
✅ kubernetes.io/blog  
❌ Google, Stack Overflow, notes, other sites

### Time Management

```
Cluster Architecture:  25% → 30 minutes
Services & Networking: 20% → 24 minutes
Workloads:            15% → 18 minutes
Storage:              10% → 12 minutes
Troubleshooting:      30% → 36 minutes
```

---

## 🎓 Study Plan

### 10-Week Intensive Plan

**Weeks 1-2:** Cluster Architecture (18 labs)  
**Weeks 3-4:** Workloads & Scheduling (11 labs)  
**Weeks 5-6:** Services & Networking (14 labs)  
**Week 7:** Storage (7 labs)  
**Weeks 8-9:** Troubleshooting (20 labs)  
**Week 10:** Review & Practice Exams

[View detailed strategy →](./COURSE-STRATEGY.md)

---

## 💡 Key Features

### Real Production Scenarios

Every lab uses realistic scenarios:
- Pharmaceutical company with FDA compliance
- Multi-tenant AKS clusters (8+ in production)
- 500+ cores, 2TB+ memory management
- HIPAA, SOC2, FDA validation requirements
- Cost optimization ($50K+/month AWS/Azure spend)

### Platform-Aware Learning

**Lab 05 Example:** etcd Backup & Restore
- ✅ Works on minikube (with docker cp workaround)
- ✅ Works on kubeadm (standard kubectl cp)
- 📝 Documents 4 major challenges encountered
- 💡 Explains distroless containers
- 🎯 Exam-ready commands for kubeadm

### Comprehensive Documentation

- Inline comments in all scripts
- Detailed troubleshooting sections
- Common issues and solutions
- Production best practices
- Exam tips and time budgets

---

## 👨‍💻 Author

**Shamsher Khan**
- **Role:** Senior DevOps Engineer @ GlobalLogic (Hitachi Company)
- **Experience:** 15+ years in IT, 5+ years Kubernetes
- **Production:** Managing 8+ AKS clusters for Fortune 500 pharma
- **Scale:** 500+ cores, 200+ applications, 50+ developers
- **Community:**
  - IEEE Senior Member
  - DZone Core Member (1000+ subscribers)
  - OpsCart.com technical blog
  - Open-source contributor

**Connect:**
- 🌐 Blog: [opscart.com](https://opscart.com)
- 💼 LinkedIn: [Shamsher Khan](https://linkedin.com/in/shamsher-khan)
- 📝 DZone: [@shamsherkhan](https://dzone.com/users/shamsherkhan)
- 🐙 GitHub: [@opscart](https://github.com/opscart)

---

## 📂 Repository Structure

```
production-cka/
├── README.md                    # This file
├── COURSE-STRATEGY.md           # Complete 70-lab roadmap
├── setup/
│   ├── minikube-setup.sh        # 3-node cluster setup
│   └── requirements.md          # Prerequisites
├── labs/
│   ├── cluster-architecture/    # 18 labs (25% of exam)
│   ├── networking/              # 14 labs (20% of exam)
│   ├── workloads/               # 11 labs (15% of exam)
│   ├── storage/                 # 7 labs (10% of exam)
│   └── troubleshooting/         # 20 labs (30% of exam)
└── docs/
    └── kubectl-cheatsheet.md    # Quick reference
```

---

## 🤝 Contributing

This is a living course! Contributions welcome:

- 🐛 Report issues or bugs
- 💡 Suggest improvements
- 📝 Share your learning experience
- ⭐ Star the repo if it helps you!

---

## 📜 License

**MIT License** - Free for personal use and learning.

**Attribution appreciated** when sharing or adapting content.

---

## 🎯 Exam Preparation Resources

### Official Resources
- [CKA Exam Overview](https://www.cncf.io/certification/cka/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [CNCF Curriculum](https://github.com/cncf/curriculum)

### Practice Platforms
- killer.sh (included with exam registration)
- This course (70 hands-on labs)
- Your own minikube cluster

### Community
- [Kubernetes Slack](https://kubernetes.slack.com)
- [CNCF Community](https://community.cncf.io/)
- [OpsCart Blog](https://opscart.com)

---

## 📈 Progress Tracking

**Overall:** 5/70 labs complete (7.1%)

**By Domain:**
- Cluster Architecture: 5/18 (27.8%) ████████░░░░░░░░░░
- Services & Networking: 0/14 (0.0%) ░░░░░░░░░░░░░░░░░░
- Workloads: 0/11 (0.0%) ░░░░░░░░░░░░░░░░░░
- Storage: 0/7 (0.0%) ░░░░░░░░░░░░░░░░░░
- Troubleshooting: 0/20 (0.0%) ░░░░░░░░░░░░░░░░░░

**Time Invested:** ~4 hours  
**Estimated Remaining:** ~52 hours

[View detailed progress →](./COURSE-STRATEGY.md)

---

## 🚀 Ready to Start?

```bash
# Clone and begin your CKA journey
git clone https://github.com/opscart/production-cka
cd production-cka
./setup/minikube-setup.sh

# Start with Lab 01
cd labs/cluster-architecture/01-rbac-basics
cat README.md
```

**Questions?** Open an issue or visit [opscart.com](https://opscart.com)

---

**⭐ Star this repo if it helps your CKA preparation!**

Last Updated: March 2026 | CKA v1.34 Curriculum