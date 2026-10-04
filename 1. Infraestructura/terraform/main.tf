# Aprovisiona vm-microservices transfiriendo los cookbooks de Chef y ejecutándolos
resource "null_resource" "provision_microservices" {
  connection {
    type     = "ssh"
    host     = var.microservices_ip
    user     = var.ssh_user
    password = var.ssh_password
  }

  # Copia la carpeta de Chef completa al nodo destino
  provisioner "file" {
    source      = "${path.module}/../chef"
    destination = "/tmp/chef"
  }

  # Instala Cinc/Chef Client en el nodo y ejecuta el rol de microservicios
  provisioner "remote-exec" {
    inline = [
      "curl -L https://omnitruck.cinc.sh/install.sh | sudo bash -s -- -v 18",
      "cd /tmp/chef && sudo cinc-client -z -c /tmp/chef/solo.rb -j /tmp/chef/nodes/vm-microservices.json"
    ]
  }
}

# Aprovisiona vm-haproxy transfiriendo los cookbooks de Chef y ejecutándolos
resource "null_resource" "provision_haproxy" {
  connection {
    type     = "ssh"
    host     = var.haproxy_ip
    user     = var.ssh_user
    password = var.ssh_password
  }

  provisioner "file" {
    source      = "${path.module}/../chef"
    destination = "/tmp/chef"
  }

  provisioner "remote-exec" {
    inline = [
      "while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do sleep 2; done",
      "sudo apt-get update -y",
      "curl -L https://omnitruck.cinc.sh/install.sh | sudo bash -s -- -v 18",
      "cd /tmp/chef && sudo cinc-client -z -c /tmp/chef/solo.rb -j /tmp/chef/nodes/vm-haproxy.json"
    ]
  }
}
