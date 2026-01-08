# CKA Kubectl Cheatsheet

## Essential Aliases (Add to ~/.bashrc)
```bash
alias k='kubectl'
alias kg='kubectl get'
alias kd='kubectl describe'
alias kdel='kubectl delete'
alias kaf='kubectl apply -f'
alias kgp='kubectl get pods'
alias kgn='kubectl get nodes'
alias kgs='kubectl get svc'
alias kl='kubectl logs'
alias kex='kubectl exec -it'

# Dry-run shortcut
export do='--dry-run=client -o yaml'
```

## Quick Resource Creation
```bash
# Pod
k run nginx --image=nginx $do > pod.yaml

# Deployment
k create deploy nginx --image=nginx --replicas=3 $do > deploy.yaml

# Service
k expose deploy nginx --port=80 $do > svc.yaml

# ConfigMap
k create cm myconfig --from-literal=key=value $do > cm.yaml

# Secret
k create secret generic mysecret --from-literal=pass=secret123 $do > secret.yaml

# Job
k create job myjob --image=busybox -- echo "hello" $do > job.yaml

# CronJob
k create cronjob mycron --image=busybox --schedule="*/5 * * * *" -- echo "hello" $do > cronjob.yaml
```

## Context & Namespace
```bash
# Switch context
k config use-context <context-name>

# Set default namespace
k config set-context --current --namespace=<namespace>

# View contexts
k config get-contexts
```

## Troubleshooting
```bash
# Pod logs
k logs <pod-name>
k logs <pod-name> -c <container-name>
k logs <pod-name> --previous

# Exec into pod
k exec -it <pod-name> -- /bin/sh

# Port forward
k port-forward <pod-name> 8080:80

# Describe (most useful!)
k describe pod <pod-name>
k describe node <node-name>
```

## RBAC
```bash
# Can I?
k auth can-i get pods
k auth can-i delete deployments --as=user@example.com
k auth can-i '*' '*' --as=system:serviceaccount:dev:dev-user -n dev
```

## JSONPath (exam essential!)
```bash
# Get pod IPs
k get pods -o jsonpath='{.items[*].status.podIP}'

# Get node names
k get nodes -o jsonpath='{.items[*].metadata.name}'

# Custom columns
k get pods -o custom-columns=NAME:.metadata.name,IP:.status.podIP
```

## Speed Tricks
```bash
# Force delete
k delete pod nginx --force --grace-period=0

# Quick edit
k edit deploy nginx

# Replace (faster than apply for updates)
k replace -f deploy.yaml --force

# Scale
k scale deploy nginx --replicas=5
```
