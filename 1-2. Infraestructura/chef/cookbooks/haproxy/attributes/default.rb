# Parametros del balanceador. Se inyectan en templates/default/haproxy.cfg.erb

# IP de la VM donde corren los contenedores (vm-microservices)
default['haproxy']['backend_ip'] = '192.168.100.3'

# Algoritmo de balanceo: roundrobin | leastconn | source | first ...
default['haproxy']['balance'] = 'roundrobin'

# Health check de cada servidor:
#   inter 2s -> revisa cada 2 segundos
#   fall 2   -> 2 fallos seguidos  = DOWN
#   rise 2   -> 2 exitos seguidos  = UP otra vez
default['haproxy']['check'] = 'inter 2s fall 2 rise 2'

# Dashboard de estadisticas (puerto dedicado + usuario/contraseña)
default['haproxy']['stats_port']     = 8080
default['haproxy']['stats_user']     = 'admin'
default['haproxy']['stats_password'] = 'admin123'
