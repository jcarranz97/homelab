# Harbor, Docker & Kubernetes Deployment Guide

This document provides a comprehensive guide for building, pushing to Harbor registry,
and deploying the FastAPI application to a Kubernetes cluster.

## Prerequisites

- Docker installed and running
- Kubernetes cluster access (kubectl configured)
- Harbor registry running at `http://192.168.1.206:30002/`
- Harbor user account with push/pull permissions

## Application Overview

This is a simple FastAPI application with the following endpoints:

- `GET /` - Returns a welcome message
- `GET /items/{item_id}` - Returns item information with optional query parameter

## 1. Harbor Registry Setup

### 1.1 Login to Harbor

First, log in to your Harbor registry using Docker:

```bash
docker login 192.168.1.206:30002
```

You'll be prompted for your Harbor username and password.

### 1.2 Create a Project in Harbor

1. Open Harbor web interface: <http://192.168.1.206:30002/>
2. Login with your credentials
3. Create a new project (e.g., `fastapi-apps` or `learning-projects`)
4. Make note of the project name - you'll need it for image tagging

## 2. Build and Push Docker Image

### 2.1 Build the Docker Image

Build the image with proper Harbor registry tagging:

```bash
# Replace 'your-project' with your actual Harbor project name
docker build -t 192.168.1.206:30002/library/fast-api-docker:latest .
```

### 2.2 Tag Image (if needed)

If you built with a different tag initially, retag it:

```bash
docker tag fast-api-docker:latest 192.168.1.206:30002/library/fast-api-docker:latest
```

### 2.3 Push to Harbor Registry

```bash
docker push 192.168.1.206:30002/library/fast-api-docker:latest
```

### 2.4 Verify Image in Harbor

1. Go to Harbor web interface
2. Navigate to your project
3. Verify the `fast-api-docker` repository is created
4. Check that the `latest` tag is available

## 3. Kubernetes Deployment

> **⚠️ Important**: Before deploying to Kubernetes, ensure your cluster is configured to work with
> Harbor's HTTP registry. If you encounter `ImagePullBackOff` or HTTPS client errors, follow the
> [K8s Harbor HTTP Registry Setup Guide](k8s-harbor-http-registry.md) to configure all cluster nodes properly.

### 3.1 Create Harbor Secret for Kubernetes

Create a secret to allow Kubernetes to pull images from Harbor:

```bash
kubectl create secret docker-registry harbor-secret \
  --docker-server=192.168.1.206:30002 \
  --docker-username=<harbor-username> \
  --docker-password=<harbor-password> \
  --namespace=test-namespace
```

### 3.2 Update Deployment and Service Configuration

Update the deployment YAML to use your Harbor image. The current configuration
should be modified to use Harbor instead of ghcr.io:

**Deployment configuration**:

```yaml title="fast-api-docker-deployment.yaml"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fast-api-docker
  namespace: test-namespace
  labels:
    app: fast-api-docker
spec:
  replicas: 1
  selector:
    matchLabels:
      app: fast-api-docker
  template:
    metadata:
      labels:
        app: fast-api-docker
    spec:
      imagePullSecrets:
      - name: harbor-secret  # Updated secret name
      containers:
      - name: fast-api-docker
        image: 192.168.1.206:30002/library/fast-api-docker:latest  # Updated image
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
```

**Service configuration**:

```yaml title="fast-api-docker-service.yaml"
apiVersion: v1
kind: Service
metadata:
  name: fast-api-docker-service
  namespace: test-namespace
  labels:
    app: fast-api-docker
spec:
  type: NodePort
  selector:
    app: fast-api-docker
  ports:
    - name: http
      port: 80
      targetPort: 80
      protocol: TCP
```

### 3.3 Deploy to Kubernetes

Apply the deployment and service configurations:

```bash
# Deploy the application
kubectl apply -f fast-api-docker-deployment.yaml

# Create the service
kubectl apply -f fast-api-docker-service.yaml
```

### 3.4 Verify Deployment

Check deployment status:

