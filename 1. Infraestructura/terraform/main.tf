# Configura conexion ssh y aprovisiona docker en vm-microservices
resource "null_resource" "provision_microservices" {
  connection {
    type     = "ssh"
    host     = var.microservices_ip
    user     = var.ssh_user
    password = var.ssh_password
  }

  # Instalar docker y habilitar el servicio
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -y",
      "sudo apt-get install -y ca-certificates curl gnupg",
      "sudo install -m 0755 -d /etc/apt/keyrings",
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes",
      "sudo chmod a+r /etc/apt/keyrings/docker.gpg",
      "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",
      "sudo apt-get update -y",
      "sudo apt-get install -y docker-ce docker-ce-cli containerd.io",
      "sudo systemctl enable docker",
      "sudo systemctl start docker",
      "sudo usermod -aG docker vagrant"
    ]
  }

  # Despliega los contenedores de microservicios (DOS INSTANCIAS PARA EL ROUND-ROBIN)
  provisioner "remote-exec" {
    inline = [
      # Users
      "sudo docker run -d --name users-service-1 --restart always -p 3001:3001 ealen/echo-server",
      "sudo docker run -d --name users-service-2 --restart always -p 3011:3001 ealen/echo-server",

      # Products
      "sudo docker run -d --name products-service-1 --restart always -p 3002:3002 ealen/echo-server",
      "sudo docker run -d --name products-service-2 --restart always -p 3012:3002 ealen/echo-server",

      # Orders
      "sudo docker run -d --name orders-service-1 --restart always -p 3003:3003 ealen/echo-server",
      "sudo docker run -d --name orders-service-2 --restart always -p 3013:3003 ealen/echo-server"
    ]
  }
}

# Configura conexion ssh e instala Haproxy en vm-haproxy
resource "null_resource" "provision_haproxy" {
  connection {
    type     = "ssh"
    host     = var.haproxy_ip
    user     = var.ssh_user
    password = var.ssh_password
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -y",
      "sudo apt-get install -y haproxy",
      "sudo systemctl enable haproxy",
      "sudo systemctl start haproxy"
    ]
  }
}
