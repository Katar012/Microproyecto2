#############################################################################
# main.tf - Aprovisionamiento de vm-microservices y vm-haproxy con Chef (Cinc)
#
# Flujo:  terraform apply  ->  SSH (llave) a cada VM  ->  copia /chef  ->
#         instala cinc-client  ->  ejecuta el rol de la VM (chef-zero, local)
#
#         terraform destroy ->  SSH a cada VM  ->  deshace TODO lo que hizo Chef
#         (contenedores, Docker, HAProxy, Cinc) dejando la VM como recien creada.
#############################################################################

locals {
  chef_dir = "${path.module}/../chef"

  # Declaracion de las dos maquinas target: red, sistema operativo, rol de Chef
  # y llave SSH con la que Terraform se conecta. Se usa en los recursos y outputs.
  maquinas = {
    "vm-microservices" = {
      ip        = var.microservices_ip
      so        = "Ubuntu ${var.ubuntu_version} (bento/ubuntu-22.04)"
      red       = "private_network 192.168.100.0/24"
      rol_chef  = "role[microservices] -> recipe[docker] + recipe[microservices]"
      llave_ssh = var.ssh_private_key_path
    }
    "vm-haproxy" = {
      ip        = var.haproxy_ip
      so        = "Ubuntu ${var.ubuntu_version} (bento/ubuntu-22.04)"
      red       = "private_network 192.168.100.0/24"
      rol_chef  = "role[haproxy] -> recipe[haproxy]"
      llave_ssh = var.ssh_private_key_path
    }
  }

  # Huella (hash) de los archivos de Chef que afectan a cada VM.
  # Si cambias una receta/plantilla/atributo, el hash cambia y en el siguiente
  # "terraform apply" Terraform re-aprovisiona SOLO la VM afectada.
  # (los notas.txt se ignoran para no re-aprovisionar por cambiar un comentario)
  archivos_microservices = sort(concat(
    [for f in fileset(local.chef_dir, "cookbooks/docker/**") : f if !endswith(f, ".txt")],
    [for f in fileset(local.chef_dir, "cookbooks/microservices/**") : f if !endswith(f, ".txt")],
    ["roles/microservices.rb", "nodes/vm-microservices.json", "solo.rb"]
  ))
  archivos_haproxy = sort(concat(
    [for f in fileset(local.chef_dir, "cookbooks/haproxy/**") : f if !endswith(f, ".txt")],
    # haproxy lee la lista de servicios del cookbook microservices (fuente unica de verdad)
    [for f in fileset(local.chef_dir, "cookbooks/microservices/**") : f if !endswith(f, ".txt")],
    ["roles/haproxy.rb", "nodes/vm-haproxy.json", "solo.rb"]
  ))
  hash_microservices = sha1(join(",", [for f in local.archivos_microservices : filesha1("${local.chef_dir}/${f}")]))
  hash_haproxy       = sha1(join(",", [for f in local.archivos_haproxy : filesha1("${local.chef_dir}/${f}")]))
}