```bash
# Check deployment status
kubectl get deployments -n test-namespace

# Check pods
kubectl get pods -n test-namespace -l app=fast-api-docker

# Check services
kubectl get services -n test-namespace

# Get detailed pod information
kubectl describe deployment fast-api-docker -n test-namespace
```

### 3.5 Access the Application

Since the service is configured as NodePort, find the assigned port:

```bash
kubectl get service fast-api-docker-service -n test-namespace
```

Access your application:

- If running on a cluster node: `http://<node-ip>:<nodeport>`
- Test the API endpoints:
  - `curl http://<node-ip>:<nodeport>/`
  - `curl http://<node-ip>:<nodeport>/items/42?q=test`

## 4. Development Workflow

### 4.1 Making Changes and Redeploying

When you make changes to your application:

1. **Rebuild the image** with a new tag:

   ```bash
   docker build -t 192.168.1.206:30002/your-project/fast-api-docker:v1.1 .
   ```

2. **Push the new version**:

   ```bash
   docker push 192.168.1.206:30002/your-project/fast-api-docker:v1.1
   ```

3. **Update the deployment**:

   ```bash
   kubectl set image deployment/fast-api-docker fast-api-docker=192.168.1.206:30002/your-project/fast-api-docker:v1.1 -n test-namespace
   ```

4. **Check rollout status**:

   ```bash
   kubectl rollout status deployment/fast-api-docker -n test-namespace
   ```

### 4.2 Rolling Back

If you need to rollback to a previous version:

```bash
# View rollout history
kubectl rollout history deployment/fast-api-docker -n test-namespace

# Rollback to previous version
kubectl rollout undo deployment/fast-api-docker -n test-namespace
```

## 5. Troubleshooting

### 5.1 Common Issues

**For detailed troubleshooting of Harbor HTTP registry issues**, see the [K8s Harbor HTTP Registry Troubleshooting Guide](../troubleshooting/k8s-harbor-http-registry.md).

**Image Pull Errors:**

- **HTTP/HTTPS client errors**: Follow the
  [K8s Harbor HTTP Registry Setup Guide](k8s-harbor-http-registry.md) to configure cluster nodes
- Verify Harbor credentials are correct
- Check if the secret `harbor-secret` exists in the correct namespace
- Ensure the image path is correct in the deployment YAML

**Pod Not Starting:**

- Check pod logs: `kubectl logs <pod-name> -n test-namespace`
- Verify resource requirements are appropriate
- Check if the container port (80) matches your application

**Service Not Accessible:**

- Verify the service selector matches deployment labels
- Check if the target port matches container port
- Confirm NodePort service is created properly

### 5.2 Useful Commands

```bash
# View pod logs
kubectl logs -f deployment/fast-api-docker -n test-namespace

# Get into pod shell for debugging
kubectl exec -it <pod-name> -n test-namespace -- /bin/bash

# Port forward for local testing
kubectl port-forward service/fast-api-docker-service 8080:80 -n test-namespace

# Delete deployment (for clean restart)
kubectl delete -f fast-api-docker-deployment.yaml
kubectl delete -f fast-api-docker-service.yaml
```

## 6. Harbor Best Practices

1. **Use specific tags** instead of `latest` for production deployments
2. **Enable vulnerability scanning** in Harbor for security
3. **Set up image retention policies** to manage storage
4. **Use Harbor projects** to organize different applications
5. **Configure Harbor replication** for backup and disaster recovery

## 7. Next Steps

1. **Set up CI/CD Pipeline**: Automate the build and deployment process
2. **Configure Ingress**: Use Ingress controller instead of NodePort for production
3. **Add Monitoring**: Implement monitoring with Prometheus and Grafana
4. **Security Hardening**: Implement security policies and network policies
5. **Resource Management**: Fine-tune resource requests and limits

---

## Summary

This workflow demonstrates:

- Building Docker images for a FastAPI application
- Pushing images to Harbor registry
- Deploying to Kubernetes using Deployments and Services
- Managing application updates and rollbacks

The setup provides a solid foundation for learning container orchestration with Kubernetes
and container registry management with Harbor.
