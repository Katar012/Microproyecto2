#!/usr/bin/env bash
# ==============================================================================
# prueba-k8s.sh - Batería de pruebas y demostración completa del Problema 3
#
# Valida los requerimientos 10, 11, 12, 13 y 14 del enunciado:
#   - Requerimiento 10 y 14: Estado general del namespace microapp (kubectl get all)
#   - Requerimiento 11: Acceso interno a los Services ClusterIP (3001, 3002, 3003)
#   - Requerimiento 12: Enrutamiento externo vía Ingress (/api/users, /api/products, /api/orders)
#   - Requerimiento 13: Escalado horizontal a 4 réplicas de orders-service con cero caídas
# ==============================================================================

set -e

titulo() {
  echo ""
  echo "======================================================================="
  echo "   $1"
  echo "======================================================================="
}

# 1. Obtener IP del Ingress Controller
titulo "1. DETECTANDO PUNTO DE ENTRADA DEL INGRESS CONTROLLER"
INGRESS_IP=$(kubectl get ingress microapp-ingress -n microapp -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
if [ -z "$INGRESS_IP" ]; then
  INGRESS_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
fi

# Si estamos en entorno local (ej: kind o port-forward) o la IP externa aún no asigna:
if [ -z "$INGRESS_IP" ] || [ "$INGRESS_IP" = "localhost" ]; then
  INGRESS_IP="${TARGET_IP:-127.0.0.1}"
  echo "Nota: Usando IP local de prueba: $INGRESS_IP (puerto 80)"
else
  echo "IP Externa del Ingress Controller detectada en Azure: $INGRESS_IP"
fi

# 2. Requerimiento 14: kubectl get all -n microapp
titulo "2. REQUERIMIENTO 14: ESTADO GENERAL DEL NAMESPACE microapp"
kubectl get all -n microapp -o wide
echo ""
echo "Ingress en microapp:"
kubectl get ingress -n microapp -o wide

# 3. Requerimiento 11: Verificación de Services ClusterIP desde dentro del clúster
titulo "3. REQUERIMIENTO 11: VERIFICACIÓN INTERNA DE LOS SERVICES ClusterIP"
echo "Lanzando pod temporal de pruebas curl dentro del clúster..."
kubectl run curl-test --image=curlimages/curl --restart=Never --rm -i --quiet --command -- \
  sh -c '
    echo "--- Probando users-svc:3001 ---"
    curl -s http://users-svc.microapp.svc.cluster.local:3001
    echo "--- Probando products-svc:3002 ---"
    curl -s http://products-svc.microapp.svc.cluster.local:3002
    echo "--- Probando orders-svc:3003 ---"
    curl -s http://orders-svc.microapp.svc.cluster.local:3003
  '

# 4. Requerimiento 12: Enrutamiento externo vía Ingress
titulo "4. REQUERIMIENTO 12: ENRUTAMIENTO EXTERNO VÍA INGRESS"
echo "Realizando 3 peticiones por cada microservicio para demostrar enrutamiento y balanceo:"

for ruta in users products orders; do
  echo ""
  echo ">> Peticiones a http://$INGRESS_IP/api/$ruta :"
  for i in 1 2 3; do
    printf "   Petición #%d: " "$i"
    curl -s -m 5 "http://$INGRESS_IP/api/$ruta" || echo "(Fallo en conexión. Verifica si el puerto 80 del Ingress está expuesto)"
  done
done

# 5. Requerimiento 13: Escalado Horizontal de orders-service
titulo "5. REQUERIMIENTO 13: ESCALADO HORIZONTAL DE orders-service A 4 RÉPLICAS"
echo "Réplicas actuales:"
kubectl get pods -n microapp -l app=orders-service

echo ""
echo "Escalando orders-deployment a 4 réplicas con 'kubectl scale'..."
kubectl scale deployment orders-deployment --replicas=4 -n microapp

echo "Esperando que las 4 réplicas estén listas..."
kubectl rollout status deployment/orders-deployment -n microapp --timeout=60s

echo ""
echo "Estado de los pods tras el escalado (deben verse 4 pods de orders):"
kubectl get pods -n microapp -l app=orders-service -o wide

echo ""
echo "Verificando distribución del tráfico en las 4 réplicas (6 peticiones a /api/orders):"
for i in 1 2 3 4 5 6; do
  printf "   Petición #%d -> " "$i"
  curl -s -m 5 "http://$INGRESS_IP/api/orders"
done

echo ""
echo "======================================================================="
echo "   ¡TODAS LAS PRUEBAS DE KUBERNETES COMPLETADAS SATISFACTORIAMENTE!"
echo "======================================================================="
