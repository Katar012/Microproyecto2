# 1. Actualizar caché de apt e instalar MySQL Server
apt_update 'update' do
  action :update
end

package 'mysql-server' do
  action :install
end

service 'mysql' do
  action [:enable, :start]
end

# 2. Configurar bind-address a 0.0.0.0 para acceso local y remoto
execute 'configure_mysql_bind' do
  command "sed -i 's/127.0.0.1/0.0.0.0/g' /etc/mysql/mysql.conf.d/mysqld.cnf"
  notifies :restart, 'service[mysql]', :immediately
  not_if "grep -q '0.0.0.0' /etc/mysql/mysql.conf.d/mysqld.cnf"
end

# 3. Asignar contraseña al usuario root local
execute 'set_mysql_root_password' do
  command "sudo mysql -e \"ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'root'; FLUSH PRIVILEGES;\""
  not_if "mysql -u root -proot -e 'SHOW DATABASES;'"
  action :run
end

# 4. Configurar usuarios y permisos para la red de Docker (%)
execute 'configure_docker_mysql_users' do
  command <<-EOH
    mysql -u root -proot -e "CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED WITH mysql_native_password BY 'root';"
    mysql -u root -proot -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;"
    mysql -u root -proot -e "CREATE USER IF NOT EXISTS 'app'@'%' IDENTIFIED WITH mysql_native_password BY 'app_password';"
    mysql -u root -proot -e "GRANT ALL PRIVILEGES ON *.* TO 'app'@'%' WITH GRANT OPTION;"
    mysql -u root -proot -e "FLUSH PRIVILEGES;"
  EOH
  not_if "mysql -u root -proot -e \"SELECT User, Host FROM mysql.user WHERE User='app' AND Host='%';\" | grep -q 'app'"
  action :run
end

# 5. Crear e importar las bases de datos (solo si el archivo existe y no se han importado las tablas)
%w[users products orders].each do |db_name|
  sql_file = "/tmp/chef/cookbooks/mysql/files/default/#{db_name}_db.sql"

  execute "create_#{db_name}_db" do
    command "mysql -u root -proot -e \"CREATE DATABASE IF NOT EXISTS #{db_name}_db;\""
    action :run
  end

  execute "import_#{db_name}_db" do
    command "mysql -u root -proot #{db_name}_db < #{sql_file}"
    only_if { ::File.exist?(sql_file) }
    not_if "mysql -u root -proot -e \"USE #{db_name}_db; SHOW TABLES;\" | grep -q [a-zA-Z]"
  end
end
