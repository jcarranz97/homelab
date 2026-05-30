#!/usr/bin/env bash
#
# verify-hermes-mcp.sh — confirm the Hermes bot's MCP servers are configured and connected.
#
# Usage:
#   ./verify-hermes-mcp.sh <namespace>
#
# For every server in config.yaml's `mcp_servers`, it checks (from the live pod):
#   - every ${VAR} placeholder in the url/headers resolves to a set env var
#   - the server's host:port is reachable through the NetworkPolicy
#   - the gateway actually registered its tools (per agent.log)
#   - no auth/credential errors when the agent called those tools
#
# Exit code: 0 if every server is connected and error-free, 1 otherwise.
#
# Optional override:
#   POD_SELECTOR   label selector to find the pod  (default: app=hermes)

set -uo pipefail

NS="${1:-}"
POD_SELECTOR="${POD_SELECTOR:-app=hermes}"

if [[ -z "$NS" ]]; then
  echo "Usage: $0 <namespace>" >&2
  exit 2
fi

if [[ -t 1 ]]; then
  G=$'\e[32m'; R=$'\e[31m'; Y=$'\e[33m'; B=$'\e[1m'; N=$'\e[0m'
else
  G=""; R=""; Y=""; B=""; N=""
fi
PASS=0; FAIL=0; WARN=0
pass() { printf "    ${G}✔ PASS${N}  %s\n" "$1"; PASS=$((PASS+1)); }
fail() { printf "    ${R}✗ FAIL${N}  %s\n" "$1"; FAIL=$((FAIL+1)); }
warn() { printf "    ${Y}● WARN${N}  %s\n" "$1"; WARN=$((WARN+1)); }

command -v kubectl >/dev/null 2>&1 || { echo "kubectl not found" >&2; exit 2; }
kubectl get namespace "$NS" >/dev/null 2>&1 || { echo "Namespace '$NS' not found." >&2; exit 2; }

POD=$(kubectl get pods -n "$NS" -l "$POD_SELECTOR" \
        -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}' 2>/dev/null | awk '{print $1}')
[[ -z "$POD" ]] && POD=$(kubectl get pods -n "$NS" \
        -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}' 2>/dev/null | awk '{print $1}')
if [[ -z "$POD" ]]; then
  echo "No Running pod found in namespace '$NS' (selector: $POD_SELECTOR)." >&2
  exit 2
fi

printf "${B}Hermes MCP check${N}\n  namespace: %s\n  pod:       %s\n\n" "$NS" "$POD"

# All the data (config, env, logs, network) lives in the pod, so the probe runs there.
# It emits a simple pipe-delimited protocol that this script renders.
RAW=$(kubectl exec -n "$NS" "$POD" -i -- python3 - <<'PY' 2>/dev/null
import os, re, socket, sys

CONFIG = "/opt/data/config.yaml"
LOGDIR = "/opt/data/logs"

def out(*a): print("|".join(str(x) for x in a))

try:
    import yaml
    cfg = yaml.safe_load(open(CONFIG)) or {}
except Exception as e:
    out("FATAL", "cannot parse %s: %s" % (CONFIG, e)); sys.exit(0)

servers = cfg.get("mcp_servers") or {}
if not servers:
    out("NOSERVERS"); sys.exit(0)

logtext = ""
for f in ("agent.log", "errors.log", "gateway.log"):
    try:
        logtext += open(os.path.join(LOGDIR, f), encoding="utf-8", errors="replace").read()
    except Exception:
        pass

def placeholders(s):
    return re.findall(r"\$\{([A-Za-z_][A-Za-z0-9_]*)\}", s or "")

for name, sc in servers.items():
    sc = sc or {}
    url = sc.get("url") or ""
    out("SERVER", name, url or "(no url — stdio server?)")

    if not url:
        out("CHECK", name, "WARN", "no url — this checker covers HTTP servers only")
        continue

    # 1. ${VAR} placeholders resolve from the pod env
    vs = set(placeholders(url))
    for hv in (sc.get("headers") or {}).values():
        vs.update(placeholders(hv if isinstance(hv, str) else ""))
    if vs:
        missing = sorted(v for v in vs if not os.environ.get(v))
        if missing:
            out("CHECK", name, "FAIL", "env var(s) not set in pod: %s — add to the Secret + restart" % ", ".join(missing))
        else:
            out("CHECK", name, "PASS", "all ${VAR} placeholders resolve: %s" % ", ".join(sorted(vs)))

    # 2. TCP reachability through the NetworkPolicy
    m = re.match(r"(https?)://([^/:]+)(?::(\d+))?", url)
    if m:
        scheme, host, port = m.group(1), m.group(2), m.group(3)
        port = int(port) if port else (443 if scheme == "https" else 80)
        s = socket.socket(); s.settimeout(6)
        try:
            s.connect((host, port)); out("CHECK", name, "PASS", "TCP reachable at %s:%d" % (host, port))
        except Exception as e:
            out("CHECK", name, "FAIL", "cannot reach %s:%d (%s) — check the NetworkPolicy egress rule" % (host, port, type(e).__name__))
        finally:
            s.close()

    # 3. did the gateway register this server's tools?
    reg = re.findall(r"MCP server '%s'[^\n]*registered (\d+) tool" % re.escape(name), logtext)
    if reg:
        out("CHECK", name, "PASS", "connected — %s tool(s) registered (per agent.log)" % reg[-1])
    else:
        out("CHECK", name, "WARN", "no 'registered N tool(s)' line in logs — not connected yet, or logs rotated; restart and recheck")

    # 4. auth / tool-call errors for THIS server
    toollines = re.findall(r"Tool mcp_%s_\w+ returned error[^\n]*" % re.escape(name), logtext)
    autherr = [l for l in toollines if re.search(r"401|validate credentials|[Uu]nauthorized|[Ff]orbidden", l)]
    if autherr:
        out("CHECK", name, "FAIL", "token rejected by the server (e.g. HTTP 401 'Could not validate credentials') — check the token value / that it belongs to this instance")
    elif toollines:
        out("CHECK", name, "WARN", "%d tool-call error(s) in logs — inspect agent.log" % len(toollines))
    else:
        out("CHECK", name, "PASS", "no auth/tool-call errors in logs")
PY
)

if [[ -z "$RAW" ]]; then
  echo "Could not read MCP state from the pod (no python3 or unreadable config)." >&2
  exit 2
fi

# Render the probe output
while IFS='|' read -r kind a b c; do
  case "$kind" in
    FATAL)     fail "$a"; ;;
    NOSERVERS) warn "no MCP servers configured in /opt/data/config.yaml (mcp_servers is empty)"; ;;
    SERVER)    printf "${B}● %s${N}  %s\n" "$a" "$b"; ;;
    CHECK)
      case "$b" in
        PASS) pass "$c" ;;
        WARN) warn "$c" ;;
        FAIL) fail "$c" ;;
      esac
      ;;
  esac
done <<< "$RAW"

printf "\n${B}Summary${N}\n"
printf "  ${G}%d passed${N}, ${Y}%d warnings${N}, ${R}%d failed${N}\n" "$PASS" "$WARN" "$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  printf "  ${R}${B}One or more MCP servers are not fully working — see FAIL items above.${N}\n"
  exit 1
fi
printf "  ${G}${B}MCP looks healthy.${N}"
[[ "$WARN" -gt 0 ]] && printf " Review the warnings above.\n" || printf "\n"
exit 0
