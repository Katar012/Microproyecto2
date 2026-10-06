# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|

  # 1. vm-haproxy
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

# 3. control-node
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
      # Instalar dependencias solo si no existe terraform
      if ! command -v terraform &> /dev/null; then
        sudo apt-get update -y
        sudo apt-get install -y wget curl unzip git software-properties-common sshpass

        wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
        echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
        sudo apt-get update -y && sudo apt-get install -y terraform
      fi

      # Instalar Chef Workstation solo si no está instalado
      if ! command -v chef &> /dev/null; then
        curl -L https://omnitruck.chef.io/install.sh | sudo bash -s -- -P chef-workstation
      fi

      # Generar y copiar clave SSH solo si no existe
      if [ ! -f /home/vagrant/.ssh/id_rsa ]; then
        sudo -u vagrant ssh-keygen -t rsa -N "" -f /home/vagrant/.ssh/id_rsa
        sshpass -p "vagrant" ssh-copy-id -i /home/vagrant/.ssh/id_rsa.pub -o StrictHostKeyChecking=no vagrant@192.168.100.2 || true
        sshpass -p "vagrant" ssh-copy-id -i /home/vagrant/.ssh/id_rsa.pub -o StrictHostKeyChecking=no vagrant@192.168.100.3 || true
      fi

      TERRAFORM_DIR="/vagrant/1-2. Infraestructura/terraform"

      if [ -d "$TERRAFORM_DIR" ]; then
        echo "=== EJECUTANDO TERRAFORM ==="
        cd "$TERRAFORM_DIR"

        # MANTENER EL ESTADO DE TERRAFORM (NO BORRAR TERRAFORM.TFSTATE)
        if [ ! -d ".terraform" ]; then
          sudo -u vagrant terraform init
        fi
        
        sudo -u vagrant terraform apply -auto-approve
      fi
    SHELL
  end
end
