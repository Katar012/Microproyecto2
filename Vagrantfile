# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|

  # 1. control-node
  config.vm.define "control-node" do |control|
    control.vm.box = "bento/ubuntu-22.04"
    control.vm.network "private_network", ip: "192.168.100.1"
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
      sudo apt-get install -y wget curl unzip git software-properties-common ansible
      
      # Instala Terraform
      wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
      echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
      sudo apt-get update -y && sudo apt-get install -y terraform

      # Genera llave ssh si no estan presentes
      # if [ ! -f /home/vagrant/.ssh/id_rsa ]; then
      #  ssh-keygen -t rsa -N "" -f /home/vagrant/.ssh/id_rsa
      #  chown vagrant:vagrant /home/vagrant/.ssh/id_rsa*
      # fi
    SHELL
  end

  # 2. vm-haproxy
  config.vm.define "vm-haproxy" do |haproxy|
    haproxy.vm.box = "bento/ubuntu-22.04"
    haproxy.vm.network "private_network", ip: "192.168.100.2"
    haproxy.vm.hostname = "vm-haproxy"
    
    haproxy.vm.provider "virtualbox" do |v|
      v.cpus = 2
      v.memory = 3072
    end
    # Permite Autenticacion ssh
    # haproxy.vm.provision "shell", inline: <<-SHELL
    #  sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
    #  systemctl restart ssh
    # SHELL
  end

  # 3. vm-microservices
  config.vm.define "vm-microservices" do |microservices|
    microservices.vm.box = "bento/ubuntu-22.04"
    microservices.vm.network "private_network", ip: "192.168.100.3"
    microservices.vm.hostname = "vm-microservices"
    
    microservices.vm.provider "virtualbox" do |v|
      v.cpus = 2
      v.memory = 3072
    end
    # Permite Autenticacion ssh
    # haproxy.vm.provision "shell", inline: <<-SHELL
    #  sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
    #  systemctl restart ssh
    # SHELL
  end

end
