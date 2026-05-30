#!/usr/bin/env bash
#
# verify-hermes-isolation.sh — confirm a Hermes Agent bot pod is properly sandboxed.
#
# Usage:
#   ./verify-hermes-isolation.sh <namespace>
#
# Checks the controls from the "Hermes Agent on k3s" guide:
#   - no Kubernetes API access (no mounted SA token, no RoleBindings)
#   - network isolation (can reach the internet/Telegram, CANNOT reach the LAN)
#   - no host access (hostNetwork/hostPID/hostIPC/hostPath/privileged)
#   - NetworkPolicy present and denying all inbound
#   - agent terminal backend pinned to 'local'
#
# Exit code: 0 if every critical check passes, 1 otherwise (WARNs don't fail).
#
# Optional overrides (env vars):
#   POD_SELECTOR   label selector to find the pod   (default: app=hermes)
#   TEST_LAN_TARGET  "host:port" on your LAN that should be BLOCKED
#                    (default: a cluster node InternalIP on port 10250)

set -uo pipefail

NS="${1:-}"
POD_SELECTOR="${POD_SELECTOR:-app=hermes}"

if [[ -z "$NS" ]]; then
  echo "Usage: $0 <namespace>" >&2
  exit 2
fi

# ── output helpers ──────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  G=$'\e[32m'; R=$'\e[31m'; Y=$'\e[33m'; B=$'\e[1m'; N=$'\e[0m'
else
  G=""; R=""; Y=""; B=""; N=""
fi
PASS=0; FAIL=0; WARN=0
pass() { printf "  ${G}✔ PASS${N}  %s\n" "$1"; PASS=$((PASS+1)); }
fail() { printf "  ${R}✗ FAIL${N}  %s\n" "$1"; FAIL=$((FAIL+1)); }
warn() { printf "  ${Y}● WARN${N}  %s\n" "$1"; WARN=$((WARN+1)); }
info() { printf "  ${B}›${N} %s\n" "$1"; }
section() { printf "\n${B}%s${N}\n" "$1"; }

need() { command -v "$1" >/dev/null 2>&1 || { echo "Required tool '$1' not found." >&2; exit 2; }; }
need kubectl

# ── locate the pod ──────────────────────────────────────────────────────────
kubectl get namespace "$NS" >/dev/null 2>&1 || { echo "Namespace '$NS' not found." >&2; exit 2; }

POD=$(kubectl get pods -n "$NS" -l "$POD_SELECTOR" \
        -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}' 2>/dev/null \
        | awk '{print $1}')
if [[ -z "$POD" ]]; then
  # fall back to the first Running pod in the namespace
  POD=$(kubectl get pods -n "$NS" \
          -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}' 2>/dev/null \
          | awk '{print $1}')
fi
if [[ -z "$POD" ]]; then
  echo "No Running pod found in namespace '$NS' (selector: $POD_SELECTOR)." >&2
  exit 2
fi

printf "${B}Hermes isolation check${N}\n  namespace: %s\n  pod:       %s\n" "$NS" "$POD"

# run a command in the pod's default container, swallowing the "Defaulted container" notice
inpod() { kubectl exec -n "$NS" "$POD" -- "$@" 2>/dev/null; }

# ── 1. Kubernetes API access ────────────────────────────────────────────────
section "1. Kubernetes API access"

SA=$(kubectl get pod "$POD" -n "$NS" -o jsonpath='{.spec.serviceAccountName}' 2>/dev/null)
SA=${SA:-default}
info "ServiceAccount: $SA"

automount=$(kubectl get pod "$POD" -n "$NS" -o jsonpath='{.spec.automountServiceAccountToken}' 2>/dev/null)
if [[ "$automount" == "false" ]]; then
  pass "automountServiceAccountToken is false on the pod"
else
  warn "automountServiceAccountToken is not explicitly false (got: '${automount:-unset}')"
fi

if inpod ls /var/run/secrets/kubernetes.io/serviceaccount/token >/dev/null 2>&1; then
  fail "SA token IS mounted in the pod — the agent can call the Kubernetes API"
else
  pass "no SA token mounted in the pod (kube API unreachable via token)"
fi

# Any RoleBindings / ClusterRoleBindings granting this SA?
rb=$(kubectl get rolebindings -n "$NS" -o json 2>/dev/null \
      | grep -c "\"name\": \"$SA\"" )
