# Changelog — Leloir Helm chart

El chart se publica como artefacto OCI firmado en `oci://ghcr.io/villadalmine/leloir`
(cosign keyless) en cada cambio. Cada tag `vX.Y.Z` crea un GitHub Release con estas notas
(el más nuevo es el recomendado). Versionado semántico; la sección de cada versión describe
los **features**, no los commits.

## v0.4.1 — 2026-07-17

Install público arreglado **end-to-end** — un `helm install` con defaults ahora funciona.

- **Imagen del control plane multi-arch (amd64 + arm64) y completa.** El `image.tag` por
  defecto pasó a `latest` (la appVersion `0.1.0` no se publicaba como tag de imagen → daría
  `ImagePullBackOff`).
- El **agente flagship con driver `builtin`** ya no crashea el control plane al arrancar
  (corre keyless contra el endpoint; el gateway inyecta la key).
- **Instalación air-gapped / offline:** `scripts/list-images.sh` (lista las imágenes a
  espejar), `examples/values-airgapped.yaml`, y una guía en el README.
- **Chart OCI firmado** (se arregló la auth de cosign en el publish).
- README: sección **Upgrading** (Helm no actualiza CRDs en upgrade → comando manual) y el
  comando de install ya no pinea una versión vieja (resuelve la última automáticamente).
- CI `kind-smoke` = gate duro: `helm install` **y** `helm upgrade` verdes en un cluster kind
  con los defaults.

## v0.4.0 — 2026-07-16

**Un solo chart.** El chart oficial reproduce exactamente el control plane que corre el
homelab del proyecto (paridad garantizada por un golden test).

- **3 drivers LLM:** `builtin` (apuntá a un endpoint OpenAI-compatible), `litellm-operator`,
  `envoy-ai-gw` (cadena keyless por-tenant).
- `agents.raw` / `routes.raw`: passthrough del schema real del control plane (tools inline,
  múltiples agentes) además del flagship/catch-all canned.
- `gateway.externalEndpoint` (usar un MCP gateway ya desplegado), OIDC completo
  (scopes / redirectURL / CA privada / hostAliases split-horizon), RBAC de containment
  gated, ServiceMonitor + dashboards de Grafana opcionales.

## v0.3.0 — 2026-07-14

- Adaptador **honcho-mcp** opcional: memoria episódica para agentes black-box contenidos,
  gobernada por el MCP Gateway (workspace = tenant, aislado). Paridad con el motor.

## v0.2.0 — 2026-07-14

- Paridad de features cerrada con el deploy de referencia: retención del audit
  (`hotRetentionDays`), black-box **containment** (Modo 2), `adminEmails` para OIDC.

## v0.1.x — 2026-07-13

- Primer chart standalone `leloir`: **un solo chart** con el stack completo — control plane
  (+ listener interno), MCP Gateway, memory-mcp, webhook-receiver, las **10 CRDs**, RBAC, y
  **Postgres 16 + pgvector** bundleado (opcional). Open-core / license-ready.
