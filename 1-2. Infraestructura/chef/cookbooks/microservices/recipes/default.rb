# Contenedores para Users Service (Puertos 3001 y 3011)
execute 'deploy_users_1' do
  command 'docker run -d --name users-service-1 --restart always -p 3001:5002 ' \
          '-e MYSQL_HOST=172.17.0.1 -e MYSQL_USER=root -e MYSQL_PASSWORD=root -e MYSQL_DB=users_db ' \
          '-e SECRET_KEY=secret123 jcueror/microusers:latest'
  not_if 'docker ps -a --format "{{.Names}}" | grep -q "^users-service-1$"'
end

execute 'deploy_users_2' do
  command 'docker run -d --name users-service-2 --restart always -p 3011:5002 ' \
          '-e MYSQL_HOST=172.17.0.1 -e MYSQL_USER=root -e MYSQL_PASSWORD=root -e MYSQL_DB=users_db ' \
          '-e SECRET_KEY=secret123 jcueror/microusers:latest'
  not_if 'docker ps -a --format "{{.Names}}" | grep -q "^users-service-2$"'
end

# Contenedores para Products Service (Puertos 3002 y 3012)
execute 'deploy_products_1' do
  command 'docker run -d --name products-service-1 --restart always -p 3002:5003 ' \
          '-e MYSQL_HOST=172.17.0.1 -e MYSQL_USER=root -e MYSQL_PASSWORD=root -e MYSQL_DB=products_db ' \
          '-e SECRET_KEY=secret123 jcueror/microproducts:latest'
  not_if 'docker ps -a --format "{{.Names}}" | grep -q "^products-service-1$"'
end

execute 'deploy_products_2' do
  command 'docker run -d --name products-service-2 --restart always -p 3012:5003 ' \
          '-e MYSQL_HOST=172.17.0.1 -e MYSQL_USER=root -e MYSQL_PASSWORD=root -e MYSQL_DB=products_db ' \
          '-e SECRET_KEY=secret123 jcueror/microproducts:latest'
  not_if 'docker ps -a --format "{{.Names}}" | grep -q "^products-service-2$"'
end

# Contenedores para Orders Service (Puertos 3003 y 3013)
execute 'deploy_orders_1' do
  command 'docker run -d --name orders-service-1 --restart always -p 3003:5004 ' \
          '-e MYSQL_HOST=172.17.0.1 -e MYSQL_USER=root -e MYSQL_PASSWORD=root -e MYSQL_DB=orders_db ' \
          '-e SECRET_KEY=secret123 jcueror/microorders:latest'
  not_if 'docker ps -a --format "{{.Names}}" | grep -q "^orders-service-1$"'
end

execute 'deploy_orders_2' do
  command 'docker run -d --name orders-service-2 --restart always -p 3013:5004 ' \
          '-e MYSQL_HOST=172.17.0.1 -e MYSQL_USER=root -e MYSQL_PASSWORD=root -e MYSQL_DB=orders_db ' \
          '-e SECRET_KEY=secret123 jcueror/microorders:latest'
  not_if 'docker ps -a --format "{{.Names}}" | grep -q "^orders-service-2$"'
end

# Contenedor para Frontend (Puerto 5001 para HAProxy)
execute 'deploy_frontend' do
  command 'docker run -d --name frontend-service --restart always -p 5001:5001 ' \
          '-e USERS_SERVICE_URL="http://192.168.100.2" ' \
          '-e PRODUCTS_SERVICE_URL="http://192.168.100.2" ' \
          '-e ORDERS_SERVICE_URL="http://192.168.100.2" ' \
          'jcueror/frontend:latest'
  not_if 'docker ps -a --format "{{.Names}}" | grep -q "^frontend-service$"'
end