#############################################################################
# 1. vm-microservices: Docker + 6 contenedores (2 por microservicio)
#############################################################################
resource "null_resource" "provision_microservices" {
  # Si cualquiera de estos valores cambia, Terraform destruye y vuelve a crear
  # este recurso (o sea: limpia la VM y la vuelve a aprovisionar).
  triggers = {
    host      = var.microservices_ip
    user      = var.ssh_user
    key_path  = var.ssh_private_key_path
    chef_hash = local.hash_microservices
  }

  connection {
    type        = "ssh"
    host        = self.triggers.host
    user        = self.triggers.user
    private_key = file(self.triggers.key_path)
  }

  # 1.1 Validaciones y preparacion de la VM
  provisioner "remote-exec" {
    inline = [
      "set -e",
      "echo '=== [vm-microservices] Validando sistema operativo ==='",
      "grep -q 'VERSION_ID=\"${var.ubuntu_version}\"' /etc/os-release || { echo 'ERROR: se esperaba Ubuntu ${var.ubuntu_version}'; exit 1; }",
      "grep PRETTY_NAME /etc/os-release",
      # Las actualizaciones automaticas de Ubuntu bloquean apt y rompen a Chef
      "sudo systemctl disable --now unattended-upgrades apt-daily.timer apt-daily-upgrade.timer >/dev/null 2>&1 || true",
      "while sudo fuser /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/lib/apt/lists/lock >/dev/null 2>&1; do echo 'Esperando a que apt se libere...'; sleep 3; done",
      # Carpeta limpia para los cookbooks (sudo porque Chef deja archivos de root ahi)
      "sudo rm -rf /tmp/chef && mkdir -p /tmp/chef",
    ]
  }

  # 1.2 Copia la carpeta de Chef completa al nodo destino (/tmp/chef)
  provisioner "file" {
    source      = "${local.chef_dir}/"
    destination = "/tmp/chef"
  }

  # 1.3 Instala Cinc Client (Chef libre) si no esta y ejecuta el rol de microservicios
  provisioner "remote-exec" {
    inline = [
      "set -e",
      "echo '=== [vm-microservices] Instalando Cinc Client y ejecutando Chef ==='",
      "command -v cinc-client >/dev/null 2>&1 || curl -sL https://omnitruck.cinc.sh/install.sh | sudo bash -s -- -v 18",
      "cd /tmp/chef && sudo cinc-client -z -c /tmp/chef/solo.rb -j /tmp/chef/nodes/vm-microservices.json",
      "echo '=== [vm-microservices] Contenedores corriendo ==='",
      "sudo docker ps --format 'table {{.Names}}\\t{{.Image}}\\t{{.Ports}}\\t{{.Status}}'",
    ]
  }

  # 1.4 terraform destroy: deshace todo lo que hizo Chef en esta VM
  provisioner "remote-exec" {
    when = destroy
    inline = [
      "echo '=== [terraform destroy] Limpiando vm-microservices ==='",
      "if [ -f /opt/microapp/docker-compose.yml ]; then sudo docker compose -f /opt/microapp/docker-compose.yml down -v >/dev/null 2>&1 || true; fi",
      "if command -v docker >/dev/null 2>&1; then sudo docker rm -f $(sudo docker ps -aq) >/dev/null 2>&1 || true; sudo docker system prune -af >/dev/null 2>&1 || true; fi",
      "sudo systemctl disable --now docker.socket docker containerd >/dev/null 2>&1 || true",
      "while sudo fuser /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/lib/apt/lists/lock >/dev/null 2>&1; do sleep 3; done",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras >/dev/null 2>&1 || true",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get purge -y cinc >/dev/null 2>&1 || true",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get autoremove -y >/dev/null 2>&1 || true",
      "sudo rm -rf /var/lib/docker /var/lib/containerd /etc/apt/sources.list.d/docker.list /etc/apt/keyrings/docker.gpg /tmp/chef /opt/cinc /etc/cinc /var/cinc /opt/microapp",
      "echo 'vm-microservices limpia: sin contenedores, sin Docker y sin Cinc'",
    ]
  }
}

#############################################################################
# 2. vm-haproxy: HAProxy con el haproxy.cfg generado por Chef (Problema 2)
#############################################################################
resource "null_resource" "provision_haproxy" {
  # Garantiza que los microservicios se instalen primero antes de aprovisionar el balanceador
  # (y en destroy, que el balanceador se limpie primero)
  depends_on = [null_resource.provision_microservices]

  triggers = {
    host      = var.haproxy_ip
    user      = var.ssh_user
    key_path  = var.ssh_private_key_path
    chef_hash = local.hash_haproxy
  }

  connection {
    type        = "ssh"
    host        = self.triggers.host
    user        = self.triggers.user
    private_key = file(self.triggers.key_path)
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "echo '=== [vm-haproxy] Validando sistema operativo ==='",
      "grep -q 'VERSION_ID=\"${var.ubuntu_version}\"' /etc/os-release || { echo 'ERROR: se esperaba Ubuntu ${var.ubuntu_version}'; exit 1; }",
      "grep PRETTY_NAME /etc/os-release",
      "sudo systemctl disable --now unattended-upgrades apt-daily.timer apt-daily-upgrade.timer >/dev/null 2>&1 || true",
      "while sudo fuser /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/lib/apt/lists/lock >/dev/null 2>&1; do echo 'Esperando a que apt se libere...'; sleep 3; done",
      "sudo rm -rf /tmp/chef && mkdir -p /tmp/chef",
    ]
  }

  provisioner "file" {
    source      = "${local.chef_dir}/"
    destination = "/tmp/chef"
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "echo '=== [vm-haproxy] Instalando Cinc Client y ejecutando Chef ==='",
      "command -v cinc-client >/dev/null 2>&1 || curl -sL https://omnitruck.cinc.sh/install.sh | sudo bash -s -- -v 18",
      "cd /tmp/chef && sudo cinc-client -z -c /tmp/chef/solo.rb -j /tmp/chef/nodes/vm-haproxy.json",
      "echo '=== [vm-haproxy] Estado de HAProxy ==='",
      "echo \"haproxy: $(systemctl is-active haproxy) / $(systemctl is-enabled haproxy)\"",
    ]
  }

  provisioner "remote-exec" {
    when = destroy
    inline = [
      "echo '=== [terraform destroy] Limpiando vm-haproxy ==='",
      "sudo systemctl disable --now haproxy >/dev/null 2>&1 || true",
      "while sudo fuser /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/lib/apt/lists/lock >/dev/null 2>&1; do sleep 3; done",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get purge -y haproxy socat cinc >/dev/null 2>&1 || true",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get autoremove -y >/dev/null 2>&1 || true",
      "sudo rm -rf /etc/haproxy /tmp/chef /opt/cinc /etc/cinc /var/cinc",
      "echo 'vm-haproxy limpia: sin HAProxy y sin Cinc'",
    ]
  }
}
