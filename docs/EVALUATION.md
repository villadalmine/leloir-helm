# Testing Leloir in an Ephemeral Sandbox (vcluster)

Want to evaluate Leloir **without polluting your cluster** or spinning up heavy VMs? Use
[vcluster](https://www.vcluster.com/): a fully functional Kubernetes control plane
that runs **inside a simple namespace** of your existing cluster. You create it, install
Leloir inside, play around, and **destroy it in seconds** — leaving no trace behind.

This is the ideal pattern for evaluating charts: total and disposable isolation.

## Prerequisites

- Any Kubernetes cluster (Minikube, Kind, K3s, EKS…) with `kubectl` configured.
- [`helm`](https://helm.sh/docs/intro/install/) v3.8+ (OCI support required).
- The [`vcluster`](https://www.vcluster.com/docs/get-started) CLI (`v0.20+`).

## 1. Create the ephemeral vcluster

```bash
vcluster create leloir-sandbox -n vcluster-leloir --connect
```

`--connect` automatically points your `kubectl`/`helm` to the virtual cluster. (Everything you do
now happens INSIDE the sandbox.)

## 2. Install Leloir from GHCR (OCI)

```bash
helm install leloir oci://ghcr.io/villadalmine/leloir --version 0.1.1 \
  --namespace leloir-system --create-namespace \
  --set profile=local
```

The `profile=local` setting is safe-to-test: it generates native Secrets (internal token, static admin), spins up an internal **Postgres 16 + pgvector**, and leaves
OIDC turned off. All the OSS features remain enabled (L7 gateway + budgets + RBAC).

## 3. Verify the deployment

```bash
kubectl get pods -n leloir-system
```

You should see 5 pods `1/1 Running` (control plane, gateway, memory-mcp,
webhook-receiver, postgresql). The control plane waits for Postgres via an
`initContainer` (clean startup, no CrashLoops).

Access the API/UI:

```bash
kubectl -n leloir-system port-forward svc/leloir-controlplane 8080:80
# → http://localhost:8080
```

## 4. Destroy the sandbox (no trace left)

```bash
vcluster disconnect
vcluster delete leloir-sandbox -n vcluster-leloir
```

That's it — the virtual cluster and EVERYTHING you installed inside it vanishes. Your
main host cluster remains completely untouched.

---

## GitOps evaluation with ArgoCD

Prefer GitOps? [`deploy/argocd/leloir-application.yaml`](../deploy/argocd/leloir-application.yaml)
ships two objects: a repository Secret that teaches ArgoCD to pull the chart from GHCR as
**OCI** (anonymous — chart and image are public), and an `Application` that installs it with
`profile=local`, auto-synced.

```bash
kubectl apply -f deploy/argocd/leloir-application.yaml
```

**Combine with vcluster for a fully disposable GitOps sandbox:**

```bash
# 1. Create the sandbox and register it in ArgoCD
vcluster create leloir-sandbox -n vcluster-leloir
vcluster connect leloir-sandbox -n vcluster-leloir -- argocd cluster add ...  # or: argocd cluster add vcluster_leloir-sandbox
# 2. Point the Application's destination at the vcluster (destination.name)
# 3. Sync — ArgoCD installs Leloir INSIDE the sandbox
# 4. Done evaluating? vcluster delete leloir-sandbox → everything vanishes,
#    and ArgoCD shows the Application as missing (prune on delete if you like).
```

> ⚠ **CRDs are cluster-scoped:** the chart ships 10 Leloir CRDs. Do NOT point the
> Application at a cluster that already runs Leloir — use a vcluster (its CRDs live
> inside the sandbox) or a dedicated cluster.

## For Chart Developers

If you are iterating on the chart (using local code, not the published release), use the
[`scripts/test-vcluster.sh`](../scripts/test-vcluster.sh) script: it creates a vcluster,
installs the chart **from the local directory** with `--wait`, and reports any
`CrashLoopBackOff` or volume errors. It's ideal for the CI/validation loop.

### Parity routine (maintainers)

Features are usually proven first on the maintainers' cluster and then **must** be
replicated in this official chart — the chart is what everyone else runs.
[`scripts/check-parity.sh`](../scripts/check-parity.sh) makes forgetting loud: it checks a
static manifest of required deploy-surface features (config keys, env vars, CNPs) against
the chart templates, and — when the private infra repo is available via `INFRA_ROLE` — also
scans it for config keys the chart doesn't know about. Add a line to the script's manifest
whenever a new feature grows a deploy surface, and re-test with `test-vcluster.sh`.
