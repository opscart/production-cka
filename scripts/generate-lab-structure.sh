#!/bin/bash
# Generate lab structure for remaining Cluster Architecture labs (08-18)
# Run from: ~/Source/production-cka

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Guard: must run from repo root
if [ ! -f "README.md" ] || [ ! -d "labs" ]; then
    echo -e "${RED}Error: Run this script from the repo root!${NC}"
    echo ""
    echo "  cd ~/Source/production-cka"
    echo "  ./scripts/generate-lab-structure.sh"
    exit 1
fi
echo -e "${GREEN}✓ Running from: $(pwd)${NC}"
echo ""

echo "🏗️  Generating Lab Structure (08-18)"
echo "======================================"
echo ""

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

BASE="labs/cluster-architecture"

# All remaining labs in cluster-architecture domain
LABS=(
  "08-kustomize-basics|Kustomize Basics"
  "09-high-availability|High Availability Clusters"
  "10-cluster-components|Cluster Components Deep Dive"
  "11-api-server-auth|API Server Authentication"
  "12-admission-controllers|Admission Controllers"
  "13-service-accounts|Service Accounts"
  "14-crds-operators|CRDs and Operators"
  "15-cni-plugins|CNI Plugins"
  "16-csi-storage|CSI Storage"
  "17-cri-runtimes|CRI Container Runtimes"
  "18-cluster-maintenance|Cluster Maintenance"
)

for LAB in "${LABS[@]}"; do
  FOLDER=$(echo $LAB | cut -d'|' -f1)
  TITLE=$(echo $LAB | cut -d'|' -f2)
  LAB_NUM=$(echo $FOLDER | cut -d'-' -f1 | sed 's/^0*//')
  LAB_PATH="$BASE/$FOLDER"

  # Skip if already exists
  if [ -d "$LAB_PATH" ]; then
    echo -e "${GREEN}✓ Lab $LAB_NUM already exists: $LAB_PATH${NC}"
    continue
  fi

  echo -e "${BLUE}Creating Lab $LAB_NUM: $TITLE${NC}"

  # Create directory structure
  mkdir -p $LAB_PATH/{scripts,solutions,manifests}

  # README
  cat > $LAB_PATH/README.md << EOF
# Lab $LAB_NUM: $TITLE

## Objective
TODO: Add lab objective.

## CKA Exam Relevance
- **Domain:** Cluster Architecture, Installation & Configuration (25%)
- **Topic:** TODO
- **Exam Weight:** TODO
- **Typical Exam Time:** TODO minutes

## Time to Complete
TODO minutes

## Prerequisites
- Completed Labs 01-0$((LAB_NUM - 1))
- Running minikube cluster

---

## Tasks

### Task 1: TODO (X min)

\`\`\`bash
# TODO: Add commands
\`\`\`

---

## Next Lab

Move to **[Lab $((LAB_NUM + 1))](../$FOLDER/README.md)**

---

**Author:** Shamsher Khan | **Blog:** opscart.com | **Course:** Production CKA 2026
EOF

  # QUICK-REFERENCE
  cat > $LAB_PATH/QUICK-REFERENCE.md << EOF
# Lab $LAB_NUM: $TITLE - Quick Reference

## Essential Commands

\`\`\`bash
# TODO: Add commands
\`\`\`

---

## Exam Scenarios

### Scenario 1: TODO

\`\`\`bash
# TODO
\`\`\`

---

## Time Budget (Exam)

- TODO: **X minutes**
- **Total: ~X minutes**
EOF

  # Scripts
  for SCRIPT in setup.sh test.sh cleanup.sh; do
    cat > $LAB_PATH/scripts/$SCRIPT << EOF
#!/bin/bash
# Lab $LAB_NUM: $TITLE - ${SCRIPT%.sh} script
# TODO: Implement

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "🔧 Lab $LAB_NUM: $TITLE - ${SCRIPT%.sh}"
echo "TODO: Implement ${SCRIPT%.sh} logic"
EOF
    chmod +x $LAB_PATH/scripts/$SCRIPT
  done

  # SOLUTION
  cat > $LAB_PATH/solutions/SOLUTION.md << EOF
# Lab $LAB_NUM: $TITLE - Solution Guide

## Complete Solution

### Step 1: TODO

\`\`\`bash
# TODO: Add solution
\`\`\`

---

## Key Takeaways

- TODO

---

**Completed Lab $LAB_NUM?** ✅
EOF

  echo -e "  ${GREEN}✓ Created: $LAB_PATH${NC}"
  echo ""
done

echo "======================================"
echo -e "${GREEN}✓ Done!${NC}"
echo ""
echo "Cluster Architecture Domain (18 labs):"
echo ""
echo "  ✅ 01-rbac-basics              (complete)"
echo "  ✅ 02-rbac-advanced            (complete)"
echo "  ✅ 03-kubeadm-install          (complete)"
echo "  ✅ 04-cluster-upgrade          (complete)"
echo "  ✅ 05-etcd-backup-restore      (complete)"
echo "  ✅ 06-helm-basics              (complete)"
echo "  ✅ 07-helm-charts              (complete)"
echo "  🏗️  08-kustomize-basics        (scaffolded)"
echo "  🏗️  09-high-availability       (scaffolded)"
echo "  🏗️  10-cluster-components      (scaffolded)"
echo "  🏗️  11-api-server-auth         (scaffolded)"
echo "  🏗️  12-admission-controllers   (scaffolded)"
echo "  🏗️  13-service-accounts        (scaffolded)"
echo "  🏗️  14-crds-operators          (scaffolded)"
echo "  🏗️  15-cni-plugins             (scaffolded)"
echo "  🏗️  16-csi-storage             (scaffolded)"
echo "  🏗️  17-cri-runtimes            (scaffolded)"
echo "  🏗️  18-cluster-maintenance     (scaffolded)"
echo ""
echo "Next: Fill in content for Lab 08"
echo "  cd labs/cluster-architecture/08-kustomize-basics"