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

## For Chart Developers

If you are iterating on the chart (using local code, not the published release), use the
[`scripts/test-vcluster.sh`](../scripts/test-vcluster.sh) script: it creates a vcluster,
installs the chart **from the local directory** with `--wait`, and reports any
`CrashLoopBackOff` or volume errors. It's ideal for the CI/validation loop.

> Future idea: a **self-service "try it out" dev-environment** (vcluster + ArgoCD)
> packaged together, so a user can spin up Leloir with a single click.
