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

Want to evaluate Leloir safely without polluting your host cluster or modifying host CRDs? 
Read our step-by-step [Sandboxed Evaluation Guide (vcluster)](docs/EVALUATION.md) to run a 100% disposable evaluation using `vcluster` or GitOps with ArgoCD.
