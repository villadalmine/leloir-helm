# Leloir — Optionality & Degradation Matrix

For **every pluggable component category**: what Leloir defaults to, what
alternatives work, and — the important column — **what happens to the product if
you don't use it, or swap it.** This is the honest "you are not locked in"
document. It extends [DEPENDENCIES_DEBATE.md](DEPENDENCIES_DEBATE.md) with an
impact lens for each category.

Legend for **Impact if absent/swapped**:
- 🟢 **None** — the core is unaffected; feature is additive.
- 🟡 **Degraded** — a specific capability weakens or turns off; core keeps working.
- 🔴 **Blocked** — the product (or a whole loop) does not function.

Design principle: **the differentiator is the governance control plane, not any
one component.** Everything below the control plane is swappable. The only 🔴 in
the whole matrix is Postgres (state) and an LLM endpoint (there is no
investigation without a model to run).

---

## 1. Memory / agent state

Leloir has **native memory** and treats external memory systems as **plug-ins
through the MCP Gateway** (an `MCPServer` CRD — the same governed path as any
tool). Nothing about memory is hardcoded.

| Option | How it plugs | Status | Impact if absent |
|---|---|---|---|
| **Native: `leloir-memory-mcp`** (spec-m18) | Built-in MCP server, per-tenant remember/recall/forget | ✅ Proven | 🟡 Without it, agents lose durable key/value recall across calls |
| **Native: RAG episodic** (spec-m22, pgvector) | Built-in; captures alert→cause→fix, recalls by cosine similarity as an auto-runbook | ✅ Proven | 🟡 Without it, no "we've seen this incident before" auto-runbook |
| **Honcho** (Plastic Labs) | External; via `MCPServer` CRD + `leloir-honcho-mcp` adapter (chart `memory.honcho.enabled`). Peer-centric, background deriver, NL dialectic | ✅ **MEASURED 4/4 (2026-07-14)** — recall HIT 330 ms, dialectic cites rule+incident, deriver 9–11 observations (free-tier models derive ZERO: it needs a strong model) | 🟢 None on the core — the *upgrade* for synthesis/continuity |
| **mem0** | External HTTP | ⚠️ **MEASURED (2026-07-14): runs only patched** (8 blockers OOTB: unconditional neo4j, hardcoded models, no psycopg…). Recall HIT but it atomizes facts — the incident-id lands apart from the lesson | 🟢 None on core; not a recommendable default |
| **Zep / Graphiti** | External; temporal knowledge graph | 🔴 Out for self-host — Community Edition deprecated (2026); platform is SaaS-only | 🟢 None on core |
| **Letta (MemGPT)** | External; agent-managed memory OS | 🟡 **MEASURED (2026-07-14):** archival store/search sound via API (recall HIT), but the agent cannot reach its own archival in-chat even when asked (synthesis fail) | 🟢 None on core; fine for scratch memory, not synthesis |
| **NO memory at all** | — | — | 🟡 **Degraded, not blocked.** Every investigation is still self-contained and correct; you lose cross-incident learning (auto-runbook) and cross-session continuity. The governance, budgets, RBAC, audit, containment all work identically. |

**Why memory matters MOST for black-box agents (Modo 2):** a contained
third-party agent (e.g. HolmesGPT) can't be modified — external memory is the
*only* way to give it continuity, and it attaches through the **MCP facade**
like any other tool. So a black-box agent gains "what did we learn last time"
without touching its runtime. For SDK-native agents (Modo 1/3) memory is a
quality boost on top of the native RAG.

**Recommendation (preliminary — spike pending):** keep `leloir-memory-mcp` + RAG
as the always-on baseline (zero external deps). Position Honcho as the
**reference external memory** (it's already deployed here and wired to the
governed LLM layer) documented as an `MCPServer` example — richest for
peer-modeling and the black-box continuity story. mem0/Zep/Letta stay as
documented alternatives. **No memory is a paid lock-in** anywhere — all of these
are OSS/self-hostable. Running Honcho **v3.0.6**; latest is **v3.0.12** (same
minor — worth a routine bump, not urgent).

---

## 2. Networking / CNI

| Option | Status | Impact if absent/swapped |
|---|---|---|
| **Any CNI** (Calico, Flannel, cloud CNIs) | ✅ Proven (core) | 🟢 Core governance, gateway, budgets, RBAC, audit all work |
| **Cilium — CiliumNetworkPolicies** (`hardening.networkPolicies`) | ✅ Proven | 🟡 Without Cilium: no internal-listener lock, no egress-lock containment → black-box **containment degrades to RBAC-only** (documented, honest scorecard reports it) |
| **Cilium + SPIRE — SPIFFE mTLS** (`hardening.mtls`) | ✅ Proven | 🟡 Without it: no mutual-auth on the tools/DB seams. Traffic still governed at L7 by the gateway; you lose the L3/L4 Zero-Trust layer |
| **NO Cilium** | — | 🟡 **Degraded, not blocked.** You get RBAC + L7 governance; you lose network-level containment and mTLS. The scorecard says so — no fake "contained" badge. |

