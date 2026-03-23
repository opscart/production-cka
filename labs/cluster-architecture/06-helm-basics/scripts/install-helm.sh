#!/bin/bash
# Lab 06: Helm Basics - Install Helm Script

set -e

echo "🎯 Lab 06: Install Helm"
echo "======================="
echo ""

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if Helm is already installed
if command -v helm &> /dev/null; then
    HELM_VERSION=$(helm version --short)
    echo -e "${GREEN}✓ Helm already installed: $HELM_VERSION${NC}"
    echo ""
    helm version
    exit 0
fi

echo -e "${BLUE}Installing Helm...${NC}"
echo ""

# Detect OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    if command -v brew &> /dev/null; then
        echo "Installing via Homebrew..."
        brew install helm
    else
        echo -e "${YELLOW}Homebrew not found. Install manually from: https://helm.sh/docs/intro/install/${NC}"
        exit 1
    fi
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    echo "Installing via script..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
    echo -e "${YELLOW}Unsupported OS. Install manually from: https://helm.sh/docs/intro/install/${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ Helm installed successfully!${NC}"
echo ""

# Verify installation
helm version

echo ""
echo "Next steps:"
echo "  helm repo add bitnami https://charts.bitnami.com/bitnami"
echo "  helm search repo nginx"
echo "  helm install my-app bitnami/nginx"
