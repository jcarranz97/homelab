# How to Configure K8s Cluster Nodes for Harbor HTTP Registry

This guide explains how to configure all Kubernetes cluster nodes to pull images from a local Harbor registry
running on HTTP (non-HTTPS).

## Problem Overview

By default, both Docker and Kubernetes expect container registries to use HTTPS. When using a local Harbor
registry with HTTP (common in homelab environments), you'll encounter errors like:

```
http: server gave HTTP response to HTTPS client
```

This guide provides the solution to configure your k3s cluster to work with HTTP registries.

## Prerequisites

- k3s cluster with control plane and worker nodes
- Harbor registry running on HTTP (e.g., `192.168.1.206:30002`)
- SSH access to all cluster nodes
- Root/sudo access on cluster nodes

## Solution Overview

You need to configure **every node** in your k3s cluster (both control plane and worker nodes) to allow HTTP
connections to your Harbor registry.

## Step-by-Step Configuration

### Step 1: Identify Your Cluster Nodes

First, identify all nodes in your cluster:

```bash
kubectl get nodes -o wide
```

Example output:

```
NAME      STATUS   ROLES                       AGE   VERSION        INTERNAL-IP     EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
dell-01   Ready    control-plane,master        10d   v1.33.4+k3s1   192.168.1.208   <none>        Ubuntu 20.04.3 LTS   5.4.0-91-generic    containerd://1.7.21-k3s2
nuc-01    Ready    <none>                      10d   v1.33.4+k3s1   192.168.1.206   <none>        Ubuntu 20.04.3 LTS   5.4.0-91-generic    containerd://1.7.21-k3s2
```

### Step 2: Configure Each Node

**You must repeat this process on EVERY node in your cluster.**

#### SSH into each node

```bash
# For control plane node
ssh root@192.168.1.208  # dell-01

# For worker nodes
ssh root@192.168.1.206  # nuc-01
```

#### Create the registries configuration

On **each node**, create the registries configuration file:

```bash
# Create the directory if it doesn't exist
mkdir -p /etc/rancher/k3s

# Create/edit the registries.yaml file
nano /etc/rancher/k3s/registries.yaml
```

#### Add the following content

```yaml
mirrors:
  "192.168.1.206:30002":
    endpoint:
      - "http://192.168.1.206:30002"
configs:
  "192.168.1.206:30002":
    tls:
      insecure_skip_verify: true
```

**Important**: Replace `192.168.1.206:30002` with your Harbor registry's actual IP and port.

#### Save the file

- In nano: Press `Ctrl+X`, then `Y`, then `Enter`
- In vim: Press `Esc`, type `:wq`, press `Enter`

### Step 3: Restart k3s Services

The service name differs between control plane and worker nodes:

#### On Control Plane (Master) Nodes

```bash
# Check if it's the control plane service
systemctl list-units --type=service | grep k3s

# If you see 'k3s.service':
systemctl restart k3s

# Verify it's running
systemctl status k3s
```

#### On Worker Nodes

```bash
# Check if it's a worker node service
systemctl list-units --type=service | grep k3s

# If you see 'k3s-agent.service':
systemctl restart k3s-agent

# Verify it's running
systemctl status k3s-agent
```

### Step 4: Verify Configuration

After configuring all nodes, verify the cluster is healthy:

```bash
# Check all nodes are ready
kubectl get nodes

# Check k3s can access the registry by testing a deployment
kubectl create deployment test-harbor --image=192.168.1.206:30002/library/your-image:latest -n test-namespace
```

## Configuration File Explanation

```yaml
mirrors:
  "192.168.1.206:30002":           # Your Harbor registry address
    endpoint:
      - "http://192.168.1.206:30002" # Force HTTP protocol

configs:
  "192.168.1.206:30002":           # Same registry address
    tls:
      insecure_skip_verify: true    # Allow insecure connections
```

- **mirrors**: Defines registry endpoints
- **endpoint**: Specifies the HTTP URL (not HTTPS)
- **insecure_skip_verify**: Allows connections without TLS verification

## Common Node Configurations

### Single Node Cluster

- Configure the single node with both `mirrors` and `configs`
- Restart the appropriate k3s service

### Multi-Node Cluster

- **Control Plane**: Usually runs `k3s.service`
- **Worker Nodes**: Usually run `k3s-agent.service`
- **All nodes** need the same `registries.yaml` configuration

## Troubleshooting

For detailed troubleshooting steps and solutions to common issues, see the dedicated
[K8s Harbor HTTP Registry Troubleshooting Guide](../troubleshooting/k8s-harbor-http-registry.md).

### Quick Verification

```bash
# Check node configuration
cat /etc/rancher/k3s/registries.yaml

# Check k3s service status
systemctl status k3s        # or k3s-agent

# Test registry connectivity
curl http://192.168.1.206:30002/v2/
```

## Security Considerations

### For Homelab Use

- HTTP registries are acceptable for internal/homelab environments
- Ensure your network is properly segmented
- Use Harbor's built-in authentication

### For Production

- **Do not use HTTP registries in production**
- Configure Harbor with proper SSL certificates
- Use network policies to restrict access

## Alternative: HTTPS Setup

For production environments, consider setting up Harbor with HTTPS:

1. **Generate SSL certificates** (Let's Encrypt or self-signed)
2. **Configure Harbor** with SSL termination
3. **Update k3s configuration** to use HTTPS endpoints
4. **Install certificates** on all nodes if using self-signed

## Summary

This configuration allows your k3s cluster to pull images from a local Harbor HTTP registry by:

1. **Creating `/etc/rancher/k3s/registries.yaml`** on all nodes
2. **Configuring HTTP endpoints** with `insecure_skip_verify`
3. **Restarting k3s services** to apply changes
4. **Verifying** the configuration works

Remember: This configuration must be applied to **every node** in your cluster for consistent image pulling across all pods.
