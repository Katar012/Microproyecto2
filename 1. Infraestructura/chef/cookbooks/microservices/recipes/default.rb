# Contenedores para Users Service (Puertos 3001 y 3011 para round-robin)
execute 'deploy_users_1' do
  command 'docker run -d --name users-service-1 --restart always -p 3001:3000 hashicorp/http-echo -listen=:3000 -text="users-service-1"'
  not_if 'docker ps -a --format "{{.Names}}" | grep -q "^users-service-1$"'
end

execute 'deploy_users_2' do
  command 'docker run -d --name users-service-2 --restart always -p 3011:3000 hashicorp/http-echo -listen=:3000 -text="users-service-2"'
  not_if 'docker ps -a --format "{{.Names}}" | grep -q "^users-service-2$"'
end

# Contenedores para Products Service (Puertos 3002 y 3012)
execute 'deploy_products_1' do
  command 'docker run -d --name products-service-1 --restart always -p 3002:3000 hashicorp/http-echo -listen=:3000 -text="products-service-1"'
  not_if 'docker ps -a --format "{{.Names}}" | grep -q "^products-service-1$"'
end

execute 'deploy_products_2' do
  command 'docker run -d --name products-service-2 --restart always -p 3022:3000 hashicorp/http-echo -listen=:3000 -text="products-service-2"'
  not_if 'docker ps -a --format "{{.Names}}" | grep -q "^products-service-2$"'
end

# Contenedores para Orders Service (Puertos 3003 y 3013)
execute 'deploy_orders_1' do
  command 'docker run -d --name orders-service-1 --restart always -p 3003:3000 hashicorp/http-echo -listen=:3000 -text="orders-service-1"'
  not_if 'docker ps -a --format "{{.Names}}" | grep -q "^orders-service-1$"'
end

execute 'deploy_orders_2' do
  command 'docker run -d --name orders-service-2 --restart always -p 3033:3000 hashicorp/http-echo -listen=:3000 -text="orders-service-2"'
  not_if 'docker ps -a --format "{{.Names}}" | grep -q "^orders-service-2$"'
end
