#!/usr/bin/env bash
# ==============================================================================
# destroy-aks.sh - Destruye inmediatamente los recursos de AKS en Azure
#
# ¡IMPORTANTE!: Ejecuta este script tan pronto termines tu sustentación o pruebas
# para evitar que se consuman los 100 USD de tu suscripción de estudiante.
# ==============================================================================

RG_NAME="${RG_NAME:-rg-microapp-aks}"

echo "======================================================================="
echo "   ADVERTENCIA: DESTRUCCIÓN DE RECURSOS EN AZURE"
echo "   Grupo de recursos a eliminar: $RG_NAME"
echo "======================================================================="

read -p "¿Estás seguro de eliminar el Resource Group '$RG_NAME'? (s/N): " CONFIRM
if [[ "$CONFIRM" =~ ^[sSyY]$ ]]; then
  echo "Eliminando Resource Group '$RG_NAME' de Azure en segundo plano..."
  az group delete --name "$RG_NAME" --yes --no-wait
  echo "Comando enviado a Azure. La eliminación tomará un par de minutos."
  echo "Tu suscripción dejará de generar cobros por este clúster."
else
  echo "Operación cancelada. Los recursos siguen activos."
fi
