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

Once Harbor is configured:

```bash
# Test pulling from Harbor registry
kubectl create deployment test-harbor --image=192.168.1.206:30002/library/your-app:latest -n test-namespace
```

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

### 4.2 Configure Ingress (To be added)

For production-like deployments, consider setting up an ingress controller:

- Traefik (comes with k3s by default)
- Nginx Ingress Controller
- Cloudflare Tunnel integration

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
