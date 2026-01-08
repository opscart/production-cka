# CKA Lab Setup Troubleshooting Guide

## Common Issues & Solutions

### Issue 1: Docker Not Running
**Error:** `Cannot connect to Docker daemon`
**Solution:**
```bash
# macOS
open -a Docker

# Linux
sudo systemctl start docker
```

### Issue 2: Insufficient Resources
**Error:** `Requested cpus/memory exceeds available`
**Solution:**
- Close other applications
- Reduce cluster resources:
```bash
minikube start --nodes=2 --cpus=2 --memory=3072
```

### Issue 3: VPN Conflicts
**Error:** Network connectivity issues
**Solution:**
- Disconnect VPN during cluster setup
- Or use `--driver=hyperkit` instead of docker

### Issue 4: Port Already in Use
**Error:** `Port 8443 already in use`
**Solution:**
```bash
minikube delete
minikube start --nodes=3
```

### Issue 5: Old Minikube Version
**Error:** `Unknown flag --kubernetes-version`
**Solution:**
```bash
# Update minikube
brew upgrade minikube  # macOS
# or download latest from minikube.sigs.k8s.io
```

### Issue 6: Kubernetes Version Not Available
**Error:** `v1.34.0 not found`
**Solution:**
```bash
# Use latest stable
minikube start --nodes=3 --kubernetes-version=stable
```

### Issue 7: Cluster Stuck in Starting
**Error:** Hangs at "Waiting for cluster to come online"
**Solution:**
```bash
minikube delete -p cka-lab --all --purge
minikube start --nodes=3 --driver=docker
```

## Verification Commands
```bash
# Check cluster status
minikube status -p cka-lab

# Check nodes
kubectl get nodes

# Check system pods
kubectl get pods -n kube-system

# View cluster info
kubectl cluster-info

# Check resources
minikube profile list
```

## Reset Cluster
```bash
# Complete reset
minikube delete -p cka-lab
rm -rf ~/.minikube/profiles/cka-lab
./minikube-setup.sh
```