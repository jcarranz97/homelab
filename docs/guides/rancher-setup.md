# Installing Rancher on a Dedicated Homelab Node

This guide walks through installing [Rancher](https://www.rancher.com/) on a dedicated Ubuntu machine in your
homelab, then importing your existing k3s cluster so you can manage it from the Rancher UI.

Rancher is installed on its own machine (separate from the cluster it manages) so the management plane stays
available even when worker nodes are rebooted, upgraded, or experiencing issues.

## Overview

The setup looks like this:

```
┌──────────────────────────┐         ┌──────────────────────────────────────┐
│  Rancher Node (this guide) │       │     Existing k3s Cluster (managed)   │
│  - Ubuntu Server           │       │  ┌──────────┐ ┌──────────┐ ┌────────┐│
│  - Single-node k3s         │ ◄───► │  │ dell-01  │ │ nuc-01   │ │ ...    ││
│  - Rancher (Helm)          │       │  │ (master) │ │ (worker) │ │        ││
│  - cert-manager            │       │  └──────────┘ └──────────┘ └────────┘│
└──────────────────────────┘         └──────────────────────────────────────┘
  192.168.1.233 (rancher.dev.lan)            192.168.1.208 (master)
```

The Rancher node runs its **own** single-node k3s — this is just a host for Rancher itself and is independent
from the cluster you already use for workloads. In this homelab it is reachable at `192.168.1.233`, served as
`rancher.dev.lan` by Pi-hole (see the [Pi-hole Local DNS Setup guide](pi-hole-setup.md)).

## Prerequisites

### Hardware (Rancher node)

Rancher's [official requirements](https://ranchermanager.docs.rancher.com/getting-started/installation-and-upgrade/installation-requirements)
for a small management cluster:

- **CPU:** 2 cores minimum (4 recommended)
- **RAM:** 4 GB minimum (8 GB recommended)
- **Disk:** 40 GB+ SSD
- **Network:** Static IP on the same LAN as your k3s cluster

### Software

- Ubuntu Server 22.04 LTS or newer (clean install)
- SSH access from your management machine
- `kubectl` and `helm` available locally (for managing the existing k3s cluster)

### Network

- The Rancher node and the existing k3s cluster nodes must be able to reach each other.
- TCP **443** must be reachable on the Rancher node from anywhere you'll open the UI.
- The existing k3s cluster nodes need outbound access to the Rancher node on **443** so the cluster agent can
  register.
- Pi-hole running on the LAN so `rancher.dev.lan` resolves everywhere (recommended — see
  [Pi-hole Local DNS Setup](pi-hole-setup.md)). The bootstrap hosts-file fallback is noted in Step 6 for the
  pre-Pi-hole case.

## Step 1: Prepare the Rancher Node

On the dedicated Rancher machine:

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install basic utilities
sudo apt install -y curl wget

# Set a recognizable hostname
sudo hostnamectl set-hostname rancher-01
```

Confirm the static IP is configured (via netplan or your router's DHCP reservation) and note it down — in
this homelab the Rancher node is `192.168.1.233`. **Replace it with your actual IP throughout if different.**

## Step 2: Install k3s on the Rancher Node

Rancher will run on its own single-node k3s. Disable Traefik so the NGINX ingress that ships with the Rancher
chart can take over port 443.

```bash
# Install k3s without Traefik
curl -sfL https://get.k3s.io | sh -s - --disable=traefik --write-kubeconfig-mode=644

# Verify the node is Ready
sudo kubectl get nodes
```

Set up `kubectl` for your user on this node. **Do not copy the k3s kubeconfig over `~/.kube/config`** — if
this machine already has a kubeconfig pointing at another cluster (e.g. your existing homelab k3s), that
would silently overwrite it. Use a dedicated file and select it via `KUBECONFIG` instead:

```bash
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/k3s-local.yaml
sudo chown $(id -u):$(id -g) ~/.kube/k3s-local.yaml

# Point this shell at the local k3s. Run this in every shell where you'll
# run helm/kubectl commands for the Rancher install.
export KUBECONFIG=~/.kube/k3s-local.yaml

# Verify — must show ONLY this node, not your existing homelab cluster nodes
kubectl get nodes
```

!!! warning
    Before each `helm install` in the steps below, double-check with `kubectl get nodes` that you're talking
    to the local k3s. If you see your existing cluster's nodes, your shell is pointing at the wrong
    kubeconfig — re-run the `export KUBECONFIG=...` line above.

## Step 3: Install Helm

```bash
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

helm version
```

## Step 4: Install cert-manager

Rancher needs cert-manager to issue its self-signed TLS certificate.

```bash
# Add the Jetstack Helm repo
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install cert-manager with its CRDs
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true

# Wait until all cert-manager pods are Running
kubectl -n cert-manager get pods -w
```

Press `Ctrl+C` once all three pods (`cert-manager`, `cert-manager-cainjector`, `cert-manager-webhook`) are
`Running`.

## Step 5: Install Rancher via Helm

Add the Rancher Helm repo. The `stable` channel is recommended for homelab use.

```bash
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
helm repo update

kubectl create namespace cattle-system
```

Install Rancher. The chart's Ingress requires `hostname` to be a **DNS name** — Kubernetes rejects raw IPs in
`spec.rules[0].host`. This homelab uses `rancher.dev.lan`, served LAN-wide by Pi-hole as a direct A record to
the Rancher node (see [Pi-hole Local DNS Setup](pi-hole-setup.md)). No public DNS, no internet dependency.

```bash
helm install rancher rancher-stable/rancher \
  --namespace cattle-system \
  --set hostname=rancher.dev.lan \
  --set replicas=1 \
  --set bootstrapPassword=changeme-on-first-login \
  --set ingress.tls.source=rancher
```

!!! note
    `replicas=1` is correct for a single-node k3s host. The default chart value is 3, which would leave two
    pods stuck in `Pending`.

!!! tip "No Pi-hole yet? Bootstrap with a hosts file"
    If you're installing before Pi-hole exists, `rancher.dev.lan` still works — just add a temporary
    hosts-file entry on the machines that browse the UI (Step 6), then add the Pi-hole A record later. A
    public-DNS shortcut like [nip.io](https://nip.io) (`--set hostname=192.168.1.233.nip.io`) also works, but
    DNS-rebind protection on many routers (and Pi-hole) drops public responses pointing at private IPs, so
    the `rancher.dev.lan` + Pi-hole approach is the reliable end state.

Wait for the rollout to finish:

```bash
kubectl -n cattle-system rollout status deploy/rancher
```

This can take several minutes on the first run while images are pulled.

## Step 6: Make `rancher.dev.lan` Resolvable

Every device that opens the UI — and the pods that register the imported cluster — must resolve
`rancher.dev.lan` to `192.168.1.233`.

**Recommended — Pi-hole (LAN-wide):** add a single **A record** in Pi-hole:

- **Local DNS → DNS Records:** `rancher.dev.lan` → `192.168.1.233`

This is a *direct A record*, not a CNAME to `nuc-01.dev.lan` — Rancher is on its own node, not behind the k3s
ingress. Full context and verification steps are in the
[Pi-hole Local DNS Setup guide](pi-hole-setup.md). Once it's live:

```bash
dig @192.168.1.245 rancher.dev.lan +short   # → 192.168.1.233
```

**Bootstrap fallback — per-device hosts file** (only if Pi-hole isn't up yet). Add to each client:

```
192.168.1.233   rancher.dev.lan
```

- **Linux / macOS:** edit `/etc/hosts` with `sudo`.
- **Windows:** edit `C:\Windows\System32\drivers\etc\hosts` as Administrator.

```bash
ping rancher.dev.lan      # should reply from 192.168.1.233
```

!!! note "Hosts files don't reach pods"
    A hosts-file entry only resolves the name for the **host** that has it — it **does not propagate into
    pods**, which use CoreDNS. The Pi-hole record avoids this entirely: point the imported cluster's CoreDNS
    upstream at Pi-hole and every pod resolves `rancher.dev.lan` natively. Step 8.3 covers the pod-side
    fallback if CoreDNS can't reach Pi-hole.

## Step 7: First Login

1. Open `https://rancher.dev.lan` in your browser. You'll see a TLS warning because the cert is self-signed —
   click through (in Chrome, type `thisisunsafe` while the warning page is focused).
2. The bootstrap password is the one you set in the Helm command (`changeme-on-first-login`). If you forgot
   it, retrieve it with:

   ```bash
   kubectl -n cattle-system get secret bootstrap-secret -o go-template='{{.data.bootstrapPassword|base64decode}}{{"\n"}}'
   ```

3. Set a strong admin password when prompted.
4. Confirm the **Server URL** shown matches `https://rancher.dev.lan` and accept it.

You should now land on the Rancher home page with the **local** cluster (the single-node k3s hosting Rancher
itself) listed.

## Step 8: Import the Existing k3s Cluster

This is the step that connects Rancher to the cluster you already use for workloads.

### 8.1 Start the import in the Rancher UI

1. In the top-left menu, click ☰ → **Cluster Management**.
2. Click **Import Existing**.
3. Choose the **Generic** option (works for any Kubernetes distribution, including k3s).
4. Give the cluster a name (e.g. `homelab-k3s`) and click **Create**.

Rancher will display two `kubectl apply` commands. Copy the second one — it looks like:

```bash
kubectl apply -f https://rancher.dev.lan/v3/import/<long-token>.yaml
```

### 8.2 Apply the import manifest on the existing k3s cluster

From the machine where you already manage the existing cluster (i.e. where `kubectl get nodes` lists
`dell-01`, `nuc-01`, etc.):

```bash
# Verify you're pointed at the right cluster
kubectl config current-context
kubectl get nodes

# Apply the manifest from Rancher. Because Rancher uses a self-signed cert,
# you'll need --insecure on the curl piped into kubectl:
curl --insecure -sfL https://rancher.dev.lan/v3/import/<long-token>.yaml | kubectl apply -f -
```

!!! tip "Running this directly on a k3s control plane node?"
    On a k3s node, `/etc/rancher/k3s/k3s.yaml` is `root:root` mode 600 by default. If you don't have a
    user-level kubeconfig, plain `kubectl` fails with `permission denied`. Putting `sudo` only on `curl`
    doesn't help — it has to apply to the **kubectl** side of the pipe. Two options:

    ```bash
    # Option A: sudo the apply side and use the k3s-bundled kubectl
    curl --insecure -sfL https://rancher.dev.lan/v3/import/<long-token>.yaml | sudo k3s kubectl apply -f -

    # Option B: run the whole pipeline as root
    sudo bash -c 'curl --insecure -sfL https://rancher.dev.lan/v3/import/<long-token>.yaml | kubectl apply -f -'
    ```

    Or set up a user-level kubeconfig once so plain `kubectl` works:

    ```bash
    mkdir -p ~/.kube
    sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
    sudo chown $USER:$USER ~/.kube/config
    chmod 600 ~/.kube/config
    ```

This deploys the `cattle-cluster-agent` and `cattle-node-agent` into the existing cluster. They open an
outbound connection back to the Rancher node on 443.

### 8.3 Make `rancher.dev.lan` resolvable from inside the agent pod

With Pi-hole serving `rancher.dev.lan` LAN-wide **and** the imported cluster's CoreDNS forwarding upstream to
Pi-hole, the `cattle-cluster-agent` pod resolves the hostname natively — nothing extra to do. This step is
only the fallback when CoreDNS *cannot* reach Pi-hole and the agent crash-loops with:

```
ERROR: https://rancher.dev.lan/ping is not accessible (Could not resolve host: rancher.dev.lan)
```

The quickest patch is to inject a hosts-file mapping into just the agent pod via `hostAliases`:

```bash
kubectl -n cattle-system patch deployment cattle-cluster-agent --type='json' -p='[
  {"op": "add", "path": "/spec/template/spec/hostAliases", "value": [
    {"ip": "192.168.1.233", "hostnames": ["rancher.dev.lan"]}
  ]}
]'
```

That triggers a rollout. Watch the new pod come up:

```bash
kubectl get pods -n cattle-system -w
```

The pod should reach `Running` and stay there.

!!! warning "hostAliases is a workaround, not a permanent fix"
    Rancher manages the `cattle-cluster-agent` deployment. Future agent updates (chart upgrades,
    re-imports, etc.) **may overwrite** this `hostAliases` patch, putting the pod back into
    `CrashLoopBackOff`. Reapply the same patch when that happens. The durable fixes are:

    - **Pi-hole (preferred):** serve the record from your LAN's DNS resolver and point the imported
      cluster's CoreDNS upstream at Pi-hole so every pod resolves `rancher.dev.lan` natively.
    - **CoreDNS hosts block:** add a `hosts` block to the cluster's CoreDNS configmap mapping
      `rancher.dev.lan → 192.168.1.233` for every pod.

### 8.4 Confirm the cluster registers

Watch the agent come up on the existing cluster:

```bash
kubectl -n cattle-system get pods -w
```

Back in the Rancher UI, the cluster will move from **Pending** → **Waiting** → **Active** within a few
minutes. Once it's `Active`, all your existing nodes appear under **Cluster Management → homelab-k3s →
Nodes**.

## Step 9: Verification

From the Rancher UI:

- **Cluster Dashboard** for `homelab-k3s` should show node count, CPU, and memory matching your real cluster.
- **Workloads** should list everything currently running — Harbor, ingress controllers, any test deployments,
  etc.
- **Apps → Charts** lets you install Helm charts onto the imported cluster directly from Rancher.

From the CLI on the existing cluster:

```bash
# The agents should be Running, not CrashLoopBackOff
kubectl -n cattle-system get pods

# Logs should show "Connected" / no repeating TLS errors
kubectl -n cattle-system logs deploy/cattle-cluster-agent --tail=50
```

## Changing the Rancher Hostname

This homelab originally installed Rancher with `--set hostname=rancher.local` and migrated to
`rancher.dev.lan` once Pi-hole was serving LAN DNS. Changing the hostname touches **three** places — the Helm
release / Ingress, the self-signed TLS cert (its SAN is bound to the old name), and the `server-url` setting
stored inside Rancher. A `helm upgrade` alone is **not** enough.

**1. Add the new DNS record first.** In Pi-hole, **Local DNS → DNS Records:** `rancher.dev.lan` →
`192.168.1.233`. Verify before touching Rancher:

```bash
dig @192.168.1.245 rancher.dev.lan +short   # → 192.168.1.233
```

**2. Find the installed chart version** so the upgrade only changes the hostname and doesn't also bump
Rancher's version:

```bash
helm list -n cattle-system          # note the CHART column, e.g. rancher-2.x.x
```

**3. Helm upgrade** with the new hostname. Re-specify the non-default values (Helm resets to chart defaults
otherwise), pin the version, and drop `bootstrapPassword` (it is only read on *first* install):

```bash
helm upgrade rancher rancher-stable/rancher \
  --namespace cattle-system \
  --version <CHART_VERSION_FROM_STEP_2> \
  --set hostname=rancher.dev.lan \
  --set replicas=1 \
  --set ingress.tls.source=rancher
```

**4. Regenerate the self-signed cert.** With `ingress.tls.source=rancher`, the cert's SAN still contains the
old hostname; browsers reject it for the new name until it is regenerated:

```bash
kubectl -n cattle-system delete secret tls-rancher-ingress
kubectl -n cattle-system rollout restart deploy/rancher
kubectl -n cattle-system rollout status deploy/rancher
```

Rancher recreates `tls-rancher-ingress` with `rancher.dev.lan` in the SAN on startup.

**5. Update the stored `server-url`** (held in Rancher's database, not managed by Helm). Via the UI:
**☰ → Global Settings → server-url** → `https://rancher.dev.lan`. Or via the CLI:

```bash
kubectl patch setting server-url --type=merge -p '{"value":"https://rancher.dev.lan"}'
```

**6. Verify and re-point agents.**

```bash
kubectl -n cattle-system get ingress     # HOSTS column → rancher.dev.lan
curl -kI https://rancher.dev.lan         # → HTTP 200/302
```

Open `https://rancher.dev.lan` and re-accept the new self-signed cert. The imported cluster's
`cattle-cluster-agent` picks up the new `server-url` automatically; if it had a `hostAliases` patch (Step
8.3), update that patch to the new hostname or rely on Pi-hole + CoreDNS resolving it natively.

## Common Issues

### Helm install fails with `host: Invalid value: ... must be a DNS name, not an IP address`

The chart's Ingress rejects raw IPs in `spec.rules[0].host`. Pick a DNS name like `rancher.dev.lan` and
re-run with `--set hostname=rancher.dev.lan`. See Step 5.

### Browser shows `ERR_NAME_NOT_RESOLVED` / `DNS_PROBE_FINISHED_NXDOMAIN`

The client machine can't resolve the hostname. Common causes:

- **Missing Pi-hole record.** Confirm the `rancher.dev.lan` A record exists and points at `192.168.1.233`
  (`dig @192.168.1.245 rancher.dev.lan +short`). See [Pi-hole Local DNS Setup](pi-hole-setup.md).
- **Client not using Pi-hole.** The device is on a different resolver — check `resolvectl status` (Linux) /
  `scutil --dns` (macOS) and renew the DHCP lease.
- **Wrong record type.** If `rancher.dev.lan` resolves to `192.168.1.206` it was added as a CNAME to
  `nuc-01.dev.lan` by mistake. It must be a direct **A record** to `192.168.1.233`.

### Rancher pod stuck in `Pending`

Almost always because `replicas` defaulted to 3 on a single-node k3s. Re-run the install with
`--set replicas=1` or upgrade in place:

```bash
helm upgrade rancher rancher-stable/rancher \
  --namespace cattle-system \
  --reuse-values \
  --set replicas=1
```

### Cluster agent on the existing k3s can't connect

The agent error is usually one of:

- **`Could not resolve host: rancher.dev.lan`** (in `kubectl logs -n cattle-system deploy/cattle-cluster-agent`)
  — the **pod** can't resolve the hostname. Point the cluster's CoreDNS upstream at Pi-hole, or apply the
  `hostAliases` patch from Step 8.3.
- **`no such host` from the host machine itself** — when running `curl https://rancher.dev.lan` on a node and
  it fails: that node isn't using Pi-hole. Fix its resolver, or add a temporary `/etc/hosts` entry.
- **`x509: certificate signed by unknown authority`** — the agent doesn't trust Rancher's self-signed cert.
  Re-apply the import manifest using `curl --insecure` as shown in Step 8.2, **and** make sure the
  `CATTLE_SERVER` value inside the manifest matches the Server URL configured in Rancher (Step 7, item 4). If
  you recently changed the hostname, confirm `server-url` was updated (see *Changing the Rancher Hostname*).
- **`dial tcp ...:443: i/o timeout`** — firewall or routing problem between the cluster nodes and the Rancher
  node. Test with `curl -k https://rancher.dev.lan` from one of the existing cluster nodes.

### Forgot the bootstrap password before first login

```bash
kubectl -n cattle-system get secret bootstrap-secret \
  -o go-template='{{.data.bootstrapPassword|base64decode}}{{"\n"}}'
```

If the secret is gone, reset the admin password from inside the Rancher pod:

```bash
kubectl -n cattle-system exec -it deploy/rancher -- reset-password
```

## Next Steps

- **DNS:** Already done in this homelab — `rancher.dev.lan` is served LAN-wide by Pi-hole as an A record to
  `192.168.1.233`. See the [Pi-hole Local DNS Setup guide](pi-hole-setup.md). To change the hostname later,
  follow the **Changing the Rancher Hostname** section above (Helm upgrade + cert regeneration +
  `server-url`).
- **Backups:** Install the [rancher-backup](https://ranchermanager.docs.rancher.com/how-to-guides/advanced-user-guides/backup-restore-and-disaster-recovery)
  Helm chart on the Rancher node so you can recover the management state if the box dies.
- **Monitoring:** From the imported cluster's **Apps** tab, install the Rancher Monitoring chart for
  Prometheus + Grafana with prebuilt dashboards.
- **Upgrades:** Track new Rancher releases and upgrade with `helm upgrade rancher rancher-stable/rancher
  --reuse-values --version <new-version>`.

## Related Guides

- [K8s Cluster Setup](k8s-cluster-setup.md) — initial k3s cluster this guide imports
- [Harbor & K8s Deployment](harbor-k8s-deployment.md) — registry running on the imported cluster
- [Pi-hole Local DNS Setup](pi-hole-setup.md) — serves `rancher.dev.lan` and the k3s app hostnames
