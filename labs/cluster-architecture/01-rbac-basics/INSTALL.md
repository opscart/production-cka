# Lab 01 Setup Instructions

## Files to Copy to Your Local Repository

Copy the downloaded files to your `production-cka` repository with this structure:

```
production-cka/
└── labs/
    └── 01-cluster-architecture/
        └── lab01-rbac-basics/
            ├── README.md                    # Main lab instructions
            ├── QUICK-REFERENCE.md           # Cheat sheet
            ├── manifests/
            │   ├── dev-role.yaml           # Role definition
            │   └── dev-rolebinding.yaml    # RoleBinding definition
            ├── scripts/
            │   ├── setup.sh                # Automated setup
            │   ├── test.sh                 # Validation tests
            │   └── cleanup.sh              # Cleanup script
            └── solutions/
                └── SOLUTION.md             # Step-by-step solution
```

## Quick Setup

```bash
# Navigate to your repo
cd ~/Source/production-cka

# Create directory structure
mkdir -p labs/01-cluster-architecture/lab01-rbac-basics/{manifests,scripts,solutions}

# Copy files to appropriate locations
# (Download the 8 files and place them as shown above)

# Make scripts executable
chmod +x labs/01-cluster-architecture/lab01-rbac-basics/scripts/*.sh
```

## How to Use This Lab

### Method 1: Automated (Quick Test)

```bash
cd labs/01-cluster-architecture/lab01-rbac-basics

# Run setup
./scripts/setup.sh

# Run tests
./scripts/test.sh

# Cleanup
./scripts/cleanup.sh
```

### Method 2: Manual (Exam Practice)

```bash
cd labs/01-cluster-architecture/lab01-rbac-basics

# Read the README
cat README.md

# Follow the tasks manually
# Use the manifests as reference
# Don't look at solutions until you're stuck!

# Validate your work
./scripts/test.sh
```

### Method 3: Timed Practice (Exam Simulation)

```bash
# Set a timer for 7 minutes
# Complete all tasks from memory
# Use only kubernetes.io docs

# When done, validate
./scripts/test.sh
```

## Testing Your Setup

Once you've copied all files:

```bash
# Ensure minikube is running
minikube status

# If not running, start it
minikube start --nodes=3

# Run the lab
cd labs/01-cluster-architecture/lab01-rbac-basics
./scripts/setup.sh
./scripts/test.sh
```

Expected output from test.sh:
```
🧪 Lab 01: RBAC Basics - Validation Tests
===========================================

=== Positive Tests (Should Succeed) ===

Test 1: Can get pods... ✅ PASS
Test 2: Can create pods... ✅ PASS
Test 3: Can list deployments... ✅ PASS
Test 4: Can create deployments... ✅ PASS
Test 5: Can update deployments... ✅ PASS
Test 6: Can get pod logs... ✅ PASS

=== Negative Tests (Should Fail) ===

Test 7: Cannot delete deployments... ✅ PASS
Test 8: Cannot get secrets... ✅ PASS
Test 9: Cannot create secrets... ✅ PASS
Test 10: Cannot access nodes... ✅ PASS
Test 11: Cannot access default namespace... ✅ PASS

=== Resource Verification ===

✅ Namespace 'dev' exists
✅ ServiceAccount 'dev-user' exists
✅ Role 'dev-role' exists
✅ RoleBinding 'dev-rolebinding' exists

===========================================
Test Results: 15/15 passed
===========================================

🎉 All tests passed! Lab 01 completed successfully!
```

## Next Steps

1. Complete Lab 01 manually at least once
2. Practice with timer (aim for < 5 minutes)
3. Review the QUICK-REFERENCE.md
4. Ready for Lab 02? Let me know!

## Troubleshooting

**Issue: Scripts won't run**
```bash
chmod +x scripts/*.sh
```

**Issue: Minikube not found**
```bash
# Install minikube first
brew install minikube  # macOS
```

**Issue: kubectl not found**
```bash
# Install kubectl
brew install kubectl  # macOS
```

**Issue: Tests failing**
```bash
# Check cluster status
kubectl cluster-info
minikube status

# Re-run setup
./scripts/cleanup.sh
./scripts/setup.sh
```