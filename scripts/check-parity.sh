#!/usr/bin/env bash
# check-parity.sh — guards against drift between the founders' private deploy
# (infra-ai Ansible role) and THIS official chart.
#
# Routine (mandatory): every feature proven via infra-ai must be replicated
# here and tested with the official chart. This script makes forgetting loud.
#
# How it works: it extracts the leloir config surface from the Ansible role
# (config keys, env vars, internal endpoints, CNP names) and checks each one
# appears somewhere in charts/leloir/. Purely textual — it catches "we forgot
# to port X", not semantic differences.
#
# Usage:
#   INFRA_ROLE=~/Nextcloud/Repos/infra-ai/infra/roles/install-leloir ./scripts/check-parity.sh
#
# Without INFRA_ROLE (e.g. public CI, where infra-ai is not available) it
# checks the STATIC manifest below instead, which lists every deploy-surface
# feature that MUST exist in the chart. Add a line here whenever you add a
# feature to the infra-ai role.
set -u

CHART_DIR="$(dirname "$0")/../charts/leloir"
FAIL=0

# ── Static parity manifest (update when infra-ai grows a feature) ─────────────
# token → why it must be in the chart
REQUIRED=(
  "internalAddr:internal /internal/* listener (spec-m21 21.6)"
  "anomalyEndpoint:gateway thrash→quarantine callback"
  "auditEndpoint:gateway tool-call→WORM audit forward"
  "LELOIR_THRASH_TOKEN:shared internal bearer"
  "LELOIR_DATABASE_DSN:DSN via Secret"
  "LELOIR_AUDIT_STREAM_TOKEN:SIEM streaming bearer"
  "streaming:SIEM audit streaming config"
  "authentication:mTLS SPIFFE rule (hardening.mtls)"
  "ingressDeny:internal-lock CNP (hardening.networkPolicies)"
  "antiThrashing:gateway anti-thrash + escalation"
  "spendVelocityUSD:anomaly detector threshold"
  "embeddingModel:RAG episodic memory"
)

check_token() {
  local token="$1" why="$2"
  if grep -rq "$token" "$CHART_DIR"; then
    echo "  ✓ $token"
  else
    echo "  ✗ MISSING in chart: $token  ($why)"
    FAIL=1
  fi
}

echo "── Static manifest vs chart ──"
for entry in "${REQUIRED[@]}"; do
  check_token "${entry%%:*}" "${entry#*:}"
done

# ── Dynamic check against the live Ansible role (when available) ──────────────
if [ -n "${INFRA_ROLE:-}" ] && [ -d "$INFRA_ROLE" ]; then
  echo "── infra-ai role vs chart (dynamic) ──"
  # Config keys the role renders into leloir ConfigMaps (gateway.yaml/config.yaml).
  keys=$(grep -hoE "^\s+[a-zA-Z][a-zA-Z0-9]+:" "$INFRA_ROLE/tasks/main.yml" 2>/dev/null \
    | tr -d ' :' | sort -u \
    | grep -vE "^(name|namespace|metadata|labels|spec|data|kind|apiVersion|definition|state|app|matchLabels|port|protocol|ports|image|env|value|key|containers|template|selector|replicas|valueFrom|secretKeyRef|containerPort|targetPort|when|path|host|hostnames|parentRefs|rules|matches|backendRefs|weight|type|stringData|items|command|args|volumeMounts|volumes|configMap|mountPath|subPath|readOnly|initContainers|resources|limits|requests|memory|cpu)$")
  for k in $keys; do
    if ! grep -rq "$k" "$CHART_DIR"; then
      echo "  ⚠ role key not found in chart: $k (verify: real feature or infra-only detail?)"
    fi
  done
  echo "  (⚠ = review; only config-surface keys matter, infra-only details are fine)"
else
  echo "── infra-ai role not available (INFRA_ROLE unset) — static manifest only ──"
fi

echo
if [ "$FAIL" -eq 1 ]; then
  echo "PARITY CHECK FAILED — the official chart is missing required features."
  exit 1
fi
echo "PARITY CHECK OK"
