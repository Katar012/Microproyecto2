# 📋 Índice

* [¿Que hay hecho?](#que-hay-hecho)
* [1. Infraestructura](#1-infraestructura)
  * [1.1. Chef](#11-chef)
  * [1.2. Cambios y arreglos que le metí](#12-cambios-y-arreglos-que-le-meti)
* [2. HAProxy](#2-haproxy)
  * [¿Que hace haproxy.cfg?](#que-hace-haproxycfg)
  * [Mejoras que le cuadré al balanceo](#mejoras-que-le-cuadre-al-balanceo)
* [3. Kubernetes (Punto 3 Terminado)](#3-kubernetes)
  * [3.1. Arquitectura de los Manifiestos](#31-arquitectura-de-los-manifiestos)
  * [3.2. Scripts listos para Azure y Local](#32-scripts-listos-para-azure-y-local)
  * [3.3. Opcional: Terraform + AKS](#33-opcional-terraform--aks)
* [4. Probar](#4-probar)
  * [Probar Infraestructura](#probar-infraestructura)
  * [Probar HAProxy](#probar-haproxy)
  * [Probar Kubernetes](#probar-kubernetes)
* [NOTAS PARA DESARROLLO Y SUSTENTACIÓN](#notas-para-desarrollo)
  * [ARBOL DE CARPETAS ACTUALIZADO](#arbol-de-carpetas)

---

# <a id="que-hay-hecho"></a>¿Que hay hecho?

1. Infraestructura :white_check_mark: (LISTO: arreglado el ciclo reproducible de `terraform destroy` y `terraform apply`, autenticación con llaves SSH y memoria optimizada para que no estalle la máquina).
2. HAProxy :white_check_mark: (LISTO: sincronizado con los atributos de Chef, health checks dinámicos, redispatch ante caídas sin errores para el cliente, dashboard seguro y script de prueba automática).
3. Kubernetes :white_check_mark: (LISTO: Namespace `microapp`, Deployments con 2 réplicas cada uno, Services ClusterIP, Ingress NGINX por rutas `/api/*`, escalado horizontal a 4 réplicas con cero caída, scripts de Azure AKS + Local con Kind/Minikube + Opcional de Terraform).

---

# <a id="1-infraestructura"></a>1. Infraestructura

Es un `Vagrantfile` que crea 3 VMs Ubuntu 22.04:
- `control-node` (192.168.100.10): La máquina administradora donde corre Terraform y Chef Workstation.
- `vm-haproxy` (192.168.100.2): Nodo donde corre el balanceador HAProxy.
- `vm-microservices` (192.168.100.3): Nodo donde corren Docker y los contenedores de los microservicios.

El `Vagrantfile` aprovisiona la máquina `control-node`, genera llaves SSH, las distribuye a las otras 2 VMs y lanza Terraform.  
Terraform se conecta mediante SSH por llave a `vm-haproxy` y `vm-microservices`, les transfiere la carpeta `/chef` y ejecuta `cinc-client` (Chef de código abierto) en modo local (chef-zero).

> 📌 **NOTA:** El `Vagrantfile` monta una carpeta compartida desde la raíz del repo (`/vagrant`) hacia el `control-node`.

### <a id="11-chef"></a>1.1. Chef

Chef tiene cookbooks modulares dentro de `/chef/cookbooks/`:

1. `/docker/`: Instala Docker Engine, dependencias, GPG oficial de Docker y agrega el usuario `vagrant` al grupo docker.
2. `/microservices/`: Despliega los contenedores de `users-service`, `products-service` y `orders-service` (2 instancias por servicio) con reinicio automático (`restart: always`).
3. `/haproxy/`: Instala HAProxy y genera el archivo `/etc/haproxy/haproxy.cfg` a partir de una plantilla dinámica (`haproxy.cfg.erb`).

Estructura de roles y nodos:
- En `/chef/roles/`:
  - `microservices.rb`: Invoca `recipe[docker]` y `recipe[microservices]`.
  - `haproxy.rb`: Invoca `recipe[haproxy]`.
- En `/chef/nodes/`:
  - `vm-microservices.json`: Le asigna el rol `microservices` al nodo.
  - `vm-haproxy.json`: Le asigna el rol `haproxy` al nodo.

### <a id="12-cambios-y-arreglos-que-le-meti"></a>1.2. Cambios y arreglos que le metí (Pepe / Alejandro)

Mano, revisé todo con lupa y cuadré varias cositas que nos podían hacer perder puntos con el profe:

1. **Memoria de las VMs en `Vagrantfile`:** El Vagrantfile pedía 3GB + 3GB + 2GB = 8GB de RAM. Como muchos portátiles tienen 8GB o 16GB con apps abiertas, eso iba a crashear por falta de RAM física. Le bajé a 1GB para haproxy, 1.5GB para microservices y 1GB para control-node (~3.5GB en total). Con eso vuela y los contenedores `http-echo` solo pesan como 5MB cada uno.
2. **Ciclo reproducible `terraform destroy` y `terraform apply` (Requerimiento 4):**
   - Antes Terraform solo creaba con `null_resource`, pero si tirabas `terraform destroy` no borraba nada en las VMs destino.
   - Le metí un `provisioner "remote-exec" { when = destroy }` a cada máquina en `main.tf`. Ahora si ejecutas `terraform destroy`, se conecta por SSH a las VMs y purga los contenedores, Docker, HAProxy y Cinc, dejándolas como recién salidas de fábrica.
   - Al volver a correr `terraform apply`, reconstruye absolutamente todo desde cero sin intervención manual. ¡Cumple el 100% de la reproducibilidad que pide el parcial!
3. **Autenticación SSH por Llave (Requerimiento 1):** El enunciado pide explícitamente "llaves SSH correspondientes". En lugar de meter contraseñas en plano en Terraform, ahora Terraform usa `/home/vagrant/.ssh/id_rsa` para conectarse a las máquinas target.
4. **Idempotencia con Triggers y Hashes:** Si modificas una receta de Chef, Terraform calcula un `sha1` de los archivos y sabe exactamente cuál VM tiene cambios pendientes sin tener que destruir la otra.

---

# <a id="2-haproxy"></a>2. HAProxy

En el cookbook `/haproxy/` la receta instala el paquete `haproxy` y renderiza el template `haproxy.cfg.erb`.

### <a id="que-hace-haproxycfg"></a>¿Que hace haproxy.cfg?

1. **Frontend en puerto 80:** Recibe todo el tráfico externo y clasifica mediante ACLs según el prefijo:
   - `/api/users` -> redirige al backend `users_back`
   - `/api/products` -> redirige al backend `products_back`
   - `/api/orders` -> redirige al backend `orders_back`
   - Cualquier otra ruta -> devuelve un 404 limpio indicando las rutas válidas.
2. **Backends con Round-Robin:** Cada backend tiene 2 servidores apuntando a `vm-microservices`:
   - `users`: puertos 3001 y 3011 (ambos mapeados al puerto interno 3001 del microservicio).
   - `products`: puertos 3002 y 3012 (mapeados al puerto interno 3002).
   - `orders`: puertos 3003 y 3013 (mapeados al puerto interno 3003).
3. **Dashboard de Estadísticas en puerto 8080:** Protegido con usuario `admin` y clave `admin123`.

### <a id="mejoras-que-le-cuadre-al-balanceo"></a>Mejoras que le cuadré al balanceo

1. **Fuente Única de Verdad (Atributos):** Creé `chef/cookbooks/microservices/attributes/default.rb` y `haproxy/attributes/default.rb`. Ahora los puertos, número de réplicas e IPs están en atributos compartidos. Si el profe te dice en caliente *"agrega una tercera réplica de orders"*, solo cambias `instances: 3` en atributos y le das `terraform apply`, sin tener que modificar a mano ni recetas ni el archivo `.cfg`.
2. **Tolerancia a fallos inmediata (`option redispatch` y `retries 3`):** Si tumbas un contenedor, mientras HAProxy detecta el fallo en 2-4 segundos, las peticiones que alcancen a pegarle al puerto caído se reenvían automáticamente al otro contenedor vivo. El cliente nunca ve un error 502/503.
3. **Cabecera `X-Backend-Server`:** Le agregué al HAProxy que devuelva en los headers el nombre del servidor (`users1`, `users2`, etc.). Con eso demuestras el round-robin en vivo de manera clarísima en el curl.
4. **Script de prueba automatizado:** Creé `scripts/prueba-haproxy.sh` para demostrar en vivo el round-robin, tumbar un contenedor con `docker stop`, mostrar que se marca en `DOWN` en el dashboard y que el servicio sigue respondiendo sin interrupciones.

---

# <a id="3-kubernetes"></a>3. Kubernetes (Punto 3 Terminado)

Para el Problema 3 creamos la carpeta `3. Kubernetes/` con todos los manifiestos declarativos y scripts de despliegue.

### <a id="31-arquitectura-de-los-manifiestos"></a>3.1. Arquitectura de los Manifiestos (`3. Kubernetes/manifests/`)

- `00-namespace.yaml`: Crea el namespace aislado `microapp`.
- `01-users.yaml`: 
  - `Deployment`: 2 réplicas de `hashicorp/http-echo:1.0.0` escuchando en su puerto interno `3001`. Mediante la Downward API de K8s, inyectamos el nombre del Pod (`$(POD_NAME)`) en la respuesta HTTP para evidenciar el balanceo. Incluye `livenessProbe` y `readinessProbe`.
  - `Service`: Tipo `ClusterIP`, exponiendo el puerto `3001` hacia el clúster.
- `02-products.yaml`: 
  - `Deployment`: 2 réplicas en puerto interno `3002`.
  - `Service`: Tipo `ClusterIP`, exponiendo el puerto `3002`.
- `03-orders.yaml`: 
  - `Deployment`: 2 réplicas iniciales en puerto interno `3003` (listo para escalar a 4).
  - `Service`: Tipo `ClusterIP`, exponiendo el puerto `3003`.
- `04-ingress.yaml`: Ingress con clase `nginx` que enruta el tráfico externo:
  - `/api/users` -> `users-svc:3001`
  - `/api/products` -> `products-svc:3002`
  - `/api/orders` -> `orders-svc:3003`

### <a id="32-scripts-listos-para-azure-y-local"></a>3.2. Scripts listos para Azure y Local (`3. Kubernetes/scripts/`)

- `deploy-aks.sh`: Automatiza la creación en Azure:
  1. Valida la sesión de Azure CLI / Cloud Shell.
  2. Registra proveedores `Microsoft.Compute` y `Microsoft.ContainerService`.
  3. Crea el Resource Group `rg-microapp-aks` en región económica (`eastus`).
  4. Levanta el clúster AKS con tamaño económico para suscripción estudiante (`Standard_B2s`).
  5. Instala el Ingress Controller NGINX oficial.
  6. Aplica todos los manifiestos YAML de `manifests/`.
- `destroy-aks.sh`: **¡Súper importante para los créditos!** Ejecutas `bash destroy-aks.sh` y elimina el Resource Group completo en Azure para no gastar los 100 USD de estudiante.
- `prueba-k8s.sh`: Script que ejecuta en orden todas las verificaciones exigidas por el profesor:
  - `kubectl get all -n microapp` y `kubectl get ingress` (Requerimiento 14).
  - Prueba de conectividad interna a los ClusterIP Services (Requerimiento 11).
  - Pruebas externas con `curl` hacia el Ingress en `/api/users`, `/api/products`, `/api/orders` (Requerimiento 12).
  - Escalado horizontal de `orders-deployment` a 4 réplicas con `kubectl scale` y verificación de tráfico en las 4 instancias sin cortes (Requerimiento 13).
- `deploy-local.sh`: Permite desplegar y probar todo localmente con `kind` o `minikube` sin gastar ni un peso de Azure.

### <a id="33-opcional-terraform--aks"></a>3.3. Opcional: Terraform + AKS (`3. Kubernetes/terraform-aks/`)

Incluimos los archivos `.tf` (`main.tf`, `variables.tf`, `providers.tf`, `outputs.tf`) para desplegar AKS automáticamente usando Terraform, por si el profe pregunta por el punto opcional.

---

# <a id="4-probar"></a>4. Probar

### <a id="probar-infraestructura"></a>4.1. Probar Infraestructura (Problema 1)

1. En tu máquina anfitriona, en la raíz del repo:
   ```bash
   vagrant up
   ```
   *(Esto crea las 3 máquinas virtuales y ejecuta automáticamente el provisioner de Terraform + Chef)*.
2. Entra al nodo de control:
   ```bash
   vagrant ssh control-node
   ```
3. Verifica el estado inicial de toda la infraestructura con el script de verificación:
   ```bash
   bash "/vagrant/1-2. Infraestructura/scripts/verificar.sh"
   ```
4. **Demostración de Reproducibilidad (terraform destroy / apply):**
   ```bash
   cd "/vagrant/1-2. Infraestructura/terraform"
   
   # 1. Destruye el aprovisionamiento
   terraform destroy -auto-approve
   
   # Verifica que los contenedores y HAProxy fueron eliminados limpiamente
   ssh vm-microservices "docker ps"              # Sale vacío
   ssh vm-haproxy "systemctl status haproxy"     # No instalado / inactivo
   
   # 2. Vuelve a aprovisionar
   terraform apply -auto-approve
   
   # 3. Verifica que todo volvió a quedar idéntico y funcional
   bash "/vagrant/1-2. Infraestructura/scripts/verificar.sh"
   ```

### <a id="probar-haproxy"></a>4.2. Probar HAProxy (Problema 2)

1. **Dashboard web:**
   Abre en el navegador de tu máquina host:  
   👉 [http://192.168.100.2:8080/stats](http://192.168.100.2:8080/stats)  
   Usuario: `admin` | Contraseña: `admin123`  
   *(Verás los backends `users_back`, `products_back` y `orders_back` en verde / UP)*.
2. **Prueba automática de Balanceo y Failover:**
   Desde el `control-node`:
   ```bash
   bash "/vagrant/1-2. Infraestructura/scripts/prueba-haproxy.sh" users 1
   ```
   El script hace:
   - 6 peticiones a `/api/users` mostrando cómo alterna entre `users1` y `users2` (Round-Robin).
   - Detiene el contenedor `users-service-1` con `docker stop`.
   - Lanza peticiones continuas demostrando que el cliente no sufre caídas (0 errores).
   - Muestra el servidor en estado `DOWN` en HAProxy.
   - Vuelve a iniciar el contenedor con `docker start` y muestra su recuperación a `UP`.

### <a id="probar-kubernetes"></a>4.3. Probar Kubernetes (Problema 3)

#### En Azure AKS (Para la Sustentación):
1. Abre Azure Cloud Shell (o tu terminal con `az login`) y clona el repositorio en la rama `problema3pepe`:
   ```bash
   git clone -b problema3pepe https://github.com/Katar012/Microproyecto2.git
   cd Microproyecto2/"3. Kubernetes"/scripts
   ```
2. Despliega el clúster y la aplicación:
   ```bash
   bash deploy-aks.sh
   ```
3. Ejecuta la batería de pruebas requerida por el profesor:
   ```bash
   bash prueba-k8s.sh
   ```
4. **¡DESTRUIR EL CLÚSTER AL TERMINAR LA SUSTENTACIÓN!**:
   ```bash
   bash destroy-aks.sh
   ```

#### En Local (Para ensayar sin costo):
```bash
cd "3. Kubernetes/scripts"
bash deploy-local.sh
bash prueba-k8s.sh
```

---

# <a id="notas-para-desarrollo"></a>NOTAS PARA DESARROLLO Y SUSTENTACIÓN

* **Guía Completa para Exponer:** Revisa el archivo [`GUIA_SUSTENTACION.md`](./GUIA_SUSTENTACION.md). Contiene el guión paso a paso de qué decir, cómo funciona cada componente, y cómo responder a cualquier cambio en caliente que pida el profesor.
* Contraseña de las VMs de Vagrant: `vagrant`
* Dashboard de HAProxy: [http://192.168.100.2:8080/stats](http://192.168.100.2:8080/stats) (`admin / admin123`).
* Namespace de Kubernetes: `microapp`.
* **¡OJO CON LOS CRÉDITOS DE AZURE!** No dejes el clúster de AKS prendido de noche. Destrúyelo con `destroy-aks.sh`.

### <a id="arbol-de-carpetas"></a>ARBOL DE CARPETAS ACTUALIZADO

```text
Microproyecto2/
├── .gitattributes
├── .gitignore
├── GUIA_SUSTENTACION.md
├── README.md
├── Vagrantfile
├── 1-2. Infraestructura/
│   ├── chef/
│   │   ├── cookbooks/
│   │   │   ├── docker/
│   │   │   │   ├── metadata.rb
│   │   │   │   └── recipes/
│   │   │   │       └── default.rb
│   │   │   ├── haproxy/
│   │   │   │   ├── attributes/
│   │   │   │   │   └── default.rb
│   │   │   │   ├── metadata.rb
│   │   │   │   ├── notas.txt
│   │   │   │   ├── recipes/
│   │   │   │   │   └── default.rb
│   │   │   │   └── templates/
│   │   │   │       └── default/
│   │   │   │           └── haproxy.cfg.erb
│   │   │   ├── microservices/
│   │   │   │   ├── attributes/
│   │   │   │   │   └── default.rb
│   │   │   │   ├── metadata.rb
│   │   │   │   └── recipes/
│   │   │   │       └── default.rb
│   │   │   └── notas.txt
│   │   ├── nodes/
│   │   │   ├── notas.txt
│   │   │   ├── vm-haproxy.json
│   │   │   └── vm-microservices.json
│   │   ├── roles/
│   │   │   ├── haproxy.rb
│   │   │   ├── microservices.rb
│   │   │   └── notas.txt
│   │   ├── notas.txt
│   │   └── solo.rb
│   ├── scripts/
│   │   ├── prueba-haproxy.sh
│   │   └── verificar.sh
│   └── terraform/
│       ├── main.tf
│       ├── outputs.tf
│       ├── providers.tf
│       └── variables.tf
└── 3. Kubernetes/
    ├── manifests/
    │   ├── 00-namespace.yaml
    │   ├── 01-users.yaml
    │   ├── 02-products.yaml
    │   ├── 03-orders.yaml
    │   └── 04-ingress.yaml
    ├── scripts/
    │   ├── deploy-aks.sh
    │   ├── deploy-local.sh
    │   ├── destroy-aks.sh
    │   └── prueba-k8s.sh
    └── terraform-aks/
        ├── main.tf
        ├── outputs.tf
        ├── providers.tf
        └── variables.tf
```
