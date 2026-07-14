# Leloir — Support Matrix

What works with what, **honestly**. Every row carries one of these statuses:

| Badge | Meaning |
|---|---|
| ✅ **Proven** | Exercised live (production cluster and/or E2E suite) |
| 🟡 **Coded** | Implemented + unit/template-tested, not yet proven live |
| 🗓 **Planned** | On the roadmap, not built |
| ❌ **No** | Not supported / out of scope |

> Maintainers: when a feature gets proven, flip its badge in the same PR.
> This matrix is the single public source of truth for compatibility.

## Identity / Authentication (OIDC & friends)

Leloir speaks **generic OIDC** (any spec-compliant issuer) plus static single-user
and API keys. Provider rows below reflect what has actually been *tested*, not
what "should work". Rollout order favors the easiest to test first.

| Provider / method | Status | Notes |
|---|---|---|
| Single-user (static admin) | ✅ Proven | Default in `profile: local` |
| API keys (`lk_…`, Pro API) | ✅ Proven | Per-tenant metering, rate limits |
| Generic OIDC (code path) | 🟡 Coded | `auth.mode: oidc` — issuer/clientID/secret + `adminEmails` |
| [Dex](https://dexidp.io/) | 🗓 Planned (next) | Easiest to test: runs in-cluster, no external account; the designed `local` OIDC profile |
| GitHub | 🗓 Planned | Easy: one OAuth App; ideal for OSS users |
| Google | 🗓 Planned | Easy: one OAuth client |
| Keycloak | 🗓 Planned | Self-hosted standard; generic OIDC should apply |
| Azure AD / Entra ID | 🗓 Planned | The designed `corporate` profile |
| AWS Cognito | 🗓 Planned | Cloud OIDC |
| GCP Identity Platform | 🗓 Planned | Cloud OIDC |
| Okta | 🗓 Planned | Enterprise |
| [OpenUnison](https://openunison.github.io/) | 🗓 Planned | Enterprise K8s SSO; also an OIDC provider |
| SAML | ❌ No | Bridge through an IdP (Dex/Keycloak translate SAML→OIDC) |

## Networking / CNI

The **core runs on any CNI**. Cilium is optional and only unlocks the
network-security extras.

| CNI / capability | Status | Notes |
|---|---|---|
| Any CNI (core: gateway, budgets, RBAC, audit, RAG…) | ✅ Proven | No network prerequisites |
| Cilium — CiliumNetworkPolicies (`hardening.networkPolicies`) | ✅ Proven | Internal-listener lock, egress-locks (containment) |
| Cilium + SPIRE — SPIFFE mTLS (`hardening.mtls`) | ✅ Proven | Paths live today: **agents→gateway (:8082, the whole tools seam)**, gateway→control-plane internal, control-plane/memory-mcp→Postgres; requires Cilium installed with mutual-auth/SPIRE |
| Calico / Flannel / cloud CNIs | ✅ Proven (core) / ❌ (mTLS & egress-lock) | Containment degrades to RBAC-only; documented behavior |
| Standard NetworkPolicy fallback | 🗓 Planned | CNP-equivalents where expressible |

## Ingress / exposure

| Method | Status | Notes |
|---|---|---|
| Gateway API (HTTPRoute) | ✅ Proven | Envoy Gateway in the reference cluster |
| Standard Ingress (NGINX/Traefik/…) | 🟡 Coded | Chart default; template-validated |
| Port-forward / ClusterIP only | ✅ Proven | Evaluation mode |

## Observability & alert sources

| Integration | Status | Notes |
|---|---|---|
| Prometheus metrics (control plane + gateway) | ✅ Proven | Per-tenant governance metrics |
| Grafana dashboards | ✅ Proven | Fleet/CISO + 10-metric panels |
| OpenTelemetry ingest (`gen_ai` spans) | ✅ Proven | Agents that emit OTEL are metered without an adapter |
| Alertmanager → webhook receiver | ✅ Proven | Real kube-prometheus-stack, end to end |
| Slack / PagerDuty / Azure Monitor / CloudWatch → receiver | 🟡 Coded | Translators implemented in the webhook receiver |
| **SIEM audit streaming** (generic HTTP sink) | ✅ Proven (tests) | Fail-open batch forwarder; pair with vector/fluent-bit for Splunk/Elastic |
| Syslog sink | 🗓 Planned | Use a collector meanwhile |

## LLM layer

| Backend | Status | Notes |
|---|---|---|
| litellm proxy (recommended for governance) | ✅ Proven | Per-tenant virtual keys, hard budget cut-offs (429), spend read-back, quarantine actuator |
| Direct OpenAI-compatible endpoint | ✅ Proven | Bring your own key |
| Google Gemini (via litellm) | ✅ Proven | Reference demo model |
| Ollama (local models) | ✅ Proven | Adapter + zero-key local RAG embedder |
| Anthropic (via litellm / openai-compat) | 🟡 Coded | Standard litellm route |
| Envoy AI Gateway driver | 🗓 Planned | Spiked (2-layer chain); increment plan documented |

## Agents (BYO-agent adapters)

| Agent | Status | Notes |
|---|---|---|
| HolmesGPT | ✅ Proven | Including black-box containment (Modo 2) |
| kagent (via A2A standard) | ✅ Proven | No vendor adapter — standards, not vendors |
| k8sgpt | ✅ Proven | Conformance adapter |
| Any OpenAI-compatible agent | ✅ Proven | `openaicompat` adapter |
| OpenCode | ✅ Proven | Living-demo mode 4 |
| Claude Code | 🟡 Coded | Adapter exists |
| Your agent (SDK) | ✅ Proven | AgentAdapter SDK + conformance suite |

## Database

| Backend | Status | Notes |
|---|---|---|
| Postgres 16 + pgvector (bundled, Bitnami subchart) | ✅ Proven | The only **hard** dependency |
| External Postgres (DSN) | ✅ Proven | RDS/CloudSQL/CNPG — anything Postgres 16 + pgvector |
| CloudNativePG | 🟡 Coded (docs) | Recommended HA path; install operator, pass DSN |

## Kubernetes distributions & architectures

| Target | Status | Notes |
|---|---|---|
| K3s | ✅ Proven | Reference cluster |
| Minikube / Kind | 🟡 Coded | Chart designed for it (`profile: local`); vcluster script |
| vcluster (ephemeral eval) | ✅ Proven | See [EVALUATION.md](EVALUATION.md) |
| EKS / GKE / AKS | 🗓 Planned (verify) | No known blockers; unproven |
| **arm64** | ✅ Proven | Reference cluster is ARM |
| **amd64** | ✅ Proven | Native amd64 build in CI (~2 min, no QEMU) pushed to `ghcr.io/villadalmine/leloir-controlplane:amd64`. Unified multi-arch manifest (amd64+arm64 under one tag) deferred to post-public (free arm64 runners) |

## GitOps / packaging

| Method | Status | Notes |
|---|---|---|
| Helm (OCI, GHCR) | ✅ Proven | `oci://ghcr.io/villadalmine/leloir` |
| ArgoCD (OCI Application) | 🟡 Coded | [`deploy/argocd/`](../deploy/argocd/leloir-application.yaml); pair with vcluster |
| FluxCD | 🗓 Planned | HelmRepository OCI should apply |
| Air-gapped install | 🗓 Planned | Offline images + tested no-egress runbook |
