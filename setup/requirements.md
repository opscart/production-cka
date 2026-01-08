# CKA Lab Requirements

## System Requirements

### Minimum
- **CPU:** 4 cores
- **RAM:** 8 GB
- **Disk:** 20 GB free space
- **OS:** macOS 10.14+, Linux (Ubuntu 20.04+), Windows 10+ with WSL2

### Recommended
- **CPU:** 6+ cores
- **RAM:** 16 GB
- **Disk:** 50 GB free space

## Software Prerequisites

### Required Tools

| Tool | Version | Installation |
|------|---------|--------------|
| Docker | 20.10+ | https://docs.docker.com/get-docker/ |
| minikube | 1.32+ | https://minikube.sigs.k8s.io/docs/start/ |
| kubectl | 1.34+ | https://kubernetes.io/docs/tasks/tools/ |
| Helm | 3.12+ | https://helm.sh/docs/intro/install/ |

### Installation Commands

**macOS (Homebrew):**
```bash
brew install docker
brew install minikube
brew install kubectl
brew install helm
```

**Linux (Ubuntu/Debian):**
```bash
# Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

## Verification
```bash
# Verify installations
docker --version
minikube version
kubectl version --client
helm version

# Verify Docker is running
docker ps

# Verify available resources
docker info | grep -E 'CPUs|Total Memory'
```

## Optional Tools (Recommended)

- **k9s:** Terminal UI for K8s - `brew install k9s`
- **kubectx/kubens:** Context switching - `brew install kubectx`
- **yq:** YAML processor - `brew install yq`
- **jq:** JSON processor - `brew install jq`

## CKA Exam Environment

The actual CKA exam uses:
- **Kubernetes version:** 1.34
- **kubectl access only** (no k9s, no IDE)
- **Documentation access:** kubernetes.io/docs, kubernetes.io/blog
- **Text editor:** vim or nano

Practice with these constraints!
