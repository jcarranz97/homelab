# Homarr Landing Page Setup

## Overview

Homarr is a self-hosted, modern homelab landing page that provides a centralized dashboard for all your homelab applications. This guide will walk you through deploying Homarr on your Kubernetes cluster with Ingress support to access it via `home.dev.lan`.

## Prerequisites

- Kubernetes cluster up and running
- Helm 3.x installed
- Ingress controller deployed (nginx-ingress or similar)
- DNS configured to resolve `home.dev.lan` to your Ingress IP

## Architecture

```
┌──────────────────────┐
│   home.dev.lan       │
│   (Ingress)          │
└──────────┬───────────┘
           │
     ┌─────▼──────┐
     │ K8s Ingress│
     └─────┬──────┘
           │
     ┌─────▼────────────┐
     │ homarr Service   │
     │ ClusterIP:7575   │
     └─────┬────────────┘
           │
     ┌─────▼────────────┐
     │ homarr Pod       │
     │ Namespace: homarr│
     └──────────────────┘
```

## Important Note

✅ **Official Homarr Helm Repository**: This guide uses the official Homarr Helm chart from `homarr-labs` at `https://homarr-labs.github.io/charts/`. This is the recommended installation method by the Homarr team.

## Step 1: Create Namespace

Create a dedicated namespace for Homarr:

```bash
kubectl create namespace homarr
```

## Step 2: Add Official Homarr Helm Repository

Add the official Homarr Helm repository from homarr-labs:

```bash
helm repo add homarr-labs https://homarr-labs.github.io/charts/
helm repo update
```

## Step 3: Create the DB Encryption Secret

The Homarr chart (v8.x+) expects an existing Kubernetes secret named `db-encryption` containing the `db-encryption-key` used to encrypt the local SQLite database. The chart will **not** create it for you; if it's missing, the pod fails with `CreateContainerConfigError: secret "db-encryption" not found`.

Generate a 32-byte hex key and create the secret in the `homarr` namespace:

```bash
kubectl create secret generic db-encryption \
  --namespace homarr \
  --from-literal=db-encryption-key="$(openssl rand -hex 32)"
```

Store this key somewhere safe (password manager). If you lose it, you will not be able to decrypt existing Homarr data after a restore.

Verify the secret was created:

```bash
kubectl get secret db-encryption -n homarr
```

## Step 4: Install Homarr

Install Homarr using the official Helm chart with a single command:

```bash
helm install homarr homarr-labs/homarr \
  --namespace homarr \
  --set ingress.enabled=true \
  --set ingress.className=nginx \
  --set ingress.hosts[0].host=home.dev.lan \
  --set ingress.hosts[0].paths[0].path=/ \
  --set ingress.hosts[0].paths[0].pathType=Prefix \
  --set persistence.enabled=true \
  --set persistence.size=2Gi \
  --set persistence.storageClassName=standard
```

This single command will:
- Create the Homarr deployment
- Configure storage with 2Gi PersistentVolumeClaim
- Set up Ingress for `home.dev.lan`
- Enable persistence for your app data

## Step 5: Verify Deployment

Check that the pods are running:

```bash
kubectl get pods -n homarr
```

Expected output:

```
NAME                     READY   STATUS    RESTARTS   AGE
homarr-xxx-yyy           1/1     Running   0          2m
```

Check the Homarr service:

```bash
kubectl get svc -n homarr
```

Check that the Ingress resource was created (if configured via Helm):

```bash
kubectl get ingress -n homarr
```

Expected output:

```
NAME     CLASS   HOSTS          ADDRESS     PORTS   AGE
homarr   nginx   home.dev.lan   10.0.0.x    80      2m
```

Get the Ingress IP/address:

```bash
kubectl get ingress -n homarr -o wide
# Look at the ADDRESS column
```

## Step 6: Configure DNS

Add an entry to your DNS server (Pi-hole, CoreDNS, or `/etc/hosts`):

```
192.168.1.x  home.dev.lan
```

Replace `192.168.1.x` with your Ingress controller's IP address (from the ADDRESS column above).

For local testing, you can also add it to `/etc/hosts`:

```bash
echo "192.168.1.x  home.dev.lan" >> /etc/hosts
```

## Step 7: Access Homarr

Open your browser and navigate to:

```
http://home.dev.lan
```

You should see the Homarr dashboard. If you're unable to access it, ensure:
- DNS resolution is configured correctly
- The Ingress IP matches your cluster node IP
- The Homarr pod is running

