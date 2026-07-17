#!/usr/bin/env bash
# check-parity.sh — el chart declara TODOS sus features de superficie de deploy.
#
# Chequeo puramente textual: cada token de config/env/endpoint que el control plane
# necesita debe aparecer en algún lado de charts/leloir/. Atrapa el "nos olvidamos de
# portar X al chart", no diferencias semánticas. Corre en CI sin dependencias.
#
#   bash scripts/check-parity.sh
#
# Agregá una línea a REQUIRED cada vez que el control plane suma un feature de deploy.
set -u

CHART_DIR="$(dirname "$0")/../charts/leloir"
FAIL=0

# token → por qué debe estar en el chart
REQUIRED=(
  "internalAddr:listener interno /internal/* (spec-m21 21.6)"
  "anomalyEndpoint:callback gateway thrash→quarantine"
  "auditEndpoint:forward gateway tool-call→WORM audit"
  "LELOIR_THRASH_TOKEN:bearer interno compartido"
  "LELOIR_DATABASE_DSN:DSN vía Secret"
  "LELOIR_AUDIT_STREAM_TOKEN:bearer del SIEM streaming"
  "streaming:config de SIEM audit streaming"
  "authentication:regla mTLS SPIFFE (hardening.mtls)"
  "ingressDeny:CNP internal-lock (hardening.networkPolicies)"
  "antiThrashing:anti-thrash + escalation del gateway"
  "spendVelocityUSD:umbral del detector de anomalías"
  "embeddingModel:RAG memoria episódica"
  "honcho-mcp:adaptador Honcho black-box (memory.honcho)"
  "notificationchannels:CRD NotificationChannel + spec.events (Q4 wiring)"
)

check_token() {
  local token="$1" why="$2"
  if grep -rq -- "$token" "$CHART_DIR"; then
    echo "  ✓ $token"
  else
    echo "  ✗ FALTA en el chart: $token  ($why)"
    FAIL=1
  fi
}

echo "── El chart declara todos sus features de deploy ──"
for entry in "${REQUIRED[@]}"; do
  check_token "${entry%%:*}" "${entry#*:}"
done

echo
if [ "$FAIL" -eq 1 ]; then
  echo "CHECK FALLÓ — al chart le falta un feature requerido (agregalo o actualizá la lista)."
  exit 1
fi
echo "CHECK OK — el chart trae todos los features de la lista."
