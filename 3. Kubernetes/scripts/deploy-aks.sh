#!/usr/bin/env bash
set -e

# ==============================================================================
# deploy-aks.sh - Despliegue completo del Problema 3 en Azure Kubernetes Service
#
# Puede ejecutarse desde:
#   1. Azure Cloud Shell (recomendado, ya tiene az y kubectl autenticados)
#   2. Tu terminal local con Azure CLI instalada
#
# NOTA DE COSTOS: Este script crea recursos en Azure. Apenas termines de sustentar
# o probar, ejecuta inmediatamente: bash destroy-aks.sh
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="$(cd "$SCRIPT_DIR/../manifests" && pwd)"

# Variables configurables (por defecto usa una región económica permitida para estudiantes)
RG_NAME="${RG_NAME:-rg-microapp-aks}"
CLUSTER_NAME="${CLUSTER_NAME:-aks-microapp}"
LOCATION="${LOCATION:-eastus}"
NODE_COUNT="${NODE_COUNT:-2}"
NODE_SIZE="${NODE_SIZE:-Standard_B2s}"   # Tamaño económico para suscripción Student

echo "======================================================================="
echo "   INICIANDO DESPLIEGUE EN AZURE KUBERNETES SERVICE (AKS)"
echo "   Grupo de Recursos: $RG_NAME"
echo "   Cluster AKS:       $CLUSTER_NAME"
echo "   Región:            $LOCATION"
echo "   Tamaño de VM:      $NODE_SIZE (Nodos: $NODE_COUNT)"
echo "======================================================================="

# 1. Validar sesión de Azure
echo "[1/7] Verificando cuenta de Azure activa..."
az account show --output table || {
  echo "ERROR: Debes iniciar sesión con 'az login' antes de continuar."
  exit 1
}

# 2. Registrar Proveedores de Recursos requeridos
echo "[2/7] Verificando registro de Microsoft.Compute y Microsoft.ContainerService..."
az provider register --namespace Microsoft.Compute >/dev/null 2>&1 || true
az provider register --namespace Microsoft.ContainerService >/dev/null 2>&1 || true

# 3. Crear Grupo de Recursos
echo "[3/7] Creando Resource Group '$RG_NAME' en '$LOCATION'..."
az group create --name "$RG_NAME" --location "$LOCATION" --output table

# 4. Crear el Clúster de AKS
echo "[4/7] Creando cluster AKS '$CLUSTER_NAME' (puede tardar 4 a 7 minutos)..."
az aks create \
  --resource-group "$RG_NAME" \
  --name "$CLUSTER_NAME" \
  --node-count "$NODE_COUNT" \
  --node-vm-size "$NODE_SIZE" \
  --enable-managed-identity \
  --generate-ssh-keys \
  --output table

# 5. Obtener credenciales de kubectl
echo "[5/7] Obteniendo credenciales para kubectl..."
az aks get-credentials --resource-group "$RG_NAME" --name "$CLUSTER_NAME" --overwrite-existing

# 6. Instalar Ingress Controller (ingress-nginx)
echo "[6/7] Instalando Ingress Controller NGINX..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.15.1/deploy/static/provider/cloud/deploy.yaml

echo "Esperando que el Ingress Controller esté listo y reciba IP pública..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=180s || true

# 7. Aplicar Manifiestos de la Aplicación
echo "[7/7] Aplicando manifiestos de la aplicación (Namespace, Deployments, Services, Ingress)..."
kubectl apply -f "$MANIFESTS_DIR/00-namespace.yaml"
kubectl apply -f "$MANIFESTS_DIR/01-users.yaml"
kubectl apply -f "$MANIFESTS_DIR/02-products.yaml"
kubectl apply -f "$MANIFESTS_DIR/03-orders.yaml"
kubectl apply -f "$MANIFESTS_DIR/04-ingress.yaml"

echo "Esperando que los pods de microapp pasen a Running..."
kubectl wait --namespace microapp \
  --for=condition=ready pod \
  --all \
  --timeout=120s

echo ""
echo "======================================================================="
echo "   ¡DESPLIEGUE COMPLETADO CON ÉXITO!"
echo "======================================================================="
echo "Ejecuta el script de pruebas para verificar el balanceo y rutas:"
echo "   bash '$SCRIPT_DIR/prueba-k8s.sh'"
echo ""
echo "Para ver la IP Externa del Ingress Controller:"
echo "   kubectl get service ingress-nginx-controller -n ingress-nginx"
echo "======================================================================="
