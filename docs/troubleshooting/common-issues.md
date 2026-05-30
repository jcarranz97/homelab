# Common Issues

This section documents common issues I've encountered in my homelab and their solutions.

## Homarr Dashboard Lost After Restart

**Problem**: Homarr configuration (tiles, layout, apps) disappears every time the pod restarts.

**Root Cause**: The Helm chart v8.x changed the persistence parameter schema. Using the old
`persistence.enabled=true` with `persistence.storageClassName=standard` silently creates the
deployment without any PVC — all data lives in the container's ephemeral filesystem.
Additionally, there is no `standard` StorageClass in this cluster (only `local-path`), so
even the old schema would fail to provision a volume.

**Diagnosis**:

```bash
# No PVC means no persistence
kubectl get pvc -n homarr
# Expected (broken): No resources found
# Expected (healthy): homarr-database   Bound   ...

# Check current Helm values
helm get values homarr -n homarr
# Broken: persistence.enabled=true, storageClassName=standard
# Fixed:  persistence.homarrDatabase.enabled=true, storageClassName=local-path
```

**Fix**: Upgrade with the correct persistence schema:

```bash
helm upgrade homarr homarr-labs/homarr -n homarr \
  --reuse-values \
  --set persistence.homarrDatabase.enabled=true \
  --set persistence.homarrDatabase.storageClassName=local-path \
  --set persistence.homarrDatabase.size=2Gi
```

Verify the PVC was created and is bound:

```bash
kubectl get pvc -n homarr
# NAME              STATUS   VOLUME   CAPACITY   STORAGECLASS
# homarr-database   Bound    ...      2Gi        local-path
```

After the upgrade, reconfigure the dashboard once — it will persist through future restarts.

---

## Rancher Cluster Showing as "Unavailable"

**Problem**: An imported cluster shows `Unavailable — Cluster agent is not connected` in Rancher.

**Root Cause**: The `cattle-cluster-agent` deployment has `CATTLE_SERVER` hardcoded to a hostname
whose TLS certificate no longer matches — either because the Rancher URL changed or the
certificate was re-issued for a different hostname.

**Diagnosis**:

```bash
# Check agent pod logs for TLS or DNS errors
kubectl logs -n cattle-system -l app=cattle-cluster-agent --tail=20

# Common errors:
# "x509: certificate is valid for <old-name>, not <cattle-server-hostname>"
# "Could not resolve host: <hostname>"

# Check what URL the agent is configured to use
kubectl get deployment cattle-cluster-agent -n cattle-system \
  -o jsonpath='{.spec.template.spec.containers[0].env}' | \
  python3 -c "import sys,json; [print(e['name'],'=',e.get('value','[ref]')) for e in json.load(sys.stdin) if 'SERVER' in e['name']]"
```

**Fix**:

1. Identify the correct Rancher hostname (the one matching the TLS certificate SAN):

   ```bash
   KUBECONFIG=~/.kube/k3s-local.yaml kubectl get secret tls-rancher-ingress \
     -n cattle-system -o jsonpath='{.data.tls\.crt}' | \
     base64 -d | openssl x509 -noout -text | grep "DNS:"
   ```

2. Update the credentials secret and the deployment env var:

   ```bash
   RANCHER_URL="https://rancher.dev.lan"  # replace with your correct hostname

   kubectl patch secret cattle-credentials-<id> -n cattle-system \
     --type='json' \
     -p='[{"op":"replace","path":"/data/url","value":"'$(echo -n "$RANCHER_URL" | base64)'"}]'

   # Find the index of CATTLE_SERVER in the env array, then patch it
   kubectl patch deployment cattle-cluster-agent -n cattle-system --type='json' \
     -p='[{"op":"replace","path":"/spec/template/spec/containers/0/env/<index>/value","value":"'"$RANCHER_URL"'"}]'
   ```

3. If the cluster pods cannot resolve the Rancher hostname via DNS, add a `hostAlias`:

   ```bash
   RANCHER_IP="192.168.1.233"  # replace with your Rancher ingress IP
   kubectl patch deployment cattle-cluster-agent -n cattle-system --type='json' \
     -p='[{"op":"add","path":"/spec/template/spec/hostAliases","value":[{"ip":"'"$RANCHER_IP"'","hostnames":["rancher.dev.lan"]}]}]'
   ```

4. Verify both agents reach Running state:

   ```bash
   kubectl get pods -n cattle-system | grep cattle-cluster-agent
   # Both pods should show Running with 0+ restarts
   ```

---

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
