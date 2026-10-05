#!/usr/bin/env bash
# ==============================================================================
# deploy-local.sh - Despliegue del Problema 3 en entorno local con KinD o Minikube
#
# Útil para probar y ensayar la sustentación SIN gastar créditos de Azure.
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="$(cd "$SCRIPT_DIR/../manifests" && pwd)"

echo "======================================================================="
echo "   DESPLIEGUE LOCAL DE KUBERNETES (KIND / MINIKUBE)"
echo "======================================================================="

if command -v kind >/dev/null 2>&1; then
  echo "[1/4] Usando KinD para crear clúster local con mapeo de puerto 80..."
  
  cat <<EOF | kind create cluster --name microapp-cluster --config=- || true
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
EOF

  echo "[2/4] Instalando Ingress NGINX para KinD..."
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.15.1/deploy/static/provider/kind/deploy.yaml
  
  echo "Esperando que ingress-nginx controller esté listo..."
  kubectl wait --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=120s || true

elif command -v minikube >/dev/null 2>&1; then
  echo "[1/4] Iniciando Minikube..."
  minikube status >/dev/null 2>&1 || minikube start
  
  echo "[2/4] Habilitando addon de Ingress en Minikube..."
  minikube addons enable ingress
else
  echo "ADVERTENCIA: Ni 'kind' ni 'minikube' fueron detectados en el PATH local."
  echo "Si vas a desplegar directamente en Azure AKS, usa: bash deploy-aks.sh"
  exit 1
fi

echo "[3/4] Aplicando manifiestos de la aplicación en namespace microapp..."
kubectl apply -f "$MANIFESTS_DIR/00-namespace.yaml"
kubectl apply -f "$MANIFESTS_DIR/01-users.yaml"
kubectl apply -f "$MANIFESTS_DIR/02-products.yaml"
kubectl apply -f "$MANIFESTS_DIR/03-orders.yaml"
kubectl apply -f "$MANIFESTS_DIR/04-ingress.yaml"

echo "[4/4] Esperando a que todos los pods estén en estado Ready..."
kubectl wait --namespace microapp --for=condition=ready pod --all --timeout=120s

echo ""
echo "======================================================================="
echo "   ¡CLÚSTER LOCAL LISTO Y APLICACIÓN DESPLEGADA!"
echo "   Prueba ahora ejecutando: bash '$SCRIPT_DIR/prueba-k8s.sh'"
echo "======================================================================="
