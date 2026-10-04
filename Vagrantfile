# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|

<<<<<<< HEAD
  # 1. control-node
  config.vm.define "control-node" do |control|
    control.vm.box = "bento/ubuntu-22.04"
    control.vm.network "private_network", ip: "192.168.100.10"
    control.vm.hostname = "control-node"
    
    control.vm.provider "virtualbox" do |v|
      v.cpus = 2
      v.memory = 2048
    end

    # Monta la raiz del repo como sync folder por si acaso
    control.vm.synced_folder ".", "/vagrant"
    # Preinstalacion de herramientas esenciales
    control.vm.provision "shell", inline: <<-SHELL
      sudo apt-get update -y
      sudo apt-get install -y wget curl unzip git software-properties-common

      # Instala Terraform
      wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
      echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
      sudo apt-get update -y && sudo apt-get install -y terraform

      # Install Chef Workstation / Cinc Workstation
      curl -L https://omnitruck.chef.io/install.sh | sudo bash -s -- -P chef-workstation
    
      # Genera llave ssh si no estan presentes
      if [ ! -f /home/vagrant/.ssh/id_rsa ]; then
      ssh-keygen -t rsa -N "" -f /home/vagrant/.ssh/id_rsa
      chown vagrant:vagrant /home/vagrant/.ssh/id_rsa*
      fi
    SHELL
  end

  # 2. vm-haproxy
=======
  # 1. vm-haproxy
>>>>>>> problema1
  config.vm.define "vm-haproxy" do |haproxy|
    haproxy.vm.box = "bento/ubuntu-22.04"
    haproxy.vm.network "private_network", ip: "192.168.100.2"
    haproxy.vm.hostname = "vm-haproxy"
    
    haproxy.vm.provider "virtualbox" do |v|
      v.cpus = 2
      v.memory = 3072
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
      v.cpus = 2
      v.memory = 3072
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
      v.cpus = 2
      v.memory = 2048
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

      TERRAFORM_DIR="/vagrant/1. Infraestructura/terraform"

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
