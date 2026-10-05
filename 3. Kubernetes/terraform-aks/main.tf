# Grupo de Recursos en Azure
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# Clúster de Azure Kubernetes Service (AKS)
resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = var.dns_prefix

  default_node_pool {
    name       = "default"
    node_count = var.node_count
    vm_size    = var.vm_size
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "Microproyecto2"
    Curso       = "ComputacionEnLaNube"
  }
}

# Aprovisionamiento automatizado de la aplicación sobre AKS una vez creado el clúster
resource "null_resource" "deploy_k8s_app" {
  depends_on = [azurerm_kubernetes_cluster.aks]

  provisioner "local-exec" {
    command = <<-EOT
      az aks get-credentials --resource-group ${azurerm_resource_group.rg.name} --name ${azurerm_kubernetes_cluster.aks.name} --overwrite-existing
      kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.15.1/deploy/static/provider/cloud/deploy.yaml
      kubectl apply -f "${path.module}/../manifests/00-namespace.yaml"
      kubectl apply -f "${path.module}/../manifests/01-users.yaml"
      kubectl apply -f "${path.module}/../manifests/02-products.yaml"
      kubectl apply -f "${path.module}/../manifests/03-orders.yaml"
      kubectl apply -f "${path.module}/../manifests/04-ingress.yaml"
    EOT
  }
}
