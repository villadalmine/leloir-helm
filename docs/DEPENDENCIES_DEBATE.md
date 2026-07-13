# Leloir Cluster Dependencies & Architecture Debate

This document analyzes Leloir's dependencies on the underlying Kubernetes cluster. It clarifies what is strictly required, what is optional, and the impact of missing certain cluster-level components. 

## 1. Database: Bitnami Postgres vs. CloudNativePG (CNPG)

**Current State:** The chart bundles the Bitnami Postgres subchart (`postgresql.enabled=true`) by default for a frictionless "quickstart" experience.
**The Debate:**
*   **Why Bitnami for the Chart?** It deploys a standard StatefulSet. It requires zero cluster prerequisites. A user can run `helm install` on a bare Minikube cluster and it just works.
*   **Why not CloudNativePG?** CNPG is structurally superior for High Availability, backups, and point-in-time recovery. However, CNPG requires installing a cluster-wide Operator *before* installing the database. We cannot package an Operator deployment and a Custom Resource (the `Cluster` object) cleanly inside a single application Helm chart without race conditions.
*   **Resolution / Matrix:**
    *   **Local/Testing:** Use the bundled Bitnami chart (`postgresql.enabled=true`).
    *   **Production (Redundant HA):** The cluster admin should install the CNPG operator, provision a Postgres `Cluster`, and then install Leloir with `postgresql.enabled=false` and `externalDatabase.dsn="..."`. Leloir is database-agnostic as long as it gets a valid Postgres 16 + pgvector connection string.

## 2. Networking & Security: Cilium (mTLS & SPIFFE)

**Current State:** Leloir mentions Cilium for mTLS, SPIFFE, and NetworkPolicies (containment). 
**The Debate:** Is Cilium a hard dependency? No, but it dictates the security posture.
*   **Without Cilium (Standard CNI like Calico/Flannel):**
    *   ✅ **What Works:** L7 MCP Gateway routing, budgets, RBAC enforcement, `AgentRegistration`, and AI interactions.
    *   ❌ **What Breaks (if enabled without Cilium):** `hardening.mtls.enabled=true` will fail because it relies on Cilium's mutual-auth CRDs (CiliumNetworkPolicy). `hardening.networkPolicies.enabled=true` will also fail or be ignored.
    *   ❌ **Degraded Features:** "Perimeter containment" (egress-locks for black-box agents) relies on Cilium's advanced L7 policies. Without it, you only get RBAC containment.
*   **Resolution:** Keep `hardening.*` flags `false` by default. Document that Mission Critical security features *require* Cilium.

## 3. Ingress: Standard Ingress vs. Envoy Gateway API

**Current State:** The chart supports both `ingress` and `gateway_api`.
**The Debate:**
*   **Standard Ingress (`ingress.enabled=true`):** Universally supported (NGINX, Traefik). Works out of the box on almost any cluster.
*   **Gateway API (`gateway_api.enabled=true`):** The modern Kubernetes standard (e.g., Envoy Gateway). Allows advanced traffic splitting and header manipulation.
*   **Resolution:** The chart correctly defaults to standard Ingress for maximum compatibility. If the cluster lacks a Gateway API controller, the HTTPRoute CRDs will fail to apply. The user simply chooses the one their cluster supports.

## 4. Observability & Alerting: Prometheus / Alertmanager

**Current State:** Leloir deploys a `webhookReceiver` to accept alerts.
**The Debate:** What if the cluster has no Prometheus stack?
*   ✅ **What Works:** Manual/declarative investigations (`Investigation` CRD), Scheduled investigations (`ScheduledInvestigation`), all agent governance, MCP tool routing.
*   ❌ **What Breaks:** The `AlertRoute` CRD (autonomous incident response) becomes useless because there is no Alertmanager to send webhooks to Leloir's `/api/v1/alerts` endpoint. 
*   ❌ **Degraded Features:** The Grafana dashboards provided by Leloir will have no Prometheus backend to query, so they will be blank.
*   **Resolution:** Prometheus is a **soft dependency** required only for the "Autonomous Incident Response" loop and observability dashboards. The core governance engine works perfectly without it.

---
### Summary Dependency Matrix

| Component | Required? | Fallback if Missing | Impact if Missing |
| :--- | :--- | :--- | :--- |
| **Postgres 16 + pgvector** | **YES (Hard)** | Bundled Bitnami chart | Leloir Control Plane will not start (`wait-for-db` initContainer blocks). |
| **Cilium** | NO (Soft) | Standard CNI | No mTLS SPIFFE. Egress-lock containment degrades to basic RBAC. |
| **Prometheus/Alertmanager** | NO (Soft) | None | `AlertRoute` won't trigger automatically. Dashboards remain blank. |
| **Gateway API Controller** | NO (Soft) | Standard Ingress | Advanced HTTPRoutes cannot be used; must use standard Ingress. |
| **OIDC Provider** | NO (Soft) | `auth.mode=single-user` | No SSO. Everyone logs in as the static `admin` user. |
