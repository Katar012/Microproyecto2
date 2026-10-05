apt_update 'update_apt' do
  action :update
end

package 'haproxy' do
  action :install
end

# socat: para hablarle a HAProxy en caliente por su socket de administracion
# ej: echo "show stat" | sudo socat stdio /run/haproxy/admin.sock
package 'socat' do
  action :install
end

# Copia el haproxy.cfg al nodo destino, rellenando la plantilla con los atributos
template '/etc/haproxy/haproxy.cfg' do
  source 'haproxy.cfg.erb'
  owner 'root'
  group 'root'
  mode '0644'
  variables(
    services:       node['microapp']['services'],
    port_step:      node['microapp']['port_step'],
    backend_ip:     node['haproxy']['backend_ip'],
    balance:        node['haproxy']['balance'],
    check:          node['haproxy']['check'],
    stats_port:     node['haproxy']['stats_port'],
    stats_user:     node['haproxy']['stats_user'],
    stats_password: node['haproxy']['stats_password']
  )
  # Valida la sintaxis ANTES de reemplazar el archivo: si la plantilla queda mal,
  # Chef falla y HAProxy sigue corriendo con la config anterior (no se cae).
  verify 'haproxy -c -f %{path}'
  # reload = recarga en caliente sin cortar las conexiones activas
  notifies :reload, 'service[haproxy]', :immediately
end

service 'haproxy' do
  supports reload: true, restart: true, status: true
  action [:enable, :start]
end
