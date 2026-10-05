# ==============================================================================
# Recipe: microservices::default
# Despliega los microservicios usando Docker Compose de forma declarativa
# ==============================================================================

app_dir = '/opt/microapp'

# 1. Crear directorio base para la aplicación
directory app_dir do
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end

# 2. Descargar la imagen base
execute "docker_pull_#{node['microapp']['image']}" do
  command "docker pull #{node['microapp']['image']}"
  not_if "docker image inspect #{node['microapp']['image']} >/dev/null 2>&1"
end

# 3. Generar el archivo docker-compose.yml a partir de la plantilla y los atributos
template "#{app_dir}/docker-compose.yml" do
  source 'docker-compose.yml.erb'
  owner 'root'
  group 'root'
  mode '0644'
  variables(
    services:  node['microapp']['services'],
    port_step: node['microapp']['port_step'],
    image:     node['microapp']['image']
  )
  notifies :run, 'execute[docker_compose_up]', :immediately
end

# 4. Levantar todos los servicios con Docker Compose en modo detached (-d)
execute 'docker_compose_up' do
  command "docker compose -f #{app_dir}/docker-compose.yml up -d --remove-orphans"
  cwd app_dir
  action :run
end
