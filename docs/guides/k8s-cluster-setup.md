# Setting Up a Kubernetes Cluster in Homelab

This guide provides a high-level overview of setting up a Kubernetes cluster in a homelab environment using k3s.
This covers the essential steps from node preparation to having a fully functional cluster with container registry
capabilities.

## Overview

Our homelab k8s cluster setup consists of:

- **Multiple Ubuntu nodes** (control plane + workers)
- **k3s Kubernetes distribution** (lightweight and homelab-friendly)
- **Harbor container registry** (for storing and managing Docker images)
- **Basic networking** configuration

## Prerequisites

- Multiple physical or virtual machines for cluster nodes
- Basic networking setup (nodes can communicate with each other)
- SSH access to all nodes
- Internet connectivity for downloading packages

## Step 1: Node Preparation

### 1.1 Install Ubuntu

On each node that will be part of your cluster:

1. **Install Ubuntu Server** (20.04 LTS or newer recommended)
   - Use a clean, minimal installation
   - Configure static IP addresses for consistency
   - Set up SSH access for remote management

2. **Basic Node Configuration**:

   ```bash
   # Update system packages
   sudo apt update && sudo apt upgrade -y

   # Install basic utilities
   sudo apt install curl wget htop -y

   # Configure hostnames (optional but recommended)
   sudo hostnamectl set-hostname <node-name>
   # Example: dell-01, nuc-01, etc.
   ```

3. **Verify Node Connectivity**:

   ```bash
   # Test connectivity between nodes
   ping <other-node-ip>

   # Verify SSH access works from your management machine
   ssh user@<node-ip>
   ```

## Step 2: Install and Configure k3s

### 2.1 Install k3s on Control Plane (Master)

On your designated master node:

```bash
# Install k3s server (control plane)
curl -sfL https://get.k3s.io | sh -

# Get the node token for workers
sudo cat /var/lib/rancher/k3s/server/node-token

# Verify installation
sudo kubectl get nodes
```

### 2.2 Join Worker Nodes

On each worker node:

```bash
# Install k3s agent (replace with your master node IP and token)
curl -sfL https://get.k3s.io | K3S_URL=https://<MASTER_IP>:6443 K3S_TOKEN=<NODE_TOKEN> sh -
```

### 2.3 Configure kubectl Access

On your local machine or management node:

```bash
# Copy kubeconfig from master node
scp user@<master-ip>:/etc/rancher/k3s/k3s.yaml ~/.kube/config

# Update server IP in config
sed -i 's/127.0.0.1/<master-ip>/g' ~/.kube/config

# Verify cluster access
kubectl get nodes
```

### 2.4 Verify Cluster

```bash
# Check all nodes are ready
kubectl get nodes -o wide

# Check system pods
kubectl get pods -n kube-system

# Verify cluster info
kubectl cluster-info
```

Expected output should show all nodes in "Ready" status.

!!! note
    This is a basic k3s setup. For detailed configuration options, security hardening, and advanced networking,
    a separate detailed guide will be created.

## Step 3: Container Registry Setup

### 3.1 Why Harbor?

With your k8s cluster running, you need a place to store your custom Docker images. Harbor provides:

- **Private container registry** for your homelab images
- **Web-based management** interface
- **Security scanning** and access controls
- **Integration with Kubernetes**

### 3.2 Harbor Deployment

For complete Harbor installation and configuration instructions, follow the **[Harbor & K8s Deployment Guide](harbor-k8s-deployment.md)**.

This guide covers:

- Harbor installation on your k8s cluster
- Configuring Docker and Kubernetes to work with Harbor
- Building and pushing images to Harbor
- Deploying applications from Harbor registry

### 3.3 Important: HTTP Registry Configuration

⚠️ **Critical Step**: After setting up Harbor, you must configure all k8s nodes to work with Harbor's HTTP
registry. Follow the [K8s Harbor HTTP Registry Setup Guide](k8s-harbor-http-registry.md) to avoid
`ImagePullBackOff` errors.

## Step 4: Verification and Testing

### 4.1 Test Basic Functionality

```bash
# Create a test namespace
kubectl create namespace test-namespace

# Deploy a simple application
kubectl create deployment nginx-test --image=nginx -n test-namespace

# Verify deployment
kubectl get pods -n test-namespace

# Clean up
kubectl delete namespace test-namespace
```

### 4.2 Test Harbor Integration