## 3. Observability & telemetry

| Option | Status | Impact if absent/swapped |
|---|---|---|
| **OpenTelemetry ingest** (`gen_ai` spans) | ✅ Proven | 🟡 Without OTEL: agents that only emit OTEL aren't auto-metered → those show reduced cost/token visibility. Agents on the SDK/gateway path are metered anyway |
| **Prometheus metrics** | ✅ Proven | 🟡 Without Prometheus: Grafana dashboards go blank; governance still enforced (metrics are for humans, not for control) |
| **Grafana dashboards** | ✅ Proven | 🟢 Pure visualization — nothing enforced depends on it |
| **NO observability stack** | — | 🟡 **Degraded, not blocked.** Governance, budgets (hard cut-offs), audit, containment all enforce without any metrics backend. You just fly with fewer instruments. The **audit WORM log is the source of truth**, independent of Prometheus/OTEL. |

## 4. Alert sources (autonomous loop)

| Option | Status | Impact if absent |
|---|---|---|
| **Alertmanager → webhook receiver** | ✅ Proven | — |
| **Slack/PagerDuty/Azure/CloudWatch → receiver** | 🟡 Coded | — |
| **NO alert source (Prometheus/Alertmanager)** | — | 🟡 **Degraded.** The autonomous incident-response loop (`AlertRoute`) can't self-trigger. Declarative `Investigation`/`ScheduledInvestigation` CRDs and manual triggers work fully — the governance engine doesn't need alerts to operate |

## 5. LLM layer

| Option | Status | Impact if absent/swapped |
|---|---|---|
| **litellm proxy** (recommended) | ✅ Proven | 🟢 vs alternatives — unlocks per-tenant virtual keys, hard budget cut-offs (429), spend read-back, quarantine actuator |
| **Direct provider key** (OpenAI-compat) | ✅ Proven | 🟡 Works, but no virtual-key isolation; budgets still enforced at Leloir's layer |
| **Ollama / local models** | ✅ Proven | 🟢 Fully offline path |
| **NO LLM endpoint** | — | 🔴 **Blocked.** There is no investigation without a model to run. This is the #1 functional dependency (see DEPENDENCIES_DEBATE §5). Everything deploys, but the first real investigation fails at the model call |

## 6. Identity / Auth

| Option | Status | Impact if absent |
|---|---|---|
| **Single-user (static admin)** | ✅ Proven | Default; fine for eval/homelab |
| **Generic OIDC** (Dex, GitHub, Google, Keycloak, Entra, Cognito…) | 🟡 Coded (Dex next) | See [SUPPORT_MATRIX](SUPPORT_MATRIX.md) for the provider rollout |
| **NO OIDC** | — | 🟡 **Degraded, not blocked.** Everyone is the static `admin`; no SSO, no per-user RBAC subjects. Tenant isolation (by namespace/API key) is unaffected |

## 7. Ingress / exposure

| Option | Status | Impact if absent |
|---|---|---|
| **Gateway API (HTTPRoute)** | ✅ Proven | — |
| **Standard Ingress (NGINX/Traefik)** | 🟡 Coded | — |
| **Neither (ClusterIP + port-forward)** | ✅ Proven | 🟢 Evaluation mode works; you just don't get a public URL |

## 8. Database — the one hard dependency

| Option | Status | Impact if absent |
|---|---|---|
| **Postgres 16 + pgvector** (bundled or external DSN) | ✅ Proven | 🔴 **Blocked.** State, audit, RAG all live here; the control plane won't start without it (`wait-for-db` initContainer). This and the LLM endpoint are the only two 🔴 in the whole matrix |

## 9. GitOps / packaging

| Option | Status | Impact if absent |
|---|---|---|
| **Helm (OCI, GHCR)** | ✅ Proven | — |
| **ArgoCD / FluxCD** | 🟡 Coded / 🗓 Planned | 🟢 Convenience — `helm install` works standalone |
| **Own registry (Harbor mirror)** | 🗓 Planned (role prepared) | 🟢 GHCR is canonical; Harbor is an optional self-hosted mirror |

---

## The one-sentence version

**Two hard dependencies (Postgres + an LLM endpoint); everything else degrades
gracefully and says so on the honest scorecard.** Memory, CNI security, metrics,
alert sources, SSO, ingress, GitOps and the registry are all swappable or
omittable — because the product is the governance control plane, and that runs
on the two hard dependencies alone.