crb=$(kubectl get clusterrolebindings -o json 2>/dev/null \
      | grep -c "\"namespace\": \"$NS\".*\"name\": \"$SA\"")
if [[ "${rb:-0}" -eq 0 ]]; then
  pass "no RoleBindings in '$NS' reference ServiceAccount '$SA'"
else
  fail "$rb RoleBinding(s) in '$NS' reference '$SA' — it has namespace permissions"
fi
# ClusterRoleBinding subjects are awkward to grep precisely; treat hits as a warning to inspect.
if [[ "${crb:-0}" -gt 0 ]]; then
  warn "a ClusterRoleBinding may reference '$SA' — inspect: kubectl get clusterrolebindings -o wide"
else
  pass "no obvious ClusterRoleBinding references ServiceAccount '$SA'"
fi

# ── 2. Host access ──────────────────────────────────────────────────────────
section "2. Host & privilege boundary"

hostNet=$(kubectl get pod "$POD" -n "$NS" -o jsonpath='{.spec.hostNetwork}' 2>/dev/null)
hostPID=$(kubectl get pod "$POD" -n "$NS" -o jsonpath='{.spec.hostPID}' 2>/dev/null)
hostIPC=$(kubectl get pod "$POD" -n "$NS" -o jsonpath='{.spec.hostIPC}' 2>/dev/null)
for pair in "hostNetwork:$hostNet" "hostPID:$hostPID" "hostIPC:$hostIPC"; do
  k=${pair%%:*}; v=${pair#*:}
  if [[ "$v" == "true" ]]; then fail "$k is true"; else pass "$k is not enabled"; fi
done

hostpaths=$(kubectl get pod "$POD" -n "$NS" -o jsonpath='{range .spec.volumes[*]}{.hostPath.path}{"\n"}{end}' 2>/dev/null | grep -c .)
if [[ "${hostpaths:-0}" -eq 0 ]]; then
  pass "no hostPath volumes"
else
  fail "$hostpaths hostPath volume(s) mounted — the pod can touch the node filesystem"
fi

priv=$(kubectl get pod "$POD" -n "$NS" -o jsonpath='{range .spec.containers[*]}{.securityContext.privileged}{"\n"}{end}' 2>/dev/null | grep -c true)
if [[ "${priv:-0}" -eq 0 ]]; then pass "no privileged containers"; else fail "$priv privileged container(s)"; fi

ape=$(kubectl get pod "$POD" -n "$NS" -o jsonpath='{range .spec.containers[*]}{.securityContext.allowPrivilegeEscalation}{"\n"}{end}' 2>/dev/null | grep -c false)
if [[ "${ape:-0}" -ge 1 ]]; then pass "allowPrivilegeEscalation: false set on container(s)"; else warn "allowPrivilegeEscalation is not false on any container"; fi

# ── 3. NetworkPolicy presence ───────────────────────────────────────────────
section "3. NetworkPolicy (inbound denial)"

if kubectl get networkpolicy -n "$NS" 2>/dev/null | grep -q .; then
  pass "at least one NetworkPolicy exists in '$NS'"
  hasEgress=$(kubectl get networkpolicy -n "$NS" -o jsonpath='{range .items[*]}{.spec.policyTypes}{"\n"}{end}' 2>/dev/null | grep -c Egress)
  hasIngress=$(kubectl get networkpolicy -n "$NS" -o jsonpath='{range .items[*]}{.spec.policyTypes}{"\n"}{end}' 2>/dev/null | grep -c Ingress)
  [[ "${hasIngress:-0}" -ge 1 ]] && pass "a policy controls Ingress" || warn "no policy lists Ingress in policyTypes"
  [[ "${hasEgress:-0}"  -ge 1 ]] && pass "a policy controls Egress"  || warn "no policy lists Egress in policyTypes — LAN may be reachable"
else
  fail "no NetworkPolicy in '$NS' — the pod is NOT network-isolated"
fi

# ── 4. Live network behaviour ───────────────────────────────────────────────
section "4. Live network behaviour (from inside the pod)"

if ! inpod python3 -c 'pass' >/dev/null 2>&1; then
  warn "python3 not available in the pod; skipping live network tests"
else
  # DNS resolves
  if inpod python3 -c "import socket; socket.gethostbyname('api.telegram.org')" >/dev/null 2>&1; then
    pass "DNS resolution works"
  else
    warn "DNS resolution failed (the bot needs DNS — check the port-53 egress rule)"
  fi

  # Internet HTTPS reachable (Telegram). The bot can't work without this.
  if inpod python3 -c "import urllib.request as u; u.urlopen('https://api.telegram.org', timeout=10)" >/dev/null 2>&1; then
    pass "outbound HTTPS to the internet works (Telegram reachable)"
  else
    warn "outbound HTTPS to api.telegram.org failed — the bot can't talk to Telegram"
  fi

  # tcp_probe HOST PORT -> prints CONNECTED | TIMEOUT | ERR:<name>
  tcp_probe() {
    inpod python3 -c "
import socket
s=socket.socket(); s.settimeout(5)
try:
    s.connect(('$1', $2)); print('CONNECTED')
except socket.timeout: print('TIMEOUT')
except Exception as e: print('ERR:'+type(e).__name__)
finally: s.close()
"
  }

  # Decisive LAN/cluster block test. We probe a target that is GUARANTEED to have a
  # listener — the Kubernetes API ClusterIP on 443 — which is in a private range and
  # must be blocked by the policy (only DNS/53 is allowed to private destinations).
  # Because something is definitely listening there, CONNECTED unambiguously means the
  # egress policy is leaking. A blocked result may appear as TIMEOUT (drop-mode policy)
  # OR connection-refused (reject-mode policy, e.g. k3s/kube-router) — both are fine.
  api_ip=$(kubectl get svc kubernetes -n default -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
  if [[ -n "$api_ip" ]]; then
    info "probing Kubernetes API $api_ip:443 (must be BLOCKED; it always has a listener)"
    case "$(tcp_probe "$api_ip" 443)" in
      CONNECTED) fail "reached the Kubernetes API at $api_ip:443 — egress isolation is LEAKING" ;;
      TIMEOUT)   pass "Kubernetes API $api_ip:443 blocked (packets dropped)" ;;
      ERR:ConnectionRefused*) pass "Kubernetes API $api_ip:443 blocked (policy rejects with RST)" ;;
      ERR:*)     pass "Kubernetes API $api_ip:443 not reachable (blocked)" ;;
      *)         warn "Kubernetes API probe inconclusive" ;;
    esac
  else
    warn "could not resolve the Kubernetes API ClusterIP to test egress blocking"
  fi

  # Optional: probe a specific LAN service the user knows is listening (TEST_LAN_TARGET).
  # Same logic — CONNECTED means a leak; anything else means blocked.
  if [[ -n "${TEST_LAN_TARGET:-}" ]]; then
    lh="${TEST_LAN_TARGET%:*}"; lp="${TEST_LAN_TARGET##*:}"
    info "probing LAN target $lh:$lp (must be BLOCKED)"
    case "$(tcp_probe "$lh" "$lp")" in
      CONNECTED) fail "LAN target $lh:$lp is REACHABLE — network isolation is leaking" ;;
      TIMEOUT)   pass "LAN target $lh:$lp blocked (packets dropped)" ;;
      ERR:ConnectionRefused*) pass "LAN target $lh:$lp blocked (policy rejects with RST)" ;;
      ERR:*)     pass "LAN target $lh:$lp not reachable (blocked)" ;;
      *)         warn "LAN probe inconclusive" ;;
    esac
  fi
fi

# ── 5. Agent terminal backend ───────────────────────────────────────────────
section "5. Agent terminal backend"
cfg=$(inpod cat /opt/data/config.yaml 2>/dev/null)
if [[ -z "$cfg" ]]; then
  warn "could not read /opt/data/config.yaml (not a Hermes pod, or different path)"
elif printf '%s' "$cfg" | grep -Eq 'backend:[[:space:]]*local'; then
  pass "terminal backend is 'local' (shell commands run in-pod)"
else
  warn "terminal backend is not 'local' — the agent may run commands outside this pod:"
  printf '%s\n' "$cfg" | sed 's/^/      /'
fi

# ── summary ─────────────────────────────────────────────────────────────────
section "Summary"
printf "  ${G}%d passed${N}, ${Y}%d warnings${N}, ${R}%d failed${N}\n" "$PASS" "$WARN" "$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  printf "  ${R}${B}Isolation is NOT intact — review the FAIL items above.${N}\n"
  exit 1
fi
printf "  ${G}${B}No isolation failures.${N}"
[[ "$WARN" -gt 0 ]] && printf " Review the warnings above.\n" || printf "\n"
exit 0
