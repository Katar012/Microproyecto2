output "haproxy_ip" {
  value       = var.haproxy_ip
  description = "Direccion ip de la VM Haproxy"
}

output "microservices_ip" {
  value       = var.microservices_ip
  description = "Direccion ip de la VM Microservices"
}

output "maquinas" {
  value       = local.maquinas
  description = "Maquinas target declaradas: red, sistema operativo, rol de Chef y llave SSH"
}

output "urls" {
  description = "Puntos de entrada de la aplicacion (todo entra por HAProxy)"
  value = {
    users    = "http://${var.haproxy_ip}/api/users"
    products = "http://${var.haproxy_ip}/api/products"
    orders   = "http://${var.haproxy_ip}/api/orders"
    stats    = "http://${var.haproxy_ip}:8080/stats  (admin / admin123)"
  }
}

output "verificar" {
  description = "Comandos para verificar desde el control-node"
  value       = <<-EOT
    ssh vm-microservices "docker ps"
    ssh vm-haproxy "systemctl status haproxy --no-pager"
    for i in 1 2 3 4; do curl -s http://${var.haproxy_ip}/api/users; done
    bash "/vagrant/1-2. Infraestructura/scripts/verificar.sh"
  EOT
}
