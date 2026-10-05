output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "cluster_name" {
  value = azurerm_kubernetes_cluster.aks.name
}

output "kube_config_command" {
  description = "Comando para conectar kubectl a este clúster"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.rg.name} --name ${azurerm_kubernetes_cluster.aks.name} --overwrite-existing"
}

output "verificacion" {
  description = "Comandos para probar la aplicación"
  value       = "kubectl get all -n microapp && bash ../scripts/prueba-k8s.sh"
}
