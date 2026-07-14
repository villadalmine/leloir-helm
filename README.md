# Leloir Helm Charts

Public Helm chart repository for the Leloir Control Plane.

## Installation

```bash
helm install leloir oci://ghcr.io/villadalmine/leloir \
  --version 0.1.1 \
  --namespace leloir-system \
  --create-namespace
```

## Support & Optionality

- **[Support Matrix](docs/SUPPORT_MATRIX.md)** — what works with what (OIDC providers, CNIs, LLM backends, agents, distros) with honest badges (proven / coded / planned).
- **[Optionality & Degradation Matrix](docs/OPTIONALITY_MATRIX.md)** — for each pluggable component (memory/Honcho, CNI/Cilium, monitoring/OTEL, LLM, auth…): what happens to the product if you don't use it or swap it. Only two hard dependencies; everything else degrades gracefully.
- **[Memory Analysis](docs/MEMORY_ANALYSIS.md)** — deep-dive + live results (Honcho, our default) and honest framework comparison (Honcho / mem0 / Zep / Letta) with metrics and real cases where memory changes the outcome.

## Sandboxed Evaluation

Want to evaluate Leloir safely without polluting your host cluster? 
Check out our **[Ephemeral Sandbox Guide (vcluster)](docs/EVALUATION.md)** for testing the chart in total isolation — including a **GitOps flavor** ([ArgoCD Application over OCI](deploy/argocd/leloir-application.yaml)) you can combine with vcluster for a fully disposable sandbox.
