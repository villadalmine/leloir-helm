#!/usr/bin/env bash
set -e

CLUSTER_NAME="leloir-test-vcluster"
NAMESPACE="vcluster-leloir"
HELM_RELEASE="leloir-core"
CHART_DIR="$(dirname "$0")/../charts/leloir"

echo "============================================================"
echo "🚀 1. Creating ephemeral vcluster ($CLUSTER_NAME)..."
echo "============================================================"
# Create the virtual cluster and update local kubeconfig to point to it
vcluster create $CLUSTER_NAME -n $NAMESPACE --update-current=true

echo "============================================================"
echo "📦 2. Installing Leloir Chart in vcluster..."
echo "============================================================"
# Change to the chart root so helm resolves dependencies correctly
cd "$CHART_DIR"

# Update dependencies (e.g. Postgres from Bitnami)
helm dependency update

# Install the chart and wait for all pods to be ready
helm upgrade --install $HELM_RELEASE . \
  --namespace leloir-system --create-namespace \
  --set profile=local \
  --wait --timeout 5m

echo "============================================================"
echo "✅ 3. Test finished. Pods running in vcluster:"
echo "============================================================"
kubectl get pods -n leloir-system

echo "============================================================"
echo "🧹 4. To destroy this ephemeral environment, run:"
echo "vcluster delete $CLUSTER_NAME -n $NAMESPACE"
echo "============================================================"
