# Leloir Helm Chart

El chart público **standalone** de [Leloir](https://github.com/villadalmine/leloir)
— el control plane de governance para agentes de IA en Kubernetes.

```bash
# Instalación (perfil local, Postgres+pgvector bundled)
helm install leloir oci://ghcr.io/villadalmine/leloir --version 0.1.0 --namespace leloir --create-namespace
```

## Qué deploya

Un solo chart, todo el stack: **control plane** (+ listener interno), **MCP Gateway**,
**memory-mcp**, **webhook-receiver** (Alertmanager → Leloir), los **10 CRDs**, RBAC
(watcher cluster-wide read-only), y **Postgres 16 + pgvector** (subchart Bitnami,
opcional).

## Modelo open-core (license-ready)

Todo lo **OSS** está prendido por defecto y es gratis (gateway L7 + budgets + RBAC +
dashboards). Las features **licenciadas** (RAG, Anomaly Quarantine, mTLS/SPIFFE) se
gatean por la presencia de `license.key` en los Secrets — el core las habilita/desactiva
en **runtime** (la validación criptográfica es futura). El chart sólo transporta la llave:

```yaml
license:
  key: ""                 # vacío = OSS; con llave = features licenciadas (runtime)
```

## Valores clave

| Valor | Default | Descripción |
|-------|---------|-------------|
| `profile` | `local` | `local` (seguro-para-probar) o `corporate` (OIDC + Postgres externo) |
| `postgresql.enabled` | `true` | Postgres+pgvector bundled; `false` → `externalDatabase.dsn` |
| `postgresql.auth.password` | `leloir-change-me` | ⚠ override en prod |
| `image.repository` | `ghcr.io/villadalmine/leloir-controlplane` | privada — inyectá `imagePullSecrets` |
| `ingress.enabled` | `true` | Ingress estándar; o `gateway_api.enabled` para HTTPRoute |
| `hardening.mtls.enabled` | `false` | mTLS SPIFFE (Mission Critical; requiere Cilium) |
| `rag.enabled` / `anomaly.*` | on | features Team (runtime las gatea por licencia) |

## Evaluación Segura (Sandbox con vcluster)

Recomendamos usar [vcluster](https://www.vcluster.com/) para probar Leloir sin ensuciar tu cluster principal — un plano de control efímero 100% aislado, destruible en segundos:

```bash
vcluster create leloir-sandbox -n vcluster-leloir --connect                        # 1. sandbox efímero
helm install leloir oci://ghcr.io/villadalmine/leloir --version 0.1.0 \
  --namespace leloir-system --create-namespace --set profile=local                 # 2. instalar Leloir
vcluster delete leloir-sandbox -n vcluster-leloir                                   # 3. destruir sin rastro
```

📖 **Guía paso a paso (requisitos, verificación, acceso a la UI):** [`docs/EVALUATION.md`](../../docs/EVALUATION.md).

## Postgres externo

```bash
helm install leloir oci://ghcr.io/villadalmine/leloir --version 0.1.0 \
  --set postgresql.enabled=false \
  --set externalDatabase.dsn="postgres://user:pass@rds-host:5432/leloir?sslmode=require"
```

> Draft — revisor: Antigravity. Ver `IMPLEMENTATION_PLAN.md`.
