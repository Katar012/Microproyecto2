apt_update 'update_apt' do
  action :update
end

package 'haproxy' do
  action :install
end

# Copia el haproxy.cfg al nodo destino
template '/etc/haproxy/haproxy.cfg' do
  source 'haproxy.cfg.erb'
  owner 'root'
  group 'root'
  mode '0644'
  notifies :restart, 'service[haproxy]', :immediately
end

service 'haproxy' do
  action [:enable, :start]
end
