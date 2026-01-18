# Common Issues

This section documents common issues I've encountered in my homelab and their solutions.

## Container Registry Issues

### Harbor Login Failures

**Problem**: `docker login 192.168.1.206:30002` fails with authentication error

**Solutions**:

1. Verify Harbor service is running:

   ```bash
   kubectl get pods -n harbor-system  # or wherever Harbor is deployed
   ```

2. Check if the registry URL is accessible:

   ```bash
   curl -I http://192.168.1.206:30002/
   ```

3. Verify credentials in Harbor web UI first

### Image Push Failures

**Problem**: `docker push` fails with "denied: requested access to the resource is denied"

**Solutions**:

1. Ensure you're logged in: `docker login 192.168.1.206:30002`
2. Verify project exists in Harbor
3. Check if user has push permissions to the project
4. Ensure image is tagged correctly with full registry path

## Kubernetes Deployment Issues

### ImagePullBackOff Errors

**Problem**: Pods stuck in `ImagePullBackOff` state

**Diagnosis**:

```bash
kubectl describe pod <pod-name> -n <namespace>
```

**Common Solutions**:

1. **Missing Pull Secret**:

   ```bash
   kubectl create secret docker-registry harbor-secret \
     --docker-server=192.168.1.206:30002 \
     --docker-username=<username> \
     --docker-password=<password> \
     --namespace=<namespace>
   ```

2. **Wrong Image Path**: Verify the image exists in Harbor and path is correct

3. **Network Issues**: Check if cluster can reach Harbor registry

### Persistent Volume Issues

**Problem**: Pods can't mount persistent volumes

**Solutions**:

1. Check if PV and PVC are bound:

   ```bash
   kubectl get pv,pvc -n <namespace>
   ```

2. Verify storage class exists:

   ```bash
   kubectl get storageclass
   ```

3. Check node permissions for local storage

## Network Connectivity Issues

### Service Not Accessible

**Problem**: Can't access services via NodePort or LoadBalancer

**Diagnosis**:

```bash
kubectl get svc -n <namespace>
kubectl describe svc <service-name> -n <namespace>
```

**Solutions**:

1. **NodePort Issues**:
   - Check if port is in valid NodePort range (30000-32767)
   - Verify firewall rules allow the port
   - Test from within cluster first

2. **LoadBalancer Issues**:
   - Verify LoadBalancer controller is installed
   - Check external IP assignment

3. **Ingress Issues**:
   - Verify Ingress controller is running
   - Check DNS resolution
   - Validate TLS certificates if using HTTPS

## Resource Constraints

### Pod Evictions

**Problem**: Pods getting evicted due to resource pressure

**Diagnosis**:

```bash
kubectl top nodes
kubectl top pods --all-namespaces
kubectl describe node <node-name>
```

**Solutions**:

1. Increase resource limits in deployments
2. Add more worker nodes
3. Optimize resource requests
4. Clean up unused images and containers

## General Debugging Commands

### Pod Issues

```bash
# Check pod status and events
kubectl get pods -n <namespace>
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>

# Get shell access to pod
kubectl exec -it <pod-name> -n <namespace> -- /bin/bash
```

### Service Issues

```bash
# Test service connectivity
kubectl port-forward svc/<service-name> <local-port>:<service-port> -n <namespace>

# Check endpoints
kubectl get endpoints <service-name> -n <namespace>
```

### Network Debugging

```bash
# Run network debug pod
kubectl run tmp-shell --rm -i --tty --image nicolaka/netshoot -- /bin/bash

# DNS testing
nslookup <service-name>.<namespace>.svc.cluster.local
```

## When All Else Fails

1. **Check cluster events**: `kubectl get events --sort-by=.metadata.creationTimestamp`
2. **Restart problematic pods**: `kubectl delete pod <pod-name> -n <namespace>`
3. **Check cluster logs**: Look at kubelet and container runtime logs on nodes
4. **Community help**: Search GitHub issues, Stack Overflow, or Kubernetes Slack

## Prevention Tips

- Always use resource limits and requests
- Implement health checks (liveness/readiness probes)
- Monitor resource usage regularly
- Keep cluster and applications updated
- Use proper secrets management
- Document your configurations
