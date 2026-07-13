# Leloir Helm Charts

Public Helm chart repository for the Leloir Control Plane.

## Installation

```bash
helm install leloir oci://ghcr.io/villadalmine/leloir \
  --version 0.1.1 \
  --namespace leloir-system \
  --create-namespace
```

## Sandboxed Evaluation

Want to evaluate Leloir safely without polluting your host cluster? 
Check out our **[Ephemeral Sandbox Guide (vcluster)](docs/EVALUATION.md)** for testing the chart in total isolation.
