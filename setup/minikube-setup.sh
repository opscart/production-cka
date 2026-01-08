#!/bin/bash
# Automated CKA Lab Setup for Kubernetes v1.34

set -e

echo "CKA Lab Environment Setup - Kubernetes v1.34"
echo "================================================"

# Prerequisites check
check_prerequisites() {
    echo "Checking prerequisites..."
    
    if ! command -v docker &> /dev/null; then
        echo "Docker not found. Install from: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    if ! command -v minikube &> /dev/null; then
        echo "Minikube not found. Install from: https://minikube.sigs.k8s.io/docs/start/"
        exit 1
    fi
    
    if ! command -v kubectl &> /dev/null; then
        echo "kubectl not found. Install from: https://kubernetes.io/docs/tasks/tools/"
        exit 1
    fi
    
    echo "✅ All prerequisites met!"
}

# Start cluster
start_cluster() {
    echo ""
    echo "Starting 3-node Kubernetes cluster..."
    
    minikube start \
        --nodes=3 \
        --cpus=2 \
        --memory=4096 \
        --driver=docker \
        --kubernetes-version=v1.34.0 \
        --cni=calico \
        --profile=cka-lab
    
    echo "Cluster started!"
}

# Enable addons
enable_addons() {
    echo ""
    echo "Enabling essential addons..."
    
    minikube addons enable metrics-server -p cka-lab
    minikube addons enable ingress -p cka-lab
    minikube addons enable storage-provisioner -p cka-lab
    
    echo "Addons enabled!"
}

# Setup aliases
setup_aliases() {
    echo ""
    echo "Setting up kubectl aliases..."
    
    cat >> ~/.bashrc << 'EOF'

# CKA Exam Aliases
alias k='kubectl'
alias kg='kubectl get'
alias kd='kubectl describe'
alias kdel='kubectl delete'
alias kaf='kubectl apply -f'
alias kgp='kubectl get pods'
alias kgn='kubectl get nodes'
alias kgs='kubectl get svc'
alias kgd='kubectl get deploy'
alias kl='kubectl logs'
alias kex='kubectl exec -it'
export do='--dry-run=client -o yaml'
EOF
    
    echo "Aliases configured! Run: source ~/.bashrc"
}

# Verify installation
verify_cluster() {
    echo ""
    echo "Verifying cluster..."
    
    kubectl config use-context cka-lab
    kubectl get nodes
    
    echo ""
    echo "✅ Setup complete! Your 3-node cluster is ready."
    echo ""
    echo "Quick commands:"
    echo "  kubectl get nodes        # View cluster nodes"
    echo "  kubectl get pods -A      # View all pods"
    echo "  minikube profile list    # View profiles"
    echo "  minikube stop -p cka-lab # Stop cluster"
    echo "  minikube delete -p cka-lab # Delete cluster"
}

# Main execution
main() {
    check_prerequisites
    start_cluster
    enable_addons
    setup_aliases
    verify_cluster
}

main