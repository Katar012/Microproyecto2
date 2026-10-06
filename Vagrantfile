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
      v.memory = 4096 # Increased to 4GB for Docker + Minikube execution
    end

    control.vm.synced_folder ".", "/vagrant"

    control.vm.provision "shell", inline: <<-SHELL
      # 1. Instalar dependencias base y Terraform
      if ! command -v terraform &> /dev/null; then
        sudo apt-get update -y
        sudo apt-get install -y wget curl unzip git software-properties-common sshpass apt-transport-https ca-certificates gnupg

        wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
        echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
        sudo apt-get update -y && sudo apt-get install -y terraform
      fi

      # 2. Instalar Docker Engine (Requerido como driver para Minikube)
      if ! command -v docker &> /dev/null; then
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update -y
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        sudo usermod -aG docker vagrant
      fi

      # 3. Instalar kubectl
      if ! command -v kubectl &> /dev/null; then
        KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
        curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
        sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
        rm kubectl
      fi

      # 4. Instalar Minikube
      if ! command -v minikube &> /dev/null; then
        curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
        sudo install minikube-linux-amd64 /usr/local/bin/minikube
        rm minikube-linux-amd64
      fi

      # 5. Instalar Azure CLI (Requerido para el punto de AKS / Azure Cloud Shell)
      if ! command -v az &> /dev/null; then
        curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
      fi

      # 6. Instalar Chef Workstation solo si no está instalado
      if ! command -v chef &> /dev/null; then
        curl -L https://omnitruck.chef.io/install.sh | sudo bash -s -- -P chef-workstation
      fi

      # 7. Generar y copiar clave SSH solo si no existe
      if [ ! -f /home/vagrant/.ssh/id_rsa ]; then
        sudo -u vagrant ssh-keygen -t rsa -N "" -f /home/vagrant/.ssh/id_rsa
        sshpass -p "vagrant" ssh-copy-id -i /home/vagrant/.ssh/id_rsa.pub -o StrictHostKeyChecking=no vagrant@192.168.100.2 || true
        sshpass -p "vagrant" ssh-copy-id -i /home/vagrant/.ssh/id_rsa.pub -o StrictHostKeyChecking=no vagrant@192.168.100.3 || true
      fi

      # 8. Ejecutar Terraform
      TERRAFORM_DIR="/vagrant/1-2. Infraestructura/terraform"

      if [ -d "$TERRAFORM_DIR" ]; then
        echo "=== EJECUTANDO TERRAFORM ==="
        cd "$TERRAFORM_DIR"

        if [ ! -d ".terraform" ]; then
          sudo -u vagrant terraform init
        fi
        
        sudo -u vagrant terraform apply -auto-approve
      fi

      # 9. Inicializar Minikube con addon de Ingress si no está iniciado
      if ! sudo -u vagrant minikube status | grep -q "Running"; then
        echo "=== INICIANDO MINIKUBE Y ENABLING INGRESS ==="
        sudo -u vagrant minikube start --driver=docker
        sudo -u vagrant minikube addons enable ingress
      fi
    SHELL
  end
end
