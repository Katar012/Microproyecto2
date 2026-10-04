apt_update 'update_apt' do
  action :update
end

package 'haproxy' do
  action :install
end

service 'haproxy' do
  action [:enable, :start]
end
