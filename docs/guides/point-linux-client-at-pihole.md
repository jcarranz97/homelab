# Point a Single Linux Client at Pi-hole (IPv4 + IPv6)

Use this guide when you **can't** change DNS network-wide at the router (common on
ISP-supplied gateways — an `attlocal.net` search domain is a tell-tale AT&T sign) and only
one Linux machine needs to resolve internal homelab names through Pi-hole.

This is the per-machine companion to [Pi-hole as Local DNS for the Homelab](pi-hole-setup.md).
It configures both the **IPv4 and IPv6** resolvers on the connection — the IPv6 half is the
step most people miss, and it silently breaks resolution even when IPv4 is set correctly.

## The symptom

`nslookup` against the default resolver fails, but querying Pi-hole directly works:

```text
$ nslookup harbor.dev.lan
Server:    127.0.0.53
Address:   127.0.0.53#53
** server can't find harbor.dev.lan: NXDOMAIN

$ nslookup harbor.dev.lan 192.168.1.245     # Pi-hole, queried directly
Name:   harbor.dev.lan
Address: 192.168.1.206
```

`127.0.0.53` is `systemd-resolved`'s local stub. The lookup fails there because the stub is
still forwarding queries to a resolver that isn't Pi-hole — see
[Why this happens](#why-this-happens) for the full explanation.

## Background: who owns DNS on the machine

On modern Ubuntu/Debian desktops two components cooperate:

- **NetworkManager** owns the connection profile and decides which DNS servers exist.
- **systemd-resolved** does the actual resolving and listens on `127.0.0.53:53`.

Set DNS on the **NetworkManager connection** — *not* by editing `/etc/resolv.conf`, which is an
auto-managed symlink to `systemd-resolved`'s stub file (`../run/systemd/resolve/stub-resolv.conf`)
whose edits won't survive a reconnect or reboot.

## Step 1: Identify the active connection and interface

```bash
nmcli -t -f NAME,DEVICE,TYPE,STATE connection show --active
```

```text
WeLoveDogs:wlp13s0:802-11-wireless:activated
```

In this homelab the values are:

| Thing | Value |
|---|---|
| Connection name | `WeLoveDogs` |
| Interface | `wlp13s0` (Wi-Fi) |
| Pi-hole (IPv4) | `192.168.1.245` |
| Example name | `harbor.dev.lan` (a k3s app — a CNAME → `nuc-01.dev.lan`) |
| k3s ingress (that CNAME resolves to) | `192.168.1.206` |

Substitute your own connection name, interface, and Pi-hole IP throughout. The example uses
`harbor.dev.lan`; any `*.dev.lan` name from the [Pi-hole Local DNS Setup](pi-hole-setup.md)
works the same way (e.g. `rancher.dev.lan`, which resolves to `192.168.1.233`).

## Step 2: Point the connection at Pi-hole — IPv4

```bash
sudo nmcli connection modify WeLoveDogs ipv4.dns "192.168.1.245"
sudo nmcli connection modify WeLoveDogs ipv4.ignore-auto-dns yes
```

`ipv4.ignore-auto-dns yes` stops the router from *also* injecting its own IPv4 resolver
alongside Pi-hole, which would let internal queries leak past Pi-hole and fail intermittently.

## Step 3: Point the connection at Pi-hole — IPv6

This is the step that's easy to forget. Even with IPv4 configured perfectly, if the network
hands out IPv6 (most ISP gateways do, via Router Advertisement / DHCPv6), `systemd-resolved`
also receives the **router's IPv6 DNS server** and will often *prefer* it. That IPv6 resolver
doesn't know your homelab names, so lookups return `NXDOMAIN`.

`resolvectl status <interface>` reveals the leak — note the two servers and which one is active:

```text
Link 3 (wlp13s0)
    Current DNS Server: 2600:1700:1b0:91f0::1            ← router IPv6, actively used
          DNS Servers: 192.168.1.245 2600:1700:1b0:91f0::1
```

Tell the connection to ignore the auto-provided IPv6 DNS so Pi-hole is the only upstream left:

```bash
sudo nmcli connection modify WeLoveDogs ipv6.ignore-auto-dns yes
```

!!! note "If your Pi-hole has an IPv6 address"
    Pi-hole in this homelab is reachable over IPv4 only, so we simply drop the router's IPv6
    resolver. If your Pi-hole *does* have a static IPv6 address, set it explicitly instead so
    IPv6-only lookups still work:

    ```bash
    sudo nmcli connection modify WeLoveDogs ipv6.dns "<pihole-ipv6>"
    sudo nmcli connection modify WeLoveDogs ipv6.ignore-auto-dns yes
    ```

## Step 4: Apply the changes and clear the cache

```bash
sudo nmcli connection up WeLoveDogs    # ~1s reconnect, re-reads the profile
resolvectl flush-caches                # drop the cached NXDOMAIN from earlier
```

The cache flush matters: `systemd-resolved` caches negative answers, so a previously failed
lookup keeps failing for the TTL even after DNS is fixed.

## Step 5: Verify

```bash
resolvectl status wlp13s0      # "DNS Servers:" should list ONLY 192.168.1.245
nslookup harbor.dev.lan        # now resolves via 127.0.0.53 → 192.168.1.206
```

A correct result looks like:

```text
Link 3 (wlp13s0)
    Current DNS Server: 192.168.1.245
          DNS Servers: 192.168.1.245
```

```text
$ nslookup harbor.dev.lan
Server:    127.0.0.53
Address:   127.0.0.53#53
Name:   harbor.dev.lan
Address: 192.168.1.206
```

## Why this happens

`systemd-resolved` treats `NXDOMAIN` as a **valid DNS answer**, not a failure. When the
router's resolver authoritatively says "this name does not exist," `resolved` accepts that
response and does **not** fall back to the other configured server (Pi-hole). So as long as
*any* non-Pi-hole resolver is attached to the link and gets picked, internal names fail —
which is why fixing only IPv4 isn't enough if an IPv6 resolver is still leaking in. Removing
every non-Pi-hole upstream (both address families) is what makes resolution reliable.

## Reverting

The changes are persistent (they survive reboot) and fully reversible:

```bash
sudo nmcli connection modify WeLoveDogs ipv4.ignore-auto-dns no
sudo nmcli connection modify WeLoveDogs ipv6.ignore-auto-dns no
sudo nmcli connection modify WeLoveDogs ipv4.dns ""
sudo nmcli connection up WeLoveDogs
```

## Quick reference

```bash
# Inspect
nmcli -t -f NAME,DEVICE,TYPE,STATE connection show --active
resolvectl status <interface>

# Configure (IPv4 + IPv6)
sudo nmcli connection modify <conn> ipv4.dns "<pihole-ip>"
sudo nmcli connection modify <conn> ipv4.ignore-auto-dns yes
sudo nmcli connection modify <conn> ipv6.ignore-auto-dns yes
sudo nmcli connection up <conn>
resolvectl flush-caches

# Verify
resolvectl status <interface>
nslookup <name>.dev.lan
```
