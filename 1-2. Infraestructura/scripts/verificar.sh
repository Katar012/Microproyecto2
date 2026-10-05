#!/usr/bin/env bash
# verificar.sh - Foto del estado de la infraestructura (Problemas 1 y 2)
# Uso (desde control-node):  bash "/vagrant/1-2. Infraestructura/scripts/verificar.sh"
#
# Sirve para la demo de reproducibilidad:
#   1) correr este script  -> estado A
#   2) terraform destroy   -> correrlo: todo vacio
#   3) terraform apply     -> correrlo: estado A otra vez (mismas huellas/sha)

HAPROXY=${HAPROXY:-192.168.100.2}
MICRO=${MICRO:-192.168.100.3}
SSH="ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"

titulo() { echo; echo "================ $* ================"; }

titulo "vm-microservices ($MICRO)"
$SSH vagrant@"$MICRO" '
  echo "SO:      $(grep PRETTY_NAME /etc/os-release | cut -d\" -f2)"
  echo "docker:  $(systemctl is-active docker 2>/dev/null) / $(systemctl is-enabled docker 2>/dev/null)"
  if command -v docker >/dev/null; then
    docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Ports}}\t{{.Status}}"
    echo "restart policy: $(docker inspect -f "{{.Name}}={{.HostConfig.RestartPolicy.Name}}" $(docker ps -aq) 2>/dev/null | tr "\n" " ")"
    [ -f /opt/microapp/docker-compose.yml ] && echo "docker-compose: /opt/microapp/docker-compose.yml (Activo)"
  else
    echo "Docker NO instalado"
  fi
'

titulo "vm-haproxy ($HAPROXY)"
$SSH vagrant@"$HAPROXY" '
  echo "SO:      $(grep PRETTY_NAME /etc/os-release | cut -d\" -f2)"
  echo "haproxy: $(systemctl is-active haproxy 2>/dev/null) / $(systemctl is-enabled haproxy 2>/dev/null)"
  if [ -f /etc/haproxy/haproxy.cfg ]; then
    echo "sha1 haproxy.cfg: $(sha1sum /etc/haproxy/haproxy.cfg | cut -c1-40)"
    sudo haproxy -c -f /etc/haproxy/haproxy.cfg
  else
    echo "HAProxy NO instalado"
  fi
'

titulo "Enrutamiento por ruta (curl a HAProxy:80)"
for ruta in users products orders; do
  for i in 1 2 3; do
    printf "%-22s -> " "/api/$ruta"
    curl -s -m 3 "http://$HAPROXY/api/$ruta" || echo "(sin respuesta)"
  done
done
printf "%-22s -> " "/otra/ruta"; curl -s -m 3 "http://$HAPROXY/otra/ruta" || echo "(sin respuesta)"; echo

titulo "Estado de servidores segun HAProxy (stats CSV)"
curl -s -m 3 -u admin:admin123 "http://$HAPROXY:8080/stats;csv" \
  | awk -F, 'NR==1 || $2 ~ /^(users|products|orders)[0-9]+$/ {printf "%-15s %-12s %-6s peticiones=%s\n", $1, $2, $18, $8}' \
  | sed 's/^# pxname/BACKEND/' || echo "(stats no disponible)"
