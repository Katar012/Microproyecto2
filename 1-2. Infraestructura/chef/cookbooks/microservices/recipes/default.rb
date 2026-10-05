require 'digest'

# Levanta los contenedores de los microservicios a partir de los atributos
# (attributes/default.rb). Por defecto: 2 instancias por servicio.
#
#   users-service-1    -> host 3001 -> contenedor 3001
#   users-service-2    -> host 3011 -> contenedor 3001
#   products-service-1 -> host 3002 -> contenedor 3002
#   products-service-2 -> host 3012 -> contenedor 3002
#   orders-service-1   -> host 3003 -> contenedor 3003
#   orders-service-2   -> host 3013 -> contenedor 3003
#
# Dentro del contenedor el servicio escucha en su puerto interno correcto
# (3001/3002/3003); la segunda instancia solo cambia el puerto del HOST.

image     = node['microapp']['image']
port_step = node['microapp']['port_step']

# 1. Descargar la imagen una sola vez
execute "docker_pull_#{image}" do
  command "docker pull #{image}"
  not_if "docker image inspect #{image} >/dev/null 2>&1"
end

desired = []

node['microapp']['services'].each do |svc, cfg|
  internal_port = cfg['port']

  (1..cfg['instances']).each do |i|
    name      = "#{svc}-service-#{i}"
    host_port = internal_port + (i - 1) * port_step
    text      = "#{svc}-service | instancia: #{name} | puerto contenedor: #{internal_port} | puerto host: #{host_port}"
    # Huella de la configuracion del contenedor: si cambia (imagen, puerto, texto)
    # Chef lo recrea; si no cambia, no lo toca (idempotencia).
    spec      = Digest::SHA1.hexdigest([image, internal_port, host_port, text].join('|'))[0, 12]
    desired << name

    # 2. Crear (o recrear si cambio su configuracion) el contenedor
    #    --restart always -> Docker lo vuelve a levantar si la VM se reinicia
    execute "deploy_#{name}" do
      command "docker rm -f #{name} >/dev/null 2>&1 || true; " \
              "docker run -d --name #{name} --restart always " \
              "--label microapp.service=#{svc} --label microapp.spec=#{spec} " \
              "-p #{host_port}:#{internal_port} #{image} " \
              "-listen=:#{internal_port} -text='#{text}'"
      not_if "test \"$(docker inspect -f '{{ index .Config.Labels \"microapp.spec\" }}' #{name} 2>/dev/null)\" = '#{spec}'"
    end

    # 3. Asegurar que este corriendo (por si alguien lo detuvo con docker stop)
    execute "start_#{name}" do
      command "docker start #{name}"
      not_if "test \"$(docker inspect -f '{{ .State.Running }}' #{name} 2>/dev/null)\" = 'true'"
    end
  end
end

# 4. Borrar contenedores sobrantes (ej: si bajas instances de 3 a 2)
keep = desired.join('|')
execute 'remove_orphan_containers' do
  command "docker ps -a --filter label=microapp.service --format '{{ .Names }}' | grep -Ev '^(#{keep})$' | xargs -r docker rm -f"
  only_if "docker ps -a --filter label=microapp.service --format '{{ .Names }}' | grep -Ev '^(#{keep})$' | grep -q ."
end
