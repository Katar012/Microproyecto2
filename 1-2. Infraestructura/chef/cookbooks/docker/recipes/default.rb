# 1. Asegurar la actualización previa de los índices de paquetes apt
apt_update 'update_apt' do
  action :update
end

# 2. Instalar paquetes de prerrequisito necesarios
%w(apt-transport-https ca-certificates curl gnupg lsb-release).each do |pkg|
  package pkg do
    action :install
  end
end

# 3. Crear el directorio de keyrings si no existe
directory '/etc/apt/keyrings' do
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end

# 4. Descargar y agregar la llave GPG oficial de Docker
execute 'add_docker_gpg_key' do
  command 'curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg'
  creates '/etc/apt/keyrings/docker.gpg'
end

# 5. Configurar el repositorio oficial de Docker usando la arquitectura nativa del sistema
docker_arch = node['kernel']['machine'] == 'aarch64' ? 'arm64' : 'amd64'

file '/etc/apt/sources.list.d/docker.list' do
  content "deb [arch=#{docker_arch} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu #{node['lsb']['codename']} stable\n"
  owner 'root'
  group 'root'
  mode '0644'
  notifies :run, 'execute[apt-get update docker repo]', :immediately
end

execute 'apt-get update docker repo' do
  command 'apt-get update'
  action :nothing
end

# 6. Instalar Docker Engine, CLI, containerd y plugin de Docker Compose
%w(docker-ce docker-ce-cli containerd.io docker-compose-plugin).each do |pkg|
  package pkg do
    action :install
  end
end

# 7. Habilitar e iniciar el servicio de Docker
service 'docker' do
  action [:enable, :start]
end

# 8. Agregar al usuario vagrant al grupo docker
group 'docker' do
  action :modify
  members 'vagrant'
  append true
end
