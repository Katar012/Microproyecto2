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
  end

end
