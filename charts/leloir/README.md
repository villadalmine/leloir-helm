# Leloir Helm Chart

The public **standalone** chart for [Leloir](https://github.com/villadalmine/leloir)
— the governance control plane for AI agents on Kubernetes.

```bash
# Installation (local profile, bundled Postgres+pgvector)
helm install leloir oci://ghcr.io/villadalmine/leloir --version 0.1.1 --namespace leloir-system --create-namespace
```

## What it deploys

A single chart, the full stack: **control plane** (+ internal listener), **MCP Gateway**,
**memory-mcp**, **webhook-receiver** (Alertmanager → Leloir), all **10 CRDs**, RBAC
(cluster-wide read-only watcher), and **Postgres 16 + pgvector** (Bitnami subchart,
optional).

## Open-core model (license-ready)

All **OSS** features are enabled by default and are free (L7 gateway + budgets + RBAC +
dashboards). **Licensed** features (RAG, Anomaly Quarantine, mTLS/SPIFFE) are gated by
the presence of a `license.key` in the Secrets — the core enables/disables them at
**runtime** (cryptographic validation is planned for the future). The chart only transports the key:

```yaml
license:
  key: ""                 # empty = OSS; with key = licensed features enabled (runtime)
```

## Key Values

| Value | Default | Description |
|-------|---------|-------------|
| `profile` | `local` | `local` (safe-to-test) or `corporate` (OIDC + external Postgres) |
| `postgresql.enabled` | `true` | Bundled Postgres+pgvector; `false` → `externalDatabase.dsn` |
| `postgresql.auth.password` | `leloir-change-me` | ⚠ override in prod |
| `image.repository` | `ghcr.io/villadalmine/leloir-controlplane` | private — inject `imagePullSecrets` |
| `ingress.enabled` | `true` | Standard Ingress; or `gateway_api.enabled` for HTTPRoute |
| `hardening.mtls.enabled` | `false` | mTLS SPIFFE (Mission Critical; requires Cilium) |
| `rag.enabled` / `anomaly.*` | on | Team features (runtime gates them by license) |

## LLM layer (required to investigate)

Leloir governs agents that use an LLM — so it needs to reach one. Point it at any
**OpenAI-compatible endpoint** (a litellm/vLLM proxy, Ollama's `/v1`, or a provider API).
The chart ships a working default: the first-party **flagship agent** + a catch-all route,
so a fresh install can investigate out of the box once you set the endpoint.

```yaml
llm:
  enabled: true
  driver: builtin                       # simplest; also: litellm-operator, envoy-ai-gw
  endpoint: "http://litellm.svc:4000"   # your OpenAI-compatible proxy (handles upstream auth)
  model:
    id: default-model
    upstream: "gpt-4o-mini"             # the model name your endpoint exposes
    pricing: {inputPer1M: 0.15, outputPer1M: 0.60}   # for metering/budget
    maxTokensPerCall: 1024
  tenantBudget: {monthlyMaxUSD: 50, hardLimitAction: reject}   # 4-layer budget guard

agents:
  flagship: {enabled: true, model: default-model}   # first-party agent; off = BYO-agent via CRD
routes:
  catchAll: {enabled: true, budgetMaxUSD: 0.50}      # every alert → flagship
```

| Value | Default | Description |
|-------|---------|-------------|
| `llm.driver` | `builtin` | `builtin` (point at an endpoint), `litellm-operator`, `envoy-ai-gw` |
| `llm.endpoint` | `""` | OpenAI-compatible URL. Should handle upstream auth (e.g. litellm with your keys) |
| `llm.model.upstream` | `gpt-4o-mini` | model name at your endpoint |
| `llm.tenantBudget.monthlyMaxUSD` | `50` | per-tenant cap; the budget guard cancels investigations that exceed it |
| `agents.flagship.enabled` | `true` | first-party agent; set `false` to bring your own via an `AgentRegistration` CRD |
| `routes.catchAll.enabled` | `true` | catch-all route so alerts investigate out of the box |

**BYO-agent:** Leloir's differentiator is the `AgentAdapter` contract — register HolmesGPT,
k8sgpt, a kagent (via `type: a2a`), or your own with an `AgentRegistration` CRD, and it's
governed the same way. Set `agents.flagship.enabled=false` and add your `AgentRegistration`.
**Tools** (real cluster reads, etc.) are added via `MCPServer` CRDs through the gateway.

### Advanced: integrating with pre-existing infra (BYO / power-user)

The same **one chart** scales down to a beginner (canned flagship + bundled Postgres) and
up to a power-user who already runs Postgres, an MCP gateway, and a 2-layer LLM stack
(Envoy AI Gateway → litellm). See **`examples/values-advanced.yaml`** for a full example —
this is exactly how the project's own homelab installs.

| Value | Default | Description |
|-------|---------|-------------|
| `llm.driver: envoy-ai-gw` | — | per-tenant keyless chain (Envoy AI GW → litellm). Fill `llm.envoyAIGateway.*` + `llm.litellmOperator.*` |
| `llm.driver: litellm-operator` | — | reconcile teams/keys on an existing `LiteLLMInstance`. Fill `llm.litellmOperator.*` |
| `agents.raw` | `[]` | **replaces** the canned flagship with a full agent list — inline `tools`, multiple agents (e.g. `holmesgpt`), custom toolsets. The CP's real schema. |
| `routes.raw` | `[]` | **replaces** the canned catch-all with full routes (custom `agentName`, `budgetMaxTokens`, …) |
| `gateway.enabled: false` + `gateway.externalEndpoint` | — | don't deploy the gateway; point the CP at an existing one |
| `postgresql.enabled: false` + `externalDatabase.existingSecret` | — | use your own Postgres via a DSN Secret |
| `observability.serviceMonitor.enabled` | `false` | Prometheus-Operator `ServiceMonitor` for the CP + gateway (set `.labels` so your Prometheus selects it) |
| `observability.dashboards.enabled` | `false` | ship the Leloir Grafana dashboards as sidecar ConfigMaps |
| `observability.otlp.enabled` + `.endpoint` | `false` | OTLP tracing (real-model traceability) to your collector |

`agents.raw`/`routes.raw` exist because agents and routes are inherently free-form (arbitrary
tools, multiple agents). Beginners use the canned `flagship`/`catchAll`; power-users pass the
real config through. **Either way it's one chart** — no forked "homelab" variant.

## Authentication (OIDC / SSO)

By default the chart runs in **single-user** mode (a static local admin — fine for
evaluation). For real use, enable **OIDC** against any OIDC-compliant provider
(Dex, Keycloak, Google, Entra ID, Okta, Auth0…).

**Full worked example:** [`examples/values-oidc.yaml`](examples/values-oidc.yaml).
Minimal setup:

```yaml
auth:
  mode: oidc
  oidc:
    enabled: true
    issuer: "https://dex.example.com"          # reachable by the CP pod AND the browser
    clientID: "leloir"                          # register a client with redirect
                                                #   https://leloir.example.com/auth/callback
    existingSecret: "leloir-oidc"               # holds key `client-secret` (never in values)
    adminEmails: ["you@example.com"]            # emails granted the admin role
```

```bash
kubectl create secret generic leloir-oidc -n leloir \
  --from-literal=client-secret='<YOUR_CLIENT_SECRET>'
helm upgrade --install leloir leloir/leloir -n leloir -f examples/values-oidc.yaml
```

### OIDC value reference

| Value | Default | Description |
|-------|---------|-------------|
| `auth.mode` | `single-user` | set to `oidc` to enable SSO |
| `auth.oidc.enabled` | `false` | must be `true` with `mode: oidc` |
| `auth.oidc.issuer` | `""` | OIDC issuer URL (discovery + JWKS) |
| `auth.oidc.clientID` | `""` | your registered client id |
| `auth.oidc.existingSecret` | `""` | Secret with key `client-secret` |
| `auth.oidc.adminEmails` | `[]` | emails that receive the `admin` role |
| `auth.oidc.caSecret` | `""` | Secret with the issuer's **private CA** (see below) |
| `auth.oidc.caKey` | `ca.crt` | key inside `caSecret` holding the PEM |
| `hostAliases` | `[]` | `/etc/hosts` entries for the CP pod (split-horizon, see below) |

### Two gotchas for **self-hosted / homelab** issuers

Both are **no-ops for public issuers** (Let's Encrypt cert + externally reachable). They
only matter when the issuer sits behind your own gateway with a private CA:

1. **Private CA** (`auth.oidc.caSecret`). The CP validates the issuer over HTTPS. If the
   issuer's cert is signed by a private CA (e.g. cert-manager self-signed), the pod won't
   trust it → **crash-loop on start**. Mount the CA and Leloir adds it to its trust store
   *for the issuer only* (system pool intact):
   ```bash
   kubectl create secret generic leloir-oidc-ca -n leloir --from-file=ca.crt=./ca.crt
   # values: auth.oidc.caSecret: "leloir-oidc-ca"
   ```
2. **Split-horizon** (`hostAliases`). If the issuer is behind a Gateway whose *external*
   VIP is not reachable from inside the cluster (hairpin), the CP can't reach the issuer
   to fetch the JWKS. Map the issuer hostname to the gateway's **ClusterIP** (reachable
   in-cluster) — the browser keeps using the external VIP, so the issuer URL stays the same:
   ```yaml
   hostAliases:
     - ip: "10.96.0.10"          # kubectl get svc -n <gw-ns> <gw-svc> -o jsonpath='{.spec.clusterIP}'
       hostnames: ["dex.example.com"]
   ```

The whole design + a headless verification recipe is documented in
[`docs/OIDC_SETUP.md`](../../../leloir/docs/OIDC_SETUP.md) (in the backend repo).

## Safe Evaluation (Sandbox with vcluster)

We highly recommend using [vcluster](https://www.vcluster.com/) to test Leloir without polluting your main cluster — a 100% isolated ephemeral control plane, destructible in seconds:

```bash
vcluster create leloir-sandbox -n vcluster-leloir --connect                        # 1. ephemeral sandbox
helm install leloir oci://ghcr.io/villadalmine/leloir --version 0.1.1 \
  --namespace leloir-system --create-namespace --set profile=local                 # 2. install Leloir
vcluster delete leloir-sandbox -n vcluster-leloir                                   # 3. destroy without a trace
```

📖 **Step-by-step guide (requirements, verification, UI access):** [`docs/EVALUATION.md`](../../docs/EVALUATION.md).

## External Postgres

```bash
helm install leloir oci://ghcr.io/villadalmine/leloir --version 0.1.1 \
  --set postgresql.enabled=false \
  --set externalDatabase.dsn="postgres://user:pass@rds-host:5432/leloir?sslmode=require"
```

## Air-gapped / offline install

Leloir's engine needs no internet at runtime — the RAG embedder is local, and the only
hard deps are Postgres and your LLM endpoint. To install where the cluster can't reach
public registries, mirror the images to a **local registry** first:

```bash
# 1) With internet: list every image the chart pulls
bash scripts/list-images.sh
#   busybox:1.36
#   docker.io/pgvector/pgvector:pg16
#   ghcr.io/villadalmine/leloir-controlplane:latest

# 2) Copy each into your local registry (skopeo/crane, or a mirror like zot with `sync`)
skopeo copy docker://ghcr.io/villadalmine/leloir-controlplane:latest \
            docker://registry.internal/villadalmine/leloir-controlplane:latest
#   …repeat for the others…

# 3) Install pointing at your mirror (full example: examples/values-airgapped.yaml)
helm install leloir leloir/leloir -n leloir -f examples/values-airgapped.yaml \
  --set image.repository=registry.internal/villadalmine/leloir-controlplane
```

The simplest air-gapped setup uses `postgresql.enabled=false` + an existing offline
Postgres, `llm.endpoint` pointing at your internal LLM proxy, and `rag.embeddingModel=local`
— so nothing reaches outside the cluster.
