#!/usr/bin/env bash
# list-images.sh — imprime TODAS las imágenes de contenedor que el chart necesita,
# para pre-pullearlas a un registry local (install air-gapped / offline).
#
#   bash scripts/list-images.sh                       # con los defaults
#   bash scripts/list-images.sh -f examples/values-airgapped.yaml   # con tu overlay
#
# Renderiza el chart (con TODOS los toggles relevantes on para no perder ninguna
# imagen) y extrae las refs únicas. Pasá tus -f/--set para acotar a tu instalación.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
CHART="$HERE/../charts/leloir"

command -v helm >/dev/null || { echo "helm required" >&2; exit 2; }
helm dependency build "$CHART" >/dev/null 2>&1 || true

# Defaults: encendemos los opcionales que agregan imágenes (postgres bundleado,
# memory-mcp, webhook, gateway) para listar el conjunto MÁXIMO. El usuario acota con -f.
helm template leloir "$CHART" \
  --set memory.honcho.enabled=true \
  "$@" 2>/dev/null \
  | grep -E '^\s*image:' \
  | sed -E 's/.*image:\s*"?([^"]+)"?\s*$/\1/' \
  | sort -u
