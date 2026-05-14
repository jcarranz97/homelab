# Homarr Landing Page

Homarr is a self-hosted, modern homelab landing page that provides a centralized dashboard for all your homelab applications. It offers a beautiful web UI for managing and accessing all your services in one place.

## Overview

- **URL**: <http://home.dev.lan>
- **Version**: Latest
- **Access**: Web UI
- **Features**:
  - Centralized dashboard for all homelab applications
  - Dynamic app management via web UI (no code changes)
  - Categories and app organization
  - Beautiful, responsive design
  - Self-hosted and open-source
  - Kubernetes native

## Access Information

### Web Interface

- **URL**: <http://home.dev.lan>
- **Access**: Browser at `http://home.dev.lan`
- **No authentication required** (open by default)

## Configuration

### Adding Applications

To add your homelab applications to Homarr:

1. Navigate to `http://home.dev.lan`
2. Click the **+** icon to add a new app
3. Fill in the following details:
   - **Name**: Application name (e.g., "Rancher", "Harbor")
   - **URL**: Full URL to the application (e.g., `http://rancher.local`)
   - **Icon**: Select from a library or upload your own (optional)
   - **Category**: Organize by category (optional)

### Current Applications

| Application | URL | Category | Status |
|-------------|-----|----------|--------|
| Rancher | http://rancher.local | Infrastructure | ✅ |
| Harbor | http://harbor.dev.lan | Container Registry | ✅ |
| Fast-API | http://fast-api.dev.lan | Development | ✅ |
| Multica | http://multica.dev.lan | Tools | ✅ |
| Colony | http://colony.dev.lan | Tools | ✅ |

## Deployment

Homarr is deployed on Kubernetes in the `homarr` namespace using Helm.

### Service Details

- **Namespace**: `homarr`
- **Service Type**: ClusterIP
- **Service Port**: 7575
- **Ingress**: Enabled (nginx-ingress controller)
- **Persistence**: Enabled (PersistentVolumeClaim)
- **Storage**: 2Gi

### Required Secrets

The Homarr Helm chart (v8.x+) expects a pre-existing secret named `db-encryption` in the `homarr` namespace, with a `db-encryption-key` entry used to encrypt the local SQLite database. Without it, the pod fails with `CreateContainerConfigError`. See [Step 3 of the setup guide](../guides/homarr-setup.md#step-3-create-the-db-encryption-secret).

### Accessing via Ingress

Homarr is accessed via an Ingress controller that routes `home.dev.lan` traffic to the Homarr service:

```
home.dev.lan → Ingress (nginx) → homarr Service (ClusterIP:7575) → homarr Pod
```

For DNS resolution, ensure that `home.dev.lan` is configured in your DNS server (Pi-hole, CoreDNS, or local `/etc/hosts`).

## Installation and Deployment

For detailed deployment instructions, including:
- Kubernetes manifest setup
- Helm installation
- Ingress configuration
- DNS configuration
- Troubleshooting

See the [Homarr Setup Guide](../guides/homarr-setup.md).

## Best Practices

### Organization

- Group related services into categories (Infrastructure, Development, Tools, etc.)
- Use clear, descriptive names for each application
- Add relevant icons to improve visual recognition

### Maintenance

- Regularly review and update application URLs if services move
- Remove applications that are no longer in use
- Backup your Homarr configuration periodically

## Integration with Other Services

### With Harbor

Homarr displays Harbor (container registry) as a bookmarked service, making it easy to access for:
- Container image management
- Registry administration
- Repository browsing

### With Rancher

Homarr links to Rancher for cluster management and app deployment.

## Backup and Recovery

### Backup Homarr Configuration

```bash
# Create a backup of Homarr data
kubectl exec -n homarr deployment/homarr -- \
  tar czf /app/data/homarr-backup.tar.gz /app/data

# Copy backup to local machine
kubectl cp homarr/$(kubectl get pods -n homarr -l app.kubernetes.io/name=homarr -o jsonpath='{.items[0].metadata.name}'):/app/data/homarr-backup.tar.gz ./homarr-backup.tar.gz
```

### Restore Homarr Configuration

```bash
# Copy backup back to pod
kubectl cp ./homarr-backup.tar.gz homarr/$(kubectl get pods -n homarr -l app.kubernetes.io/name=homarr -o jsonpath='{.items[0].metadata.name}'):/app/data/

# Restore from backup
kubectl exec -n homarr deployment/homarr -- \
  tar xzf /app/data/homarr-backup.tar.gz -C /app/data
```

## Troubleshooting

### Homarr not accessible via `home.dev.lan`

**Symptoms**: Browser times out or connection refused

**Solutions**:

1. Verify DNS resolution:
   ```bash
   nslookup home.dev.lan
   # Should resolve to your Ingress IP
   ```

2. Check Ingress status:
   ```bash
   kubectl describe ingress homarr -n homarr
   kubectl get ingress -n homarr -o wide
   ```

3. Verify Homarr pod is running:
   ```bash
   kubectl get pods -n homarr
   kubectl logs -n homarr deployment/homarr
   ```

### Pod in CrashLoopBackOff

**Symptoms**: Pod keeps restarting

**Solutions**:

1. Check logs:
   ```bash
   kubectl logs -n homarr deployment/homarr
   ```

2. Describe the pod for events:
   ```bash
   kubectl describe pod -n homarr -l app.kubernetes.io/name=homarr
   ```

3. Check resource requests/limits:
   ```bash
   kubectl top pod -n homarr
   ```

### Storage issues

**Symptoms**: Pod fails due to storage errors

**Solutions**:

1. Verify PVC is bound:
   ```bash
   kubectl get pvc -n homarr
   # Should show Bound status
   ```

2. Check available storage:
   ```bash
   kubectl get pv
   kubectl describe pvc homarr-data -n homarr
   ```

3. Resize PVC if needed:
   ```bash
   kubectl patch pvc homarr-data -n homarr \
     -p '{"spec":{"resources":{"requests":{"storage":"5Gi"}}}}'
   ```

### Ingress not routing traffic

**Symptoms**: Ingress shows correct IP but `curl` returns 404

**Solutions**:

1. Verify ingress rules:
   ```bash
   kubectl get ingress homarr -n homarr -o yaml
   ```

2. Check ingress controller logs:
   ```bash
   # For nginx-ingress
   kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
   ```

3. Test service connectivity directly:
   ```bash
   kubectl port-forward -n homarr svc/homarr 7575:7575
   curl http://localhost:7575
   ```

## Performance Optimization

### Resource Limits

Current resource limits:
- **CPU Limit**: 500m
- **Memory Limit**: 512Mi

If Homarr is slow, increase limits:

```bash
kubectl set resources deployment homarr -n homarr \
  --limits=cpu=1000m,memory=1Gi \
  --requests=cpu=500m,memory=512Mi
```

### Caching

Homarr caches application data locally. If services are slow to appear:

1. Refresh the browser cache (Ctrl+Shift+Delete)
2. Restart the Homarr pod:
   ```bash
   kubectl rollout restart deployment homarr -n homarr
   ```

## References

- [Homarr Official Documentation](https://homarr.dev/)
- [Homarr GitHub Repository](https://github.com/ajnart/homarr)
- [Homarr Setup Guide](../guides/homarr-setup.md)
- [Kubernetes Ingress Documentation](https://kubernetes.io/docs/concepts/services-networking/ingress/)