Once Harbor is configured, deploy a real image from your registry to confirm the full
Harbor → k8s pull path works end-to-end. The example below uses the `fast-api-docker` image
already in Harbor at
[`library/fast-api-docker`](http://192.168.1.206:30002/harbor/projects/1/repositories/fast-api-docker/artifacts-tab).

The Service uses `NodePort` so the app is reachable on every node IP at a high port, which is
all that's needed to verify Harbor itself is working:

```yaml title="fast-api-test.yaml"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fast-api-docker
  namespace: test-namespace
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
        - name: harbor-secret
      containers:
        - name: fast-api-docker
          image: 192.168.1.206:30002/library/fast-api-docker:latest
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: fast-api-docker-service
  namespace: test-namespace
spec:
  type: NodePort
  selector:
    app: fast-api-docker
  ports:
    - name: http
      port: 80
      targetPort: 80
```

Apply and verify:

```bash
kubectl apply -f fast-api-test.yaml
kubectl get pods,svc -n test-namespace
```

The app is now reachable on the assigned NodePort, e.g. `http://192.168.1.206:<node-port>`
(read the port from the `PORT(S)` column of `kubectl get svc`). FastAPI's auto-generated docs
are at `/docs`.

!!! tip "Reach the app by hostname instead of IP:port"
    NodePort access is enough to confirm Harbor is working, but for day-to-day use you'll want
    a clean URL like `http://fast-api.dev.lan` with no port number. See **Configure Ingress**
    in *Common Post-Setup Tasks* below to expose this same Deployment through Traefik.

!!! tip "NodePort vs Ingress"
    Both access paths coexist — adding the Ingress doesn't remove the NodePort. Once Ingress
    is working you can switch the Service `type` from `NodePort` to `ClusterIP` to drop the
    now-unused NodePort.

## Cluster Architecture

Your completed cluster should look like this:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Control Plane │    │   Worker Node   │    │   Worker Node   │
│    (dell-01)    │    │    (nuc-01)     │    │    (node-03)    │
│  192.168.1.208  │    │  192.168.1.206  │    │  192.168.1.xxx  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │  Harbor Registry │
                    │ 192.168.1.206:30002 │
                    └─────────────────┘
```

## Common Post-Setup Tasks

### 4.1 Install Additional Tools

```bash
# Install Helm (package manager for Kubernetes)
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install kubectl bash completion
kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl
```

### 4.2 Configure Ingress

For production-like deployments, expose your apps through an **ingress controller** so they're
reachable by hostname (e.g. `http://fast-api.dev.lan`) instead of by IP and port. The
controller listens on a single LAN address and routes requests to the right Service based on
the `Host:` header in the incoming HTTP request.

#### Traefik (default in k3s)

k3s ships with **Traefik** preinstalled and exposed via its built-in service load balancer at
`192.168.1.206` / `192.168.1.208` on port 80. No separate install step is needed — verify it's
running:

```bash
kubectl get ingressclass
# NAME      CONTROLLER                      AGE
# traefik   traefik.io/ingress-controller   ...

kubectl get svc -n kube-system traefik
# TYPE           EXTERNAL-IP                   PORT(S)
# LoadBalancer   192.168.1.206,192.168.1.208   80:32103/TCP,443:32192/TCP
```

#### Add an Ingress for the Test App

Building on the `fast-api-docker` Deployment from *Test Harbor Integration* above, create an
`Ingress` that maps a hostname to its Service:

```yaml title="fast-api-ingress.yaml"
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: fast-api
  namespace: test-namespace
spec:
  ingressClassName: traefik
  rules:
    - host: fast-api.dev.lan
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: fast-api-docker-service
                port:
                  number: 80
```

```bash
kubectl apply -f fast-api-ingress.yaml
kubectl get ingress -n test-namespace
# NAME       CLASS     HOSTS              ADDRESS                       PORTS
# fast-api   traefik   fast-api.dev.lan   192.168.1.206,192.168.1.208   80
```

#### Resolve the Hostname

Until a LAN-wide DNS server is set up, add a temporary entry to `/etc/hosts` on each client
machine that needs access:

```text
192.168.1.206  fast-api.dev.lan
```

Then visit `http://fast-api.dev.lan` (FastAPI's docs at `/docs`). The request flows:
browser → Traefik on port 80 → matches the `Host:` header → forwards to
`fast-api-docker-service:80` → pod.

For a permanent solution that covers `*.dev.lan` for every device on the LAN — without
per-host edits — see the [Pi-hole Local DNS Setup](pi-hole-setup.md) guide.

!!! tip "NodePort vs Ingress"
    Both access paths coexist — adding the Ingress doesn't remove the NodePort. Once Ingress
    is working you can switch the Service `type` from `NodePort` to `ClusterIP` to drop the
    now-unused NodePort.

#### Alternative Ingress Controllers

Traefik covers most homelab needs, but other options exist:

- **Nginx Ingress Controller** — broader feature set and middleware ecosystem; useful if you
  outgrow Traefik's defaults.
- **Cloudflare Tunnel** — exposes services to the public internet without opening ports on
  your router; a fit for remote access without a VPN.

### 4.3 Monitoring Setup (To be added)

Consider adding monitoring to your cluster:

- Prometheus for metrics collection
- Grafana for visualization
- Kubernetes Dashboard for web UI

## Troubleshooting

### Node Issues

- **Nodes not joining**: Check firewall settings and node token
- **Network connectivity**: Verify nodes can reach each other on required ports
- **Service status**: Check k3s service status with `systemctl status k3s`

### Application Deployment Issues

- **ImagePullBackOff**: Usually related to Harbor HTTP registry configuration
- **Scheduling issues**: Check node resources and taints
- **Networking problems**: Verify service and ingress configurations

For detailed troubleshooting of Harbor-related issues, see the [K8s Harbor HTTP Registry Troubleshooting Guide](../troubleshooting/k8s-harbor-http-registry.md).

## Next Steps

1. **Detailed k3s Configuration**: Create advanced configuration guide
2. **Security Hardening**: Implement security best practices
3. **Backup Strategy**: Set up cluster and data backup procedures
4. **CI/CD Integration**: Connect with GitLab/GitHub Actions
5. **Monitoring Setup**: Deploy Prometheus and Grafana
6. **Ingress Configuration**: Set up proper ingress for external access

## Summary

This guide covered the essential steps to set up a functional k8s homelab cluster:

1. ✅ **Node Preparation**: Ubuntu installation and basic configuration
2. ✅ **k3s Installation**: Control plane and worker node setup
3. ✅ **Harbor Registry**: Container image storage and management
4. ✅ **Verification**: Testing cluster functionality

Your cluster is now ready for deploying applications and experimenting with Kubernetes features!

## Related Guides

- [Harbor & K8s Deployment Guide](harbor-k8s-deployment.md) - Complete Harbor setup
- [K8s Harbor HTTP Registry Setup](k8s-harbor-http-registry.md) - HTTP registry configuration
- [Harbor Service Documentation](../services/harbor.md) - Harbor service overview
