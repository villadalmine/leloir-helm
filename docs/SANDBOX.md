# Sandboxed Evaluation Guide (vcluster)

Evaluate the **Leloir Control Plane** safely in any Kubernetes environment without polluting your host cluster, modifying existing CRDs, or risking production workloads.

---

## Why Use vcluster for Evaluation?

Leloir ships Custom Resource Definitions (CRDs) and cluster-scoped RBAC policies. Running your evaluation inside a [vcluster](https://www.vcluster.com/) (virtual Kubernetes cluster) provides:
- **100% Isolation:** Operates inside a single namespace on your host cluster.
- **Zero Risk:** Cannot modify or interfere with host workloads or host CRDs.
- **Instant Cleanup:** Deleting the virtual cluster removes 100% of evaluation resources cleanly.

---

## Prerequisites

- `kubectl` configured for your host cluster.
- `helm` v3.x installed.
- `vcluster` CLI (`curl -sSfL https://github.com/loft-sh/vcluster/releases/latest/download/vcluster-linux-amd64 -o vcluster && chmod +x vcluster`).

---

## Method 1: Direct Helm Evaluation (Fastest — 3 minutes)

### Step 1: Create the Virtual Cluster
```bash
vcluster create leloir-eval --namespace vcluster-leloir
```
This automatically switches your current `kubectl` context to the newly created `vcluster`.

### Step 2: Install Leloir from GHCR (OCI)
```bash
helm install leloir oci://ghcr.io/villadalmine/leloir/leloir-controlplane \
  --version 0.4.3 \
  --namespace leloir-system \
  --create-namespace
```

### Step 3: Verify the Installation
```bash
kubectl get pods -n leloir-system
kubectl get crds
```
You will see the Leloir Gateway, Audit logger, and Control Plane components running cleanly inside the virtual cluster.

### Step 4: Cleanup
When you are finished evaluating:
```bash
vcluster delete leloir-eval --namespace vcluster-leloir
```
Your host cluster is restored to its exact previous state without any leftover CRDs or orphan namespaces.

---

## Method 2: GitOps Evaluation via ArgoCD

If you use ArgoCD, you can deploy Leloir into your virtual cluster using our turn-key GitOps application:

1. **Register your vcluster in ArgoCD:**
   ```bash
   argocd cluster add vcluster-leloir_leloir-eval_vcluster-leloir --name leloir-sandbox
   ```

2. **Deploy the Leloir Application:**
   ```bash
   kubectl apply -f deploy/argocd/leloir-application.yaml
   ```

ArgoCD will pull the public Helm OCI chart from GHCR and sync Leloir automatically into your sandboxed virtual cluster.
