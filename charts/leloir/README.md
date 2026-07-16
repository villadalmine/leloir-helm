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
     - ip: "10.43.78.4"          # kubectl get svc -n <gw-ns> <gw-svc> -o jsonpath='{.spec.clusterIP}'
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
