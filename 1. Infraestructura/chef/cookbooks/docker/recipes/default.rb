# Instala paquetes de prerrequisito
package %w(apt-transport-https ca-certificates curl gnupg lsb-release) do
  action :install
end

# Crea directorio de keyring
directory '/etc/apt/keyrings' do
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end

# Agrega la llave GPG de Docker
execute 'add_docker_gpg_key' do
  command 'curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes'
  creates '/etc/apt/keyrings/docker.gpg'
end

# Agrega el repositorio oficial de Docker
file '/etc/apt/sources.list.d/docker.list' do
  content 'deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu jammy stable'
  owner 'root'
  group 'root'
  mode '0644'
  notifies :run, 'execute[apt-get update]', :immediately
end

execute 'apt-get update' do
  action :nothing
end

# Instala Docker Engine
package %w(docker-ce docker-ce-cli containerd.io) do
  action :install
end

# Habilita e inicia el servicio Docker
service 'docker' do
  action [:enable, :start]
end

# Agrega usuario vagrant al grupo docker
group 'docker' do
  action :modify
  members 'vagrant'
  append true
end