## Step 8: Configure Your Applications

Once logged in to Homarr, you can add your homelab applications:

1. Click the **+** icon to add a new app
2. Fill in the details:
   - **Name**: Application name
   - **URL**: Application URL
   - **Icon**: Select an icon (optional)
   - **Category**: Organize by category (optional)

### Example Applications to Add

| Application | URL | Category |
|-------------|-----|----------|
| Rancher | http://rancher.local | Infrastructure |
| Harbor | http://harbor.dev.lan | Container Registry |
| Fast-API | http://fast-api.dev.lan | Development |
| Multica | http://multica.dev.lan | Tools |
| Colony | http://colony.dev.lan | Tools |

## Step 9: Upgrade Homarr

To upgrade to a newer version of Homarr:

```bash
# Update the Helm repository
helm repo update homarr-labs

# Upgrade the Homarr release
helm upgrade homarr homarr-labs/homarr \
  --namespace homarr \
  --values values.yaml  # If using a values file
```

Or without a values file:

```bash
helm upgrade homarr homarr-labs/homarr \
  --namespace homarr \
  --set ingress.enabled=true \
  --set ingress.className=nginx \
  --set ingress.hosts[0].host=home.dev.lan
```

## Step 10: Backup and Restore

### Backup

Backup your Homarr configuration:

```bash
# Get the pod name
POD_NAME=$(kubectl get pods -n homarr -l app=homarr -o jsonpath='{.items[0].metadata.name}')

# Create backup
kubectl exec -n homarr $POD_NAME -- tar czf /tmp/homarr-backup.tar.gz /app/data

# Copy backup to local machine
kubectl cp homarr/$POD_NAME:/tmp/homarr-backup.tar.gz ./homarr-backup.tar.gz
```

### Restore

Restore from backup:

```bash
# Get the pod name
POD_NAME=$(kubectl get pods -n homarr -l app=homarr -o jsonpath='{.items[0].metadata.name}')

# Copy backup to pod
kubectl cp ./homarr-backup.tar.gz homarr/$POD_NAME:/tmp/

# Restore from backup
kubectl exec -n homarr $POD_NAME -- tar xzf /tmp/homarr-backup.tar.gz -C /
```

## Troubleshooting

### Homarr not accessible via `home.dev.lan`

1. Verify DNS resolution:
   ```bash
   nslookup home.dev.lan
   ```

2. Check Ingress status:
   ```bash
   kubectl describe ingress homarr -n homarr
   ```

3. Verify Homarr pod is running:
   ```bash
   kubectl get pods -n homarr
   ```

### Pod stuck in `CreateContainerConfigError`

Check the pod events:

```bash
kubectl describe pod -n homarr -l app.kubernetes.io/name=homarr
```

If you see `Error: secret "db-encryption" not found`, you skipped [Step 3](#step-3-create-the-db-encryption-secret). Create the secret and the pod will pick it up automatically:

```bash
kubectl create secret generic db-encryption \
  --namespace homarr \
  --from-literal=db-encryption-key="$(openssl rand -hex 32)"
```

### Pod in CrashLoopBackOff

Check logs:

```bash
kubectl logs -n homarr deployment/homarr
```

### Storage issues

Verify the PVC is bound:

```bash
kubectl get pvc -n homarr
```

Should show `Bound` status. If not, check available storage:

```bash
kubectl get pv
```

## Optional: Enable HTTPS with TLS

If you have cert-manager installed in your cluster, you can enable HTTPS for Homarr:

### Step 1: Create a Certificate (if using cert-manager)

```bash
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: homarr-cert
  namespace: homarr
spec:
  secretName: homarr-tls
  issuerRef:
    name: letsencrypt-prod  # Adjust to your issuer name
    kind: ClusterIssuer
  dnsNames:
    - home.dev.lan
EOF
```

### Step 2: Update Ingress to use TLS

Update the Ingress resource:

```bash
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: homarr
  namespace: homarr
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - home.dev.lan
    secretName: homarr-tls
  rules:
  - host: home.dev.lan
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: homarr
            port:
              number: 7575
EOF
```

After certificate is issued, Homarr will be accessible at `https://home.dev.lan`.

## References

- [Homarr Official Documentation](https://homarr.dev/)
- [Homarr GitHub Repository](https://github.com/ajnart/homarr)
- [Kubernetes Ingress Documentation](https://kubernetes.io/docs/concepts/services-networking/ingress/)
