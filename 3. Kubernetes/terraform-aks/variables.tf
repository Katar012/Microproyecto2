variable "resource_group_name" {
  type        = string
  default     = "rg-microapp-aks-tf"
  description = "Nombre del Resource Group en Azure"
}

variable "location" {
  type        = string
  default     = "eastus"
  description = "Región de Azure (debe estar permitida por la suscripción de estudiante)"
}

variable "cluster_name" {
  type        = string
  default     = "aks-microapp-tf"
  description = "Nombre del clúster AKS"
}

variable "dns_prefix" {
  type        = string
  default     = "microapp-k8s"
  description = "Prefijo DNS para el clúster AKS"
}

variable "node_count" {
  type        = number
  default     = 2
  description = "Cantidad de nodos en el default node pool"
}

variable "vm_size" {
  type        = string
  default     = "Standard_B2s"
  description = "Tamaño de VM para los nodos (económica para Azure for Students)"
}
