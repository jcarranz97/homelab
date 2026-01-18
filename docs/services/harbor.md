# Harbor Container Registry

Harbor is a private container registry that provides image storage, vulnerability scanning, and access control for your homelab.

## Overview

- **URL**: <http://192.168.1.206:30002/>
- **Version**: [Add Harbor version]
- **Access**: Web UI and Docker CLI
- **Features**:
  - Private image repositories
  - Vulnerability scanning
  - Access control and RBAC
  - Image replication
  - Webhook notifications

## Access Information

### Web Interface

- **URL**: <http://192.168.1.206:30002/>
- **Default Admin**: admin
- **Login**: Use your configured credentials

### Docker CLI Access

```bash
# Login to Harbor registry
docker login 192.168.1.206:30002

# Build and tag images
docker build -t 192.168.1.206:30002/project-name/app-name:tag .

# Push images
docker push 192.168.1.206:30002/project-name/app-name:tag
```

## Projects

Current projects in Harbor:

| Project Name | Purpose | Access Level |
|-------------|---------|--------------|
| learning-projects | Educational deployments | Private |
| fastapi-apps | FastAPI applications | Private |

## Best Practices

### Image Tagging

- Use semantic versioning: `v1.0.0`, `v1.1.0`
- Avoid `latest` tag in production
- Use descriptive tags: `feature-branch-name`

### Security

- Enable vulnerability scanning
- Set up image retention policies
- Use project-specific access controls

## Integration with Kubernetes

Harbor integrates with Kubernetes through:

1. **Image Pull Secrets**: For private repository access
2. **Admission Controllers**: For image policy enforcement
3. **Webhooks**: For automated deployment triggers

### Creating Pull Secrets

```bash
kubectl create secret docker-registry harbor-secret \
  --docker-server=192.168.1.206:30002 \
  --docker-username=<username> \
  --docker-password=<password> \
  --namespace=<target-namespace>
```

## Troubleshooting

### Common Issues

- **Login failures**: Check credentials and network connectivity
- **Push failures**: Verify project exists and you have push permissions
- **Pull failures in K8s**: Ensure pull secrets are properly configured

## References

- [Harbor Documentation](https://goharbor.io/docs/)
- [Harbor & K8s Deployment Guide](../guides/harbor-k8s-deployment.md)
