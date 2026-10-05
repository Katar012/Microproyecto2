#!/usr/bin/env bash
# prueba-haproxy.sh - Demo completa del Problema 2 (desde control-node)
# Uso: bash "/vagrant/1-2. Infraestructura/scripts/prueba-haproxy.sh" [servicio] [instancia]
#   servicio  = users | products | orders   (por defecto: users)
#   instancia = 1 | 2                        (por defecto: 1)
#
# 1. Muestra el round-robin (cabecera X-Backend-Server)
# 2. Tumba un contenedor y lanza peticiones MIENTRAS HAProxy detecta la caida
# 3. Muestra el servidor en DOWN y que el otro sigue respondiendo (0 errores)
# 4. Levanta el contenedor y muestra que vuelve a UP

HAPROXY=${HAPROXY:-192.168.100.2}
MICRO=${MICRO:-192.168.100.3}
SVC=${1:-users}
N=${2:-1}
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"

estado() {
  curl -s -u admin:admin123 "http://$HAPROXY:8080/stats;csv" \
    | awk -F, -v b="${SVC}_back" '$1==b && $2!="FRONTEND" && $2!="BACKEND" {printf "   %-10s %s\n", $2, $18}'
}

pedir() {  # $1 = cantidad de peticiones
  ok=0; err=0
  for i in $(seq 1 "$1"); do
    code=$(curl -s -o /tmp/resp -w '%{http_code}' -m 3 "http://$HAPROXY/api/$SVC")
    if [ "$code" = "200" ]; then ok=$((ok+1)); echo "   [$code] $(cat /tmp/resp)"; else err=$((err+1)); echo "   [$code] ERROR"; fi
    sleep 0.3
  done
  echo "   ---> OK=$ok  ERRORES=$err"
}

echo "== 1. Round-robin en /api/$SVC (6 peticiones) =="
for i in 1 2 3 4 5 6; do
  curl -s -i "http://$HAPROXY/api/$SVC" | tr -d '\r' \
    | awk 'tolower($1)=="x-backend-server:" {srv=$2} /^$/ {body=1; next} body {printf "   servidor=%-10s %s\n", srv, $0}'
done
echo; echo "Estado inicial:"; estado

echo; echo "== 2. docker stop ${SVC}-service-${N} y peticiones durante la deteccion =="
$SSH vagrant@"$MICRO" "docker stop ${SVC}-service-${N}" >/dev/null && echo "   contenedor ${SVC}-service-${N} detenido"
pedir 12

echo; echo "== 3. Estado segun HAProxy (debe verse DOWN) =="; estado

echo; echo "== 4. docker start ${SVC}-service-${N} =="
$SSH vagrant@"$MICRO" "docker start ${SVC}-service-${N}" >/dev/null && echo "   contenedor levantado, esperando health checks (rise 2 x 2s)..."
sleep 6; estado
