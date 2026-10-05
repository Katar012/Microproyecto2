# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|

  # En equipos con Hyper-V activo (Docker Desktop/WSL2) o poca RAM libre, VirtualBox
  # arranca mas lento y Vagrant aborta a los 5 min por defecto. Le damos 15 min.
  config.vm.boot_timeout = 900

  # 1. vm-haproxy
  config.vm.define "vm-haproxy" do |haproxy|
    haproxy.vm.box = "bento/ubuntu-22.04"
    haproxy.vm.network "private_network", ip: "192.168.100.2"
    haproxy.vm.hostname = "vm-haproxy"
    
    haproxy.vm.provider "virtualbox" do |v|
      v.cpus = 1
      v.memory = 768
    end

    # Habilita autenticación por contraseña y prepara llaves SSH autorizadas
    haproxy.vm.provision "shell", inline: <<-SHELL
      sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
      sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/g' /etc/ssh/sshd_config
      systemctl restart ssh
      
      # Si control-node ya generó la clave en la carpeta compartida, la autorizamos
      if [ -f /vagrant/id_rsa.pub ]; then
        mkdir -p /home/vagrant/.ssh
        cat /vagrant/id_rsa.pub >> /home/vagrant/.ssh/authorized_keys
        chmod 600 /home/vagrant/.ssh/authorized_keys
        chown -R vagrant:vagrant /home/vagrant/.ssh
      fi
    SHELL
  end

  # 2. vm-microservices
  config.vm.define "vm-microservices" do |microservices|
    microservices.vm.box = "bento/ubuntu-22.04"
    microservices.vm.network "private_network", ip: "192.168.100.3"
    microservices.vm.hostname = "vm-microservices"
    
    microservices.vm.provider "virtualbox" do |v|
      v.cpus = 1
      v.memory = 1024
    end

    # Habilita autenticación por contraseña y prepara llaves SSH autorizadas
    microservices.vm.provision "shell", inline: <<-SHELL
      sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
      sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/g' /etc/ssh/sshd_config
      systemctl restart ssh

      # Si control-node ya generó la clave en la carpeta compartida, la autorizamos
      if [ -f /vagrant/id_rsa.pub ]; then
        mkdir -p /home/vagrant/.ssh
        cat /vagrant/id_rsa.pub >> /home/vagrant/.ssh/authorized_keys
        chmod 600 /home/vagrant/.ssh/authorized_keys
        chown -R vagrant:vagrant /home/vagrant/.ssh
      fi
    SHELL
  end

# 3. control-node (Se ejecuta al final para orquestar a las otras dos VMs)
  config.vm.define "control-node" do |control|
    control.vm.box = "bento/ubuntu-22.04"
    control.vm.network "private_network", ip: "192.168.100.10"
    control.vm.hostname = "control-node"
    
    control.vm.provider "virtualbox" do |v|
      v.cpus = 1
      v.memory = 1024
    end

    control.vm.synced_folder ".", "/vagrant"

    control.vm.provision "shell", inline: <<-SHELL
      sudo apt-get update -y
      sudo apt-get install -y wget curl unzip git software-properties-common sshpass

      # Instala Terraform
      wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
      echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
      sudo apt-get update -y && sudo apt-get install -y terraform

      # Instala Chef Workstation / Cinc Workstation
      curl -L https://omnitruck.chef.io/install.sh | sudo bash -s -- -P chef-workstation

      # Genera clave SSH para el usuario vagrant si no existe
      if [ ! -f /home/vagrant/.ssh/id_rsa ]; then
        sudo -u vagrant ssh-keygen -t rsa -N "" -f /home/vagrant/.ssh/id_rsa
      fi

      # Copia las llaves a las VMs usando la llave del usuario vagrant
      sshpass -p "vagrant" ssh-copy-id -i /home/vagrant/.ssh/id_rsa.pub -o StrictHostKeyChecking=no vagrant@192.168.100.2 || true
      sshpass -p "vagrant" ssh-copy-id -i /home/vagrant/.ssh/id_rsa.pub -o StrictHostKeyChecking=no vagrant@192.168.100.3 || true

      # Nombres de las VMs (ssh vm-haproxy / curl http://vm-haproxy/api/users)
      grep -q vm-haproxy /etc/hosts || echo "192.168.100.2 vm-haproxy" >> /etc/hosts
      grep -q vm-microservices /etc/hosts || echo "192.168.100.3 vm-microservices" >> /etc/hosts

      # Cliente SSH del usuario vagrant: entra con la llave y sin preguntar
      # "Are you sure you want to continue connecting (yes/no)?"
      cat > /home/vagrant/.ssh/config <<'EOF'
Host vm-haproxy vm-microservices 192.168.100.*
    User vagrant
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR
EOF
      chown vagrant:vagrant /home/vagrant/.ssh/config
      chmod 600 /home/vagrant/.ssh/config

      TERRAFORM_DIR="/vagrant/1-2. Infraestructura/terraform"

      if [ -d "$TERRAFORM_DIR" ]; then
        echo "=== INICIANDO APROVISIONAMIENTO DE TERRAFORM ==="
        cd "$TERRAFORM_DIR"

        # Borra estados antiguos para forzar a Terraform a ejecutar Chef en instalaciones limpias
        rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.backup

        sudo -u vagrant terraform init
        sudo -u vagrant terraform apply -auto-approve
      else
        echo "ERROR: No se encontró la carpeta $TERRAFORM_DIR"
      fi
    SHELL
  end
end
