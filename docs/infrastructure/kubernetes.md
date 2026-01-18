# Kubernetes Cluster

This page documents the Kubernetes cluster configuration and setup details.

## Cluster Information

### Basic Details

- **Kubernetes Version**: [e.g., v1.28.2]
- **Distribution**: [e.g., kubeadm, k3s, microk8s]
- **Container Runtime**: [e.g., containerd, Docker]
- **CNI Plugin**: [e.g., Flannel, Calico, Cilium]
- **Installation Date**: [When cluster was set up]

### Cluster Nodes

- **Master Nodes**: 1
- **Worker Nodes**: [Number of worker nodes]
- **Total Nodes**: [Total number of nodes]

```bash
# Check cluster info
kubectl cluster-info

# List all nodes
kubectl get nodes -o wide
```

## Control Plane Configuration

### Master Node Components

- **API Server**: Kubernetes API endpoint
- **etcd**: Cluster state storage
- **Controller Manager**: Core control loops
- **Scheduler**: Pod scheduling decisions

### Configuration Files

- **kubeconfig**: `~/.kube/config`
- **Admin config**: `/etc/kubernetes/admin.conf`
- **kubelet config**: `/etc/kubernetes/kubelet.conf`

## Worker Node Configuration

### Node Components

- **kubelet**: Node agent
- **kube-proxy**: Network proxy
- **Container Runtime**: Container execution

### Node Labels and Taints

```bash
# View node labels
kubectl get nodes --show-labels

# Add custom labels
kubectl label nodes <node-name> role=worker

# Check taints
kubectl describe nodes | grep Taints
```

## Network Configuration

### Pod and Service Networks

- **Pod CIDR**: [e.g., 10.244.0.0/16]
- **Service CIDR**: [e.g., 10.96.0.0/12]
- **DNS Domain**: cluster.local

### CNI Configuration

```yaml
# Example CNI configuration (varies by plugin)
apiVersion: v1
kind: ConfigMap
metadata:
  name: kube-flannel-cfg
  namespace: kube-system
data:
  cni-conf.json: |
    {
      "name": "cbr0",
      "cniVersion": "0.3.1",
      "plugins": [
        {
          "type": "flannel",
          "delegate": {
            "hairpinMode": true,
            "isDefaultGateway": true
          }
        },
        {
          "type": "portmap",
          "capabilities": {
            "portMappings": true
          }
        }
      ]
    }
  net-conf.json: |
    {
      "Network": "10.244.0.0/16",
      "Backend": {
        "Type": "vxlan"
      }
    }
```

## Storage Configuration

### Storage Classes

```bash
# List storage classes
kubectl get storageclass

# Default storage class
kubectl get storageclass -o yaml
```

### Example Local Storage Class

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
```

## Security Configuration

### RBAC Settings

```bash
# Check cluster roles
kubectl get clusterroles

# Check service accounts
kubectl get serviceaccounts --all-namespaces

# View RBAC permissions
kubectl auth can-i --list
```

### Pod Security Standards

```yaml
# Example pod security policy
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: homelab-psp
spec:
  privileged: false
  allowPrivilegeEscalation: false
  requiredDropCapabilities:
    - ALL
  volumes:
    - 'configMap'
    - 'emptyDir'
    - 'projected'
    - 'secret'
    - 'downwardAPI'
    - 'persistentVolumeClaim'
  runAsUser:
    rule: 'MustRunAsNonRoot'
  seLinux:
    rule: 'RunAsAny'
  fsGroup:
    rule: 'RunAsAny'
```

## Namespaces

### System Namespaces

- **kube-system**: Kubernetes system components
- **kube-public**: Publicly readable cluster info
- **kube-node-lease**: Node heartbeat information

### Application Namespaces

- **default**: Default application namespace
- **test-namespace**: Testing and development
- **monitoring**: Monitoring stack (if deployed)

```bash
# List all namespaces
kubectl get namespaces

# Create new namespace
kubectl create namespace my-app
```

## Resource Management

### Node Resources

```bash
# Check node resource usage
kubectl top nodes

# Describe node resources
kubectl describe node <node-name>
```

### Cluster Resource Quotas

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: test-namespace
spec:
  hard:
    requests.cpu: "2"
    requests.memory: 4Gi
    limits.cpu: "4"
    limits.memory: 8Gi
    pods: "10"
```

### Limit Ranges

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: test-namespace
spec:
  limits:
  - default:
      cpu: 100m
      memory: 128Mi
    defaultRequest:
      cpu: 50m
      memory: 64Mi
    type: Container
```

## Monitoring and Logging

### Cluster Health Checks

```bash
# Check component status
kubectl get componentstatuses

# Check cluster events
kubectl get events --sort-by=.metadata.creationTimestamp

# Check pod logs across cluster
kubectl logs --all-containers=true --tail=100 -l app=my-app
```

### Metrics Collection

- **Metrics Server**: Resource metrics API
- **cAdvisor**: Container metrics (built into kubelet)
- **Prometheus**: (If deployed) Advanced metrics collection

## Backup and Recovery

### etcd Backup

```bash
# Backup etcd (example for kubeadm cluster)
sudo ETCDCTL_API=3 etcdctl snapshot save /backup/etcd-snapshot.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

### Configuration Backup

```bash
# Backup all cluster configurations
kubectl get all --all-namespaces -o yaml > cluster-backup.yaml

# Backup specific resources
kubectl get configmaps,secrets --all-namespaces -o yaml > configs-backup.yaml
```

## Maintenance Tasks

### Regular Maintenance

- **Weekly**: Check cluster health and resource usage
- **Monthly**: Update and patch nodes
- **Quarterly**: Kubernetes version upgrades

### Upgrade Process

```bash
# Check upgrade options
kubeadm upgrade plan

# Upgrade control plane
sudo kubeadm upgrade apply v1.28.x

# Upgrade kubelet on nodes
sudo apt update && sudo apt install -y kubelet=1.28.x-00
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

## Troubleshooting

### Common Issues

#### Node Not Ready

```bash
# Check node status
kubectl describe node <node-name>

# Check kubelet logs
sudo journalctl -u kubelet -f

# Restart kubelet
sudo systemctl restart kubelet
```

#### Pod Scheduling Issues

```bash
# Check scheduler logs
kubectl logs -n kube-system kube-scheduler-<master-node>

# Check node resources
kubectl describe nodes

# Check pod events
kubectl describe pod <pod-name>
```

#### Network Issues

```bash
# Check CNI pods
kubectl get pods -n kube-system -l app=flannel

# Test pod-to-pod connectivity
kubectl run test-pod --image=busybox --rm -it -- ping <pod-ip>
```

## Performance Tuning

### Node Optimization

- **CPU**: Adjust CPU management policies
- **Memory**: Configure memory limits appropriately
- **I/O**: Optimize storage performance

### Cluster Settings

```yaml
# Example kubelet configuration
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
maxPods: 110
podPidsLimit: 2048
evictionHard:
  memory.available: "100Mi"
  nodefs.available: "10%"
```

## Future Plans

### Planned Upgrades

- [ ] [Kubernetes version upgrades]
- [ ] [Add-on installations]
- [ ] [Security enhancements]

### Scaling Considerations

- [ ] [Additional worker nodes]
- [ ] [High availability setup]
- [ ] [Multi-zone deployment]

---

*Keep this document updated when making cluster configuration changes.*
