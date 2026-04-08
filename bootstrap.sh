#!/bin/bash
# bootstrap.sh — Levanta la infraestructura base del cluster telegram-bots desde cero.
#
# Requisitos previos:
#   brew install k3d helm kubectl
#   Docker corriendo
#
# Uso:
#   ./bootstrap.sh

set -e

CLUSTER_NAME="telegram-bots"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "🏗️  k8s-home-cluster bootstrap"
echo "================================"

# —— 1. Verificar dependencias ——————————————————————————————————————————————
for cmd in k3d helm kubectl docker; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "❌ '$cmd' no está instalado."
    echo "   Instala con: brew install $cmd"
    exit 1
  fi
done

# —— 2. Cluster k3d ————————————————————————————————————————————————————————
if k3d cluster list | grep -q "$CLUSTER_NAME"; then
  echo "✅ Cluster '$CLUSTER_NAME' ya existe"
else
  echo "🚀 Creando cluster k3d '$CLUSTER_NAME'..."
  k3d cluster create --config "$SCRIPT_DIR/cluster/k3d-config.yaml"
fi

kubectl config use-context "k3d-${CLUSTER_NAME}"

# —— 3. LocalStack ————————————————————————————————————————————————————————
echo "📦 Desplegando LocalStack..."
kubectl apply -f "$SCRIPT_DIR/apps/localstack/localstack.yaml"
kubectl rollout status deployment/localstack -n localstack --timeout=120s

# —— 4. External Secrets Operator (ESO) ———————————————————————————————————
echo "🔑 Instalando External Secrets Operator..."
helm repo add external-secrets https://charts.external-secrets.io
helm repo update
helm upgrade --install external-secrets external-secrets/external-secrets \
  -n external-secrets --create-namespace \
  --values "$SCRIPT_DIR/apps/external-secrets/values.yaml" \
  --wait

echo ""
echo "✅ Infraestructura base lista."
echo ""
echo "Próximos pasos:"
echo "  - Crear el secret en LocalStack para cada bot:"
echo "      aws --endpoint-url=http://localhost:4566 secretsmanager create-secret \\"
echo "          --name <bot>/telegram-token \\"
echo "          --secret-string '{\"TELEGRAM_BOT_TOKEN\":\"TU_TOKEN\"}'"
echo "  - Desplegar cada bot desde su propio repo."
