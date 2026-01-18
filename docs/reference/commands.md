# Useful Commands

A collection of frequently used commands for managing the homelab.

## Docker Commands

### Harbor Registry

```bash
# Login to Harbor
docker login 192.168.1.206:30002

# Build and tag for Harbor
docker build -t 192.168.1.206:30002/project/app:tag .

# Push to Harbor
docker push 192.168.1.206:30002/project/app:tag

# Pull from Harbor
docker pull 192.168.1.206:30002/project/app:tag

# List local images
docker images | grep 192.168.1.206:30002

# Clean up local images
docker image prune -f
```

## Kubernetes Commands

### Cluster Management

```bash
# Check cluster status
kubectl cluster-info
kubectl get nodes -o wide

# Check all resources
kubectl get all --all-namespaces

# Check cluster events
kubectl get events --sort-by=.metadata.creationTimestamp
```

### Pod Management

```bash
# Get pods in all namespaces
kubectl get pods --all-namespaces

# Get pods with more details
kubectl get pods -o wide -n <namespace>

# Describe a pod
kubectl describe pod <pod-name> -n <namespace>

# Get pod logs
kubectl logs <pod-name> -n <namespace>
kubectl logs -f <pod-name> -n <namespace>  # Follow logs

# Execute commands in pod
kubectl exec -it <pod-name> -n <namespace> -- /bin/bash
kubectl exec -it <pod-name> -n <namespace> -- sh
```

### Service Management

```bash
# List services
kubectl get svc --all-namespaces

# Port forward to local machine
kubectl port-forward svc/<service-name> <local-port>:<service-port> -n <namespace>

# Check service endpoints
kubectl get endpoints <service-name> -n <namespace>
```

### Deployment Management

```bash
# Apply manifests
kubectl apply -f <file.yaml>
kubectl apply -f <directory>/

# Update deployment image
kubectl set image deployment/<deployment-name> <container-name>=<new-image> -n <namespace>

# Scale deployment
kubectl scale deployment <deployment-name> --replicas=<count> -n <namespace>

# Check rollout status
kubectl rollout status deployment/<deployment-name> -n <namespace>

# Rollback deployment
kubectl rollout undo deployment/<deployment-name> -n <namespace>

# Check rollout history
kubectl rollout history deployment/<deployment-name> -n <namespace>
```

### Resource Management

```bash
# Check resource usage
kubectl top nodes
kubectl top pods --all-namespaces

# Get resource quotas
kubectl get resourcequota --all-namespaces

# Describe node resources
kubectl describe node <node-name>
```

### Secret Management

```bash
# Create docker registry secret
kubectl create secret docker-registry <secret-name> \
  --docker-server=<registry-url> \
  --docker-username=<username> \
  --docker-password=<password> \
  --namespace=<namespace>

# Create generic secret
kubectl create secret generic <secret-name> \
  --from-literal=key1=value1 \
  --from-literal=key2=value2 \
  --namespace=<namespace>

# List secrets
kubectl get secrets -n <namespace>

# View secret (base64 decoded)
kubectl get secret <secret-name> -n <namespace> -o jsonpath='{.data.<key>}' | base64 -d
```

### ConfigMap Management

```bash
# Create configmap from file
kubectl create configmap <configmap-name> --from-file=<path-to-file> -n <namespace>

# Create configmap from literal values
kubectl create configmap <configmap-name> \
  --from-literal=key1=value1 \
  --from-literal=key2=value2 \
  --namespace=<namespace>

# List configmaps
kubectl get configmaps -n <namespace>
```

### Debugging Commands

```bash
# Run debug pod
kubectl run debug-pod --image=busybox --rm -it --restart=Never -- sh

# Run network debug pod
kubectl run netshoot --image=nicolaka/netshoot --rm -it --restart=Never -- bash

# Check DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup <service-name>

# Test connectivity
kubectl run -it --rm debug --image=busybox --restart=Never -- wget -qO- http://<service-name>:<port>
```

## System Commands

### Node Management

```bash
# SSH to nodes (if applicable)
ssh <user>@<node-ip>

# Check docker on nodes
sudo docker ps
sudo docker images
sudo systemctl status docker

# Check kubelet on nodes
sudo systemctl status kubelet
sudo journalctl -u kubelet -f
```

### Harbor Management

```bash
# Check Harbor containers (if running as containers)
docker ps | grep harbor

# Harbor logs (if using docker-compose)
docker-compose -f harbor.yml logs -f
```

## One-liners

### Quick Status Checks

```bash
# Check if all pods are running
kubectl get pods --all-namespaces | grep -v Running | grep -v Completed

# Find pods using most CPU
kubectl top pods --all-namespaces --sort-by=cpu

# Find pods using most memory
kubectl top pods --all-namespaces --sort-by=memory

# Check failed pods
kubectl get pods --all-namespaces --field-selector=status.phase=Failed

# Get all ImagePullBackOff pods
kubectl get pods --all-namespaces | grep ImagePullBackOff
```

### Cleanup Commands

```bash
# Delete completed pods
kubectl delete pods --all-namespaces --field-selector=status.phase=Succeeded

# Delete failed pods
kubectl delete pods --all-namespaces --field-selector=status.phase=Failed

# Force delete stuck pod
kubectl delete pod <pod-name> -n <namespace> --grace-period=0 --force

# Clean up unused images on all nodes
kubectl get nodes -o name | xargs -I {} kubectl debug {} -it --image=alpine -- docker system prune -f
```

## Aliases

Add these to your `~/.bashrc` or `~/.zshrc`:

```bash
# Kubernetes aliases
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kgn='kubectl get nodes'
alias kga='kubectl get all'
alias kdp='kubectl describe pod'
alias kds='kubectl describe svc'
alias kl='kubectl logs'
alias kex='kubectl exec -it'

# Docker aliases
alias d='docker'
alias dps='docker ps'
alias dimg='docker images'
alias dlog='docker logs'
```
