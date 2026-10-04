# Codigo de tamaño PROMEDIO
package 'haproxy' do
  action :install
end

service 'haproxy' do
  action [:enable, :start]
end
