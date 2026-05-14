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

### Important: HTTP Registry Configuration

**Before deploying to Kubernetes**, you must configure all cluster nodes to allow HTTP connections to Harbor,
since the registry runs on HTTP (not HTTPS).

⚠️ **Required Step**: Follow the [K8s Harbor HTTP Registry Configuration Guide](../guides/k8s-harbor-http-registry.md)
to configure your cluster nodes. Without this configuration, pods will fail with `ImagePullBackOff` errors.

### Creating Pull Secrets

```bash
kubectl create secret docker-registry harbor-secret \
  --docker-server=192.168.1.206:30002 \
  --docker-username=<username> \
  --docker-password=<password> \
  --namespace=<target-namespace>
```

## Hostname Access via Ingress (`http://harbor.dev.lan`)

By default, Harbor in this homelab is reached via its NodePort at
`http://192.168.1.206:30002`. To expose it at a clean hostname like
`http://harbor.dev.lan` — the same pattern used by [Colony](https://github.com/jcarranz97/colony)
(`colony.dev.lan`, `api.colony.dev.lan`) — add a standalone Traefik Ingress
in front of Harbor's existing NodePort service. The Ingress and the NodePort
**coexist**: both URLs keep working, which makes the migration safe to do
gradually.

This setup uses the Harbor Helm release that's already running in the cluster
(release name `harbor`, namespace `harbor-system`). **You do not need to
re-install Harbor or have the chart locally** — the Ingress is a plain
Kubernetes manifest that targets Harbor's existing `harbor` Service.

### Assumptions

| Item | Value |
|---|---|
| Harbor namespace | `harbor-system` |
| Harbor Service name | `harbor` (NodePort, port 80 → targetPort 8080) |
| Helm release name | `harbor` |
| New hostname | `harbor.dev.lan` |
| Existing NodePort URL | `http://192.168.1.206:30002` (stays working) |
| Ingress controller | Traefik (ships with k3s) |
| Node IPs | `192.168.1.208` (control-plane), `192.168.1.206` (worker) |

Verify your release name and service before continuing:

```bash
helm list -n harbor-system
# NAME    NAMESPACE       REVISION  ...  CHART          APP VERSION
# harbor  harbor-system   1         ...  harbor-1.13.1  2.9.1

kubectl get svc -n harbor-system harbor
# NAME    TYPE       CLUSTER-IP    PORT(S)        AGE
# harbor  NodePort   10.43.72.54   80:30002/TCP   ...
```

### Step 1 — Create the Ingress

Harbor's front-facing `harbor` Service routes both the web UI **and** the
container registry API (`/v2/...`) through the same nginx pod, so a single
Ingress rule covering `/` is enough for both UI access and `docker push` /
`docker pull` traffic.

Save the following as `harbor-ingress.yaml`:

```yaml title="harbor-ingress.yaml"
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: harbor
  namespace: harbor-system
spec:
  ingressClassName: traefik
  rules:
    - host: harbor.dev.lan
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: harbor
                port:
                  number: 80
```

Apply it:

```bash
kubectl apply -f harbor-ingress.yaml

kubectl get ingress -n harbor-system
# NAME    CLASS     HOSTS            ADDRESS                       PORTS
# harbor  traefik   harbor.dev.lan   192.168.1.206,192.168.1.208   80
```

The `ADDRESS` column lists the IPs of every node running Traefik — those are
the IPs that `harbor.dev.lan` needs to resolve to.

> **Why no `client-max-body-size` annotation?** Traefik 3.x streams request
> bodies and does not impose a default body-size limit, so multi-GB image
> layer uploads through the Ingress work without extra configuration. (This
> is different from nginx-ingress, which defaults to `1m` and needs an
> override for registry traffic.)

### Step 2 — Resolve `harbor.dev.lan` to a node IP

Until LAN-wide DNS is in place, add a hosts entry on every machine that
needs access (including each k3s node — see Step 4):

```text
192.168.1.206  harbor.dev.lan
```

Linux/macOS: `/etc/hosts`. Windows: `C:\Windows\System32\drivers\etc\hosts`.

For a permanent solution across every device, see the
[Pi-hole Local DNS Setup](../guides/pi-hole-setup.md) guide and add a
`harbor.dev.lan` A-record (or a `*.dev.lan` wildcard that covers it).

Verify resolution and the UI:

```bash
getent hosts harbor.dev.lan   # → 192.168.1.206
curl -I http://harbor.dev.lan # → HTTP/1.1 200 OK
```

Open `http://harbor.dev.lan` in a browser — you should see the Harbor login
page. At this point the **UI works through the new hostname**, but
`docker login harbor.dev.lan` will not yet succeed because Harbor still
advertises the old URL in its token-auth challenge. Continue to Step 3 to
fix that.

### Step 3 — Update Harbor's `externalURL`

The Harbor registry uses **token-based authentication**: when a Docker
client hits `/v2/`, Harbor returns a `WWW-Authenticate` header pointing
the client at Harbor's token service. That URL is built from the chart's
`externalURL` value, which currently still points at the NodePort URL. As a
result, `docker login harbor.dev.lan` ends up trying to fetch a token from
`http://192.168.1.206:30002/service/token` — confusing and brittle.

Update `externalURL` so the token URLs match the hostname clients use.

#### 3a. Capture the current Helm values

```bash
helm get values harbor -n harbor-system > harbor-values.yaml
```

This pulls the existing user-supplied values from the release stored in
the cluster — you don't need the original chart files on disk to do this.

#### 3b. Add or change `externalURL`

Edit `harbor-values.yaml` and set:

```yaml
externalURL: http://harbor.dev.lan
```

Leave `expose.type: nodePort` (or whatever it is) alone — the NodePort
service stays in place, so `http://192.168.1.206:30002` keeps working as a
fallback. The only thing changing is the URL Harbor emits in its API
responses.

#### 3c. Add the Harbor chart repo and upgrade

```bash
# Add the upstream Harbor chart repository
helm repo add harbor https://helm.goharbor.io
helm repo update

# Upgrade the existing release in-place using the chart version that's
# already deployed (check `helm list -n harbor-system` for the version).
helm upgrade harbor harbor/harbor \
  --namespace harbor-system \
  --version 1.13.1 \
  -f harbor-values.yaml
```

Pin the `--version` to the version returned by `helm list` so you don't
accidentally upgrade Harbor itself at the same time you're tweaking config.
Run a separate, deliberate upgrade later if you want a newer version.

Watch the rollout:

```bash
kubectl rollout status deployment harbor-core -n harbor-system
kubectl rollout status deployment harbor-nginx -n harbor-system
```

### Step 4 — Trust `harbor.dev.lan` on every k3s node

Each k3s node has a `registries.yaml` that lists insecure HTTP mirrors. You
already configured `192.168.1.206:30002`; add `harbor.dev.lan` alongside
it. Without this, `containerd` on the nodes will refuse to pull images
referenced as `harbor.dev.lan/...` because they're served over plain HTTP.

SSH into each node and edit `/etc/rancher/k3s/registries.yaml`:

```yaml
mirrors:
  "192.168.1.206:30002":
    endpoint:
      - "http://192.168.1.206:30002"
  "harbor.dev.lan":
    endpoint:
      - "http://harbor.dev.lan"
```

Then restart k3s on that node:

```bash
# Control plane (dell-01)
sudo systemctl restart k3s

# Worker (nuc-01)
sudo systemctl restart k3s-agent
```

Each node also needs to resolve `harbor.dev.lan` — either via Pi-hole, or
by adding the hosts entry from Step 2 to each node's `/etc/hosts`.

Verify:

```bash
kubectl get nodes   # all nodes Ready
```

For full background on why this step is required, see
[K8s Harbor HTTP Registry Setup](../guides/k8s-harbor-http-registry.md).

### Step 5 — Trust `harbor.dev.lan` in your local Docker

On the development machine you push images from, add `harbor.dev.lan` to
Docker's `insecure-registries` next to the existing entry. The exact path
depends on your Docker installation (see the
[Colony deployment guide](https://github.com/jcarranz97/colony/blob/main/docs/architecture/deployment.md#step-1--harbor-setup-one-time)
for native-WSL2 vs Docker Desktop variants):

```json
{
  "insecure-registries": ["192.168.1.206:30002", "harbor.dev.lan"]
}
```

**Restart the Docker daemon** so it actually re-reads `daemon.json` — this
step is easy to forget and is the most common cause of `docker login`
failing immediately after the edit:

```bash
# systemd-based (native Linux, or WSL2 with systemd enabled)
sudo systemctl restart docker

# fallback (WSL2 without systemd)
sudo service docker restart
```

Then verify the daemon picked up the new entry:

```bash
docker info | grep -A5 "Insecure Registries"
# Should list both 192.168.1.206:30002 and harbor.dev.lan
```

> **Symptom if you skip the restart:** `docker login harbor.dev.lan` fails
> with `tls: failed to verify certificate: x509: certificate is valid for
> ...traefik.default, not harbor.dev.lan`. That's Traefik's default
> self-signed cert on port 443 being rejected because the daemon is still
> running with the old config and hasn't been told to treat
> `harbor.dev.lan` as insecure. Restart Docker and retry.

> **Docker Desktop users:** if Docker runs via Docker Desktop's WSL
> integration (no `dockerd` process inside WSL), editing
> `/etc/docker/daemon.json` inside WSL has no effect — the daemon lives in
> Docker Desktop's VM. Set `insecure-registries` from **Settings → Docker
> Engine** on the Windows side and click **Apply & restart** instead.

### Step 6 — Verify end-to-end

```bash
# UI
curl -I http://harbor.dev.lan
# HTTP/1.1 200 OK

# Registry handshake
curl -I http://harbor.dev.lan/v2/
# HTTP/1.1 401 Unauthorized   ← expected; means auth challenge works
# Www-Authenticate: Bearer realm="http://harbor.dev.lan/service/token",...
#                                ^^ should now say harbor.dev.lan, not the IP

# Login
docker login harbor.dev.lan
# Username: admin
# Password: ********
# Login Succeeded

# Tag and push a small image as a smoke test
docker pull alpine:3.20
docker tag alpine:3.20 harbor.dev.lan/library/alpine:3.20
docker push harbor.dev.lan/library/alpine:3.20

# Then verify pull works from the cluster's perspective
kubectl run alpine-test --rm -it --restart=Never \
  --image=harbor.dev.lan/library/alpine:3.20 -- echo ok
```

If the `Www-Authenticate` realm in the second `curl` still points at
`192.168.1.206:30002`, the `externalURL` change didn't take effect — check
that `helm get values harbor -n harbor-system` shows your updated value and
re-roll the `harbor-core` and `harbor-nginx` deployments.

### Coexistence: both URLs still work

After this setup, Harbor is reachable via **both**:

| URL | Use it for |
|---|---|
| `http://harbor.dev.lan` | New primary URL — UI and `docker push/pull` from clients that have DNS for `harbor.dev.lan` |
| `http://192.168.1.206:30002` | Fallback — still resolvable from clients that haven't been migrated. UI works; `docker login` works but the auth-challenge URL will redirect through `harbor.dev.lan`, so the client also needs DNS for that name. |

To gracefully migrate existing image references in deployments, update
their Helm values from `image.registry: "192.168.1.206:30002"` to
`image.registry: "harbor.dev.lan"` at a comfortable pace. Pods already
running on the old URL keep working — the change only matters at the next
image pull.

### Notes on HTTPS

This Ingress serves plain HTTP, matching how the rest of the homelab is
currently configured. When you eventually add TLS to Traefik (cert-manager
+ Let's Encrypt, or self-signed via mkcert):

1. Add a `tls:` block to the Ingress for `harbor.dev.lan`
2. Change `externalURL` to `https://harbor.dev.lan` and `helm upgrade`
3. Remove `harbor.dev.lan` from `insecure-registries` on each Docker client
4. Remove the `mirrors` entry from `registries.yaml` on each k3s node (or
   switch its `endpoint` to `https://harbor.dev.lan`)

---

## Troubleshooting

### Common Issues

- **Login failures**: Check credentials and network connectivity
- **Push failures**: Verify project exists and you have push permissions
- **Pull failures in K8s**: Ensure pull secrets are properly configured
- **ImagePullBackOff errors**: Verify nodes are configured for HTTP registry access (see [K8s HTTP Registry Guide](../guides/k8s-harbor-http-registry.md))
- **HTTPS client errors**: Configure cluster nodes to allow HTTP connections to Harbor
- **`docker login harbor.dev.lan` fails with `Get "https://harbor.dev.lan/v2/": ...`**: `harbor.dev.lan` is not in Docker's `insecure-registries` — see Step 5 above
- **`docker push` succeeds but `kubectl run` from a pod fails to pull**: a node is missing the `harbor.dev.lan` mirror in `/etc/rancher/k3s/registries.yaml` or can't resolve the hostname — see Step 4 above

### Quick Fixes

```bash
# Test Harbor connectivity
curl http://192.168.1.206:30002/v2/

# Check if nodes can access Harbor
kubectl describe pod <failing-pod> -n <namespace>

# Verify pull secret exists
kubectl get secrets -n <namespace>
```

## References

- [Harbor Documentation](https://goharbor.io/docs/)
- [Harbor & K8s Deployment Guide](../guides/harbor-k8s-deployment.md)
- [K8s Harbor HTTP Registry Configuration](../guides/k8s-harbor-http-registry.md)
