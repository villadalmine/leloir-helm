# Leloir Helm Charts

Public Helm chart repository for the Leloir Control Plane.

## Installation

```bash
helm install leloir oci://ghcr.io/villadalmine/leloir/leloir-controlplane \
  --version 0.2.0 \
  --namespace leloir-system \
  --create-namespace
```

## Documentation & Roadmap

All technical documentation, matrices (Support, Optionality, Memory Analysis), and the live strategic Roadmap are available at our public site:

👉 **[leloir.io](https://villadalmine.github.io/leloir-site/)** (Coming Soon)

## Sandboxed Evaluation

Want to evaluate Leloir safely without polluting your host cluster? 
Check out our GitOps flavor ([ArgoCD Application over OCI](deploy/argocd/leloir-application.yaml)) you can combine with vcluster for a fully disposable sandbox.
