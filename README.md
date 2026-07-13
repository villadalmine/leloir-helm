# Leloir Helm Charts

Public Helm chart repository for the Leloir Control Plane.

## Installation

```bash
helm repo add leloir https://charts.leloir.cybercirujas.club
helm repo update
helm install leloir-cp leloir/leloir \
  --namespace leloir-system --create-namespace
```
