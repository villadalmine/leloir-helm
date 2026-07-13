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
