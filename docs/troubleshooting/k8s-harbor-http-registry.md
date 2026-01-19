# Troubleshooting K8s Harbor HTTP Registry Issues

This document contains troubleshooting steps for common issues when configuring Kubernetes clusters to work with
Harbor HTTP registries.

## Registry Configuration Not Applied

**Symptoms**: Still getting HTTPS errors after configuration

**Solutions**:

1. Verify the file path: `/etc/rancher/k3s/registries.yaml`
2. Check YAML syntax (proper indentation)
3. Ensure you restarted the correct service name
4. Wait a few minutes for configuration to propagate

## Service Not Found

**Error**: `Failed to restart k3s.service: Unit k3s.service not found`

**Solution**: Check the actual service name:

```bash
systemctl list-units --type=service | grep k3s
```

Use the correct service name (`k3s.service` or `k3s-agent.service`).

## Image Still Not Pulling

**Check these items**:

1. Harbor registry is accessible: `curl http://192.168.1.206:30002/v2/`
2. Image exists in Harbor
3. Kubernetes secret exists: `kubectl get secrets -n your-namespace`
4. All nodes have been configured and restarted

## Verification Commands

```bash
# Check node configuration
cat /etc/rancher/k3s/registries.yaml

# Check k3s service status
systemctl status k3s        # or k3s-agent
systemctl status k3s-agent  # or k3s

# Check containerd configuration (should show your registry)
crictl info

# Test registry connectivity from node
curl http://192.168.1.206:30002/v2/
```

## Common Error Messages

### ImagePullBackOff

**Error**: Pod shows `ImagePullBackOff` status

**Causes & Solutions**:

- **HTTP/HTTPS mismatch**: Configure nodes with registries.yaml (see main guide)
- **Missing pull secret**: Create harbor-secret in the target namespace
- **Incorrect image path**: Verify project name and image name in Harbor
- **Network connectivity**: Test Harbor accessibility from cluster nodes

### ErrImagePull

**Error**: `Failed to pull image: http: server gave HTTP response to HTTPS client`

**Solution**: This is the classic HTTP registry issue. Follow the main configuration guide to set up
`/etc/rancher/k3s/registries.yaml` on all nodes.

### Authentication Errors

**Error**: `pull access denied`

**Solutions**:

1. Verify Harbor credentials are correct
2. Check if the image/project exists in Harbor
3. Ensure the pull secret is created in the correct namespace:

   ```bash
   kubectl create secret docker-registry harbor-secret \
     --docker-server=192.168.1.206:30002 \
     --docker-username=<username> \
     --docker-password=<password> \
     --namespace=<target-namespace>
   ```

## Diagnostic Steps

### Step 1: Test Harbor Connectivity

From each cluster node:

```bash
# Test basic connectivity
curl http://192.168.1.206:30002/v2/

# Expected response: should return JSON with registry info
```

### Step 2: Verify Registry Configuration

On each k3s node:

```bash
# Check if registries.yaml exists and has correct content
cat /etc/rancher/k3s/registries.yaml

# Check k3s service is running
systemctl status k3s        # for control plane
systemctl status k3s-agent  # for worker nodes
```

### Step 3: Check Kubernetes Resources

From your kubectl client:

```bash
# Check if harbor secret exists
kubectl get secrets -A | grep harbor

# Check pod events for detailed error messages
kubectl describe pod <failing-pod> -n <namespace>

# Check deployment status
kubectl get deployments -n <namespace>
```

### Step 4: Test Image Pull Manually

On a cluster node:

```bash
# Test manual image pull using crictl
crictl pull 192.168.1.206:30002/library/your-image:latest

# If this fails, the node configuration is incorrect
```

## Node-Specific Issues

### Control Plane vs Worker Nodes

**Issue**: Different service names on different node types

**Solution**: Check actual service name on each node:

```bash
systemctl list-units --type=service | grep k3s
```

- Control plane usually: `k3s.service`
- Worker nodes usually: `k3s-agent.service`

### Mixed Architecture Clusters

**Issue**: Different nodes might have different configurations

**Solution**: Ensure consistent `/etc/rancher/k3s/registries.yaml` on ALL nodes, regardless of role.

## Network Issues

### Harbor Not Accessible

**Symptoms**: `connection refused` or timeout errors

**Check**:

1. Harbor service is running: `kubectl get pods -n harbor-system`
2. Harbor NodePort service: `kubectl get svc -n harbor-system`
3. Network connectivity from nodes to Harbor
4. Firewall rules allowing traffic on port 30002

### DNS Resolution

**Issue**: Using hostname instead of IP address

**Solution**: Either:

- Use IP addresses consistently
- Ensure DNS resolution works from all nodes
- Add entries to `/etc/hosts` on all nodes

## Configuration Validation

### YAML Syntax

Common YAML syntax errors in registries.yaml:

```yaml
# CORRECT
mirrors:
  "192.168.1.206:30002":
    endpoint:
      - "http://192.168.1.206:30002"

# INCORRECT (wrong indentation)
mirrors:
"192.168.1.206:30002":
  endpoint:
    - "http://192.168.1.206:30002"
```

### File Permissions

Ensure registries.yaml has correct permissions:

```bash
# Set proper ownership and permissions
chown root:root /etc/rancher/k3s/registries.yaml
chmod 644 /etc/rancher/k3s/registries.yaml
```

## Related Issues

### Docker Desktop Configuration

If using Docker Desktop with WSL2, also configure Docker Desktop settings:

1. Open Docker Desktop settings
2. Go to "Docker Engine"
3. Add insecure registry to JSON configuration

### Multiple Registry Support

To support multiple HTTP registries:

```yaml
mirrors:
  "192.168.1.206:30002":
    endpoint:
      - "http://192.168.1.206:30002"
  "registry2.local:5000":
    endpoint:
      - "http://registry2.local:5000"
configs:
  "192.168.1.206:30002":
    tls:
      insecure_skip_verify: true
  "registry2.local:5000":
    tls:
      insecure_skip_verify: true
```

## Getting Help

If issues persist:

1. Check k3s logs: `journalctl -u k3s -f` (or `k3s-agent`)
2. Check containerd logs: `journalctl -u containerd -f`
3. Verify Harbor logs in Kubernetes: `kubectl logs -n harbor-system <harbor-pod>`
4. Test with a simple public image first to isolate registry issues

## Quick Resolution Checklist

- [ ] `/etc/rancher/k3s/registries.yaml` exists on ALL nodes
- [ ] YAML syntax is correct (proper indentation)
- [ ] Correct k3s service restarted on each node
- [ ] Harbor is accessible via HTTP from all nodes
- [ ] Pull secret exists in the target namespace
- [ ] Image path is correct in deployment YAML
- [ ] All nodes show "Ready" status in `kubectl get nodes`
