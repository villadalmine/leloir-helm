#!/usr/bin/env bash
set -e

CLUSTER_NAME="leloir-test-vcluster"
NAMESPACE="vcluster-leloir"
HELM_RELEASE="leloir-core"
CHART_DIR="$(dirname "$0")/../charts/leloir"

echo "============================================================"
echo "🚀 1. Creando vcluster efímero ($CLUSTER_NAME)..."
echo "============================================================"
# Creamos el cluster virtual y actualizamos el kubeconfig local para apuntar a él
vcluster create $CLUSTER_NAME -n $NAMESPACE --update-current=true

echo "============================================================"
echo "📦 2. Instalando Chart de Leloir en vcluster..."
echo "============================================================"
# Hacemos cd a la raíz del chart para asegurar que helm resuelva bien las dependencias
cd "$CHART_DIR"

# Actualizar dependencias (por ejemplo, Postgres de bitnami)
helm dependency update

# Instalamos el chart esperando que todos los pods levanten
helm upgrade --install $HELM_RELEASE . \
  --namespace leloir-system --create-namespace \
  --set profile=local \
  --wait --timeout 5m

echo "============================================================"
echo "✅ 3. Test finalizado. Pods corriendo en vcluster:"
echo "============================================================"
kubectl get pods -n leloir-system

echo "============================================================"
echo "🧹 4. Para destruir este entorno efímero, corre:"
echo "vcluster delete $CLUSTER_NAME -n $NAMESPACE"
echo "============================================================"
