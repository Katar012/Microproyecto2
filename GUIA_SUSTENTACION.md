# 🎓 GUÍA MAESTRA DE SUSTENTACIÓN Y REFERENCIA TÉCNICA
### Computación en la Nube · Universidad Autónoma de Occidente (UAO)
**Proyecto:** Comercio Electrónico Basado en Microservicios (Microproyecto 2)  
**Autores:** Equipo de Trabajo  

---

## 📑 ÍNDICE DE CONTENIDOS
1. [Visión General y Arquitectura de la Solución](#1-visión-general)
2. [Problema 1: Aprovisionamiento con Terraform y Chef](#2-problema-1)
3. [Problema 2: Balanceo de Carga Perimetral con HAProxy](#3-problema-2)
4. [Problema 3: Orquestación Cloud-Native con Kubernetes en Azure AKS](#4-problema-3)
5. [Guión Paso a Paso para la Sustentación Oral](#5-guión-para-la-sustentación)
6. [Catálogo de Preguntas Conceptuales y Cambios en Caliente](#6-catálogo-de-cambios-en-caliente)

---

# <a id="1-visión-general"></a>1. Visión General y Arquitectura de la Solución

El proyecto aborda el diseño, aprovisionamiento, balanceo y orquestación de una plataforma de comercio electrónico desacoplada en tres microservicios esenciales:

1. **`users-service`** (Puerto interno `3001`): Autenticación, perfiles y gestión de sesiones.
2. **`products-service`** (Puerto interno `3002`): Catálogo, existencias de inventario e imágenes.
3. **`orders-service`** (Puerto interno `3003`): Registro y ciclo de vida de los pedidos.

### Comparativa Arquitectónica de las Fases del Proyecto

| Característica | Fase Local (Problemas 1 y 2) | Fase Cloud-Native (Problema 3) |
| :--- | :--- | :--- |
| **Entorno de Ejecución** | Máquinas Virtuales Ubuntu 22.04 (VirtualBox) | Clúster Gestionado de Kubernetes (Azure AKS) |
| **Herramienta de IaC** | Terraform (`null_resource` + SSH) | Azure CLI / Terraform (`azurerm_kubernetes_cluster`) |
| **Gestor de Configuración** | Chef (Cinc-Client en modo Chef-Zero) | Manifiestos Declarativos YAML (`kubectl`) |
| **Aislamiento de Cargas** | Docker Engine + Docker Compose | Pods de Kubernetes en Namespace dedicado `microapp` |
| **Punto de Entrada HTTP** | HAProxy en puerto `80` con reglas ACL por path | Ingress Controller NGINX con reglas de Ingress Path |
| **Descubrimiento de Servicios** | Direcciones IP fijas (`192.168.100.3:<puerto>`) | Services de Kubernetes tipo `ClusterIP` con DNS interno |
| **Resiliencia** | `retries 3` + `option redispatch` en HAProxy | ReplicaSets de Kubernetes (Self-Healing) + Probes |
| **Escalabilidad** | Estática (instancias mapeadas en `haproxy.cfg`) | Dinámica y elástica (`kubectl scale` / HPA) |

---

# <a id="2-problema-1"></a>2. Problema 1: Aprovisionamiento con Terraform y Chef

### 2.1. Topología del Laboratorio en Vagrant
El archivo `Vagrantfile` define tres nodos interconectados mediante una red privada interna (`192.168.100.0/24`):

1. **`control-node` (`192.168.100.10`):** 
   - 2 vCPUs, 1024 MB de memoria RAM.
   - Actúa como servidor de administración. Durante su inicio, instala `terraform`, `chef-workstation`, genera el par de llaves SSH (`/home/vagrant/.ssh/id_rsa`), las copia hacia los nodos destino y ejecuta automáticamente `terraform apply`.
2. **`vm-haproxy` (`192.168.100.2`):** 
   - 2 vCPUs, 1024 MB de memoria RAM.
   - Nodo de balanceo perimetral.
3. **`vm-microservices` (`192.168.100.3`):** 
   - 2 vCPUs, 1536 MB de memoria RAM.
   - Nodo de cómputo donde se ejecutan Docker Engine y los contenedores de los microservicios.

> **Optimización de Recursos:** La asignación original de memoria del laboratorio (8 GB) fue redimensionada a 3.5 GB en total, permitiendo que el entorno virtualice con total fluidez en portátiles de 8 GB o 16 GB sin riesgo de congelamiento.

---

### 2.2. Aprovisionamiento con Terraform (`1-2. Infraestructura/terraform/`)

En lugar de crear máquinas en una nube pública, Terraform administra aquí el ciclo de vida de configuración sobre máquinas locales ya encendidas utilizando el proveedor oficial `hashicorp/null` y provisioners de conexión SSH.

* **Autenticación SSH Criptográfica:**  
  En `variables.tf` y `main.tf`, la conexión SSH se define mediante llave privada:
  ```hcl
  connection {
    type        = "ssh"
    host        = self.triggers.host
    user        = self.triggers.user
    private_key = file(self.triggers.key_path)
  }
  ```
  Esto elimina contraseñas en texto plano y cumple el requerimiento formal de seguridad.

* **Detección de Cambios e Idempotencia (`triggers`):**  
  Para evitar re-aprovisionar máquinas cuando no hay cambios, Terraform calcula la huella criptográfica SHA1 de todos los archivos relevantes de Chef:
  ```hcl
  triggers = {
    host      = var.microservices_ip
    user      = var.ssh_user
    key_path  = var.ssh_private_key_path
    chef_hash = local.hash_microservices
  }
  ```
  Si se modifica un archivo en `cookbooks/microservices/`, únicamente se vuelve a provisionar `vm-microservices`.

* **Validación de Entorno:**  
  Antes de iniciar, Terraform valida formalmente mediante un script `remote-exec` que el sistema operativo destino sea exactamente `Ubuntu 22.04` consultando `/etc/os-release`. Si no coincide, aborta de inmediato.

* **Garantía de Reproducibilidad (`when = destroy`):**  
  El requerimiento 4 del proyecto exige que la infraestructura se pueda destruir con `terraform destroy` y recrear con `terraform apply` de forma idéntica sin intervención manual. Para lograrlo, cada recurso implementa un bloque de limpieza profunda:
  ```hcl
  provisioner "remote-exec" {
    when = destroy
    inline = [
      "if [ -f /opt/microapp/docker-compose.yml ]; then sudo docker compose -f /opt/microapp/docker-compose.yml down -v; fi",
      "sudo systemctl disable --now docker.socket docker containerd",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get purge -y docker-ce docker-ce-cli containerd.io docker-compose-plugin cinc",
      "sudo rm -rf /var/lib/docker /tmp/chef /opt/cinc /opt/microapp"
    ]
  }
  ```
  Al ejecutar `terraform destroy`, la máquina queda completamente limpia. Al dar `terraform apply`, se reconstruye todo automáticamente.

---

### 2.3. Configuración y Orquestación con Chef (`1-2. Infraestructura/chef/`)

Chef es un sistema de gestión de configuración basado en Ruby. En este proyecto se utiliza **Chef-Zero** (mediante el cliente open-source `cinc-client` con la bandera `-z`), ejecutando recetas en memoria de manera local sin la complejidad ni costos de un servidor Chef Server central.

#### Componentes del Cookbook:
1. **`solo.rb`:** Configura los paths locales de Chef en la máquina destino:
   ```ruby
   file_cache_path "/tmp/chef/cache"
   cookbook_path   ["/tmp/chef/cookbooks"]
   role_path       ["/tmp/chef/roles"]
   ```
2. **`cookbooks/docker/recipes/default.rb`:**
   - Detecta dinámicamente la arquitectura de la CPU (`amd64` o `arm64`).
   - Descarga e instala la llave GPG oficial de Docker en `/etc/apt/keyrings/docker.gpg`.
   - Agrega el repositorio oficial de Docker a `/etc/apt/sources.list.d/docker.list`.
   - Instala `docker-ce`, `docker-ce-cli`, `containerd.io` y `docker-compose-plugin`.
   - Habilita e inicia el demonio de Docker e incorpora al usuario `vagrant` en el grupo `docker`.
3. **`cookbooks/microservices/attributes/default.rb` (Fuente Única de Verdad):**  
   Define la estructura central de la aplicación:
   ```ruby
   default['microapp']['image'] = 'hashicorp/http-echo:1.0.0'
   default['microapp']['port_step'] = 10
   default['microapp']['services'] = {
     'users'    => { 'port' => 3001, 'instances' => 2 },
     'products' => { 'port' => 3002, 'instances' => 2 },
     'orders'   => { 'port' => 3003, 'instances' => 2 },
   }
   ```
4. **`cookbooks/microservices/templates/default/docker-compose.yml.erb`:**  
   En lugar de comandos imperativos sueltos de `docker run`, Chef genera el archivo declarativo estándar `/opt/microapp/docker-compose.yml`.
   - Cada contenedor se configura con política `restart: always`.
   - Los puertos de host se calculan dinámicamente (`3001` y `3011` para users, `3002` y `3012` para products, `3003` y `3013` para orders).
   - El puerto interno en el contenedor se mantiene siempre en el puerto base asignado (`3001`, `3002`, `3003`).
5. **`cookbooks/microservices/recipes/default.rb`:**  
   Renderiza el template y ejecuta la orquestación:
   ```bash
   docker compose -f /opt/microapp/docker-compose.yml up -d --remove-orphans
   ```

---

# <a id="3-problema-2"></a>3. Problema 2: Balanceo de Carga Perimetral con HAProxy

HAProxy (High Availability Proxy) es un balanceador de carga y proxy inverso de alto rendimiento para protocolos TCP (Capa 4) y HTTP (Capa 7).

### 3.1. Arquitectura de `haproxy.cfg`

El archivo de configuración `/etc/haproxy/haproxy.cfg` es compilado por Chef desde la plantilla `haproxy.cfg.erb`:

```text
                                CLIENTE EXTERNO
                                       │
                             HTTP GET /api/users
                                       ▼
                       +───────────────────────────────+
                       |    vm-haproxy (192.168.100.2)  |
                       |       frontend http_front     |
                       |            (Puerto 80)        |
                       +───────────────────────────────+
                                       │
                    ┌──────────────────┴──────────────────┐
        path_beg /api/users                   path_beg /api/products
                    │                                     │
                    ▼                                     ▼
        +───────────────────────+             +───────────────────────+
        |   backend users_back  |             | backend products_back |
        |   balance roundrobin  |             |   balance roundrobin  |
        +───────────────────────+             +───────────────────────+
           │                 │
     Round-Robin       Round-Robin
           │                 │
           ▼                 ▼
   users1 (3001)       users2 (3011)
  (En vm-microservices: 192.168.100.3)
```

#### 1. Sección `frontend http_front`:
- Escucha en `bind *:80`.
- Evalúa el prefijo de la URL mediante Listas de Control de Acceso (ACLs):
  ```haproxy
  acl is_users    path_beg /api/users
  acl is_products path_beg /api/products
  acl is_orders   path_beg /api/orders

  use_backend users_back    if is_users
  use_backend products_back if is_products
  use_backend orders_back   if is_orders

  default_backend not_found
  ```
- Si entra una petición a una ruta no registrada, el `backend not_found` responde un código `404` descriptivo.

#### 2. Sección `backend <servicio>_back`:
- **Algoritmo de Balanceo:** `balance roundrobin`, el cual distribuye uniformemente las peticiones entre los servidores activos.
- **Trazabilidad HTTP:** Inserta en la respuesta del cliente la cabecera:
  ```haproxy
  http-response set-header X-Backend-Server %[srv_name]
  ```
  Esto permite validar en las pruebas de `curl -i` el nombre del servidor exacto que atendió la solicitud.
- **Health Checking en Capa 7:**
  ```haproxy
  option httpchk GET /health
  http-check expect status 200
  server users1 192.168.100.3:3001 check inter 2s fall 2 rise 2
  server users2 192.168.100.3:3011 check inter 2s fall 2 rise 2
  ```
  - `inter 2s`: Inspección cada 2 segundos.
  - `fall 2`: Si el contenedor no responde durante 2 chequeos seguidos (4 segundos), se marca en estado `DOWN`.
  - `rise 2`: Al revivir, tras 2 chequeos exitosos consecutivos pasa nuevamente a `UP`.
- **Conmutación Inmediata sin Pérdida de Peticiones (`Zero-Downtime Failover`):**
  En la sección `defaults`:
  ```haproxy
  retries 3
  option redispatch
  ```
  Si un contenedor cae repentinamente mientras una petición HTTP está en tránsito, HAProxy detecta el corte en el socket TCP, cancela la conexión fallida y reenvía automáticamente la petición al otro servidor sano. El usuario nunca percibe errores `502 Bad Gateway` ni `503 Service Unavailable`.

#### 3. Panel de Estadísticas en Puerto 8080 (`listen stats`):
- Escucha en `bind *:8080`, independiente del puerto web.
- Protegido por autenticación HTTP Basic (`admin` / `admin123`).
- Permite observar el throughput, conteo de peticiones y estado de salud en tiempo real.

---

# <a id="4-problema-3"></a>4. Problema 3: Orquestación Cloud-Native con Kubernetes en Azure AKS

Kubernetes es el estándar de la industria para la orquestación automatizada de aplicaciones en contenedores. En esta fase, trasladamos la arquitectura desacoplada a un clúster gestionado de **Azure Kubernetes Service (AKS)**.

```text
                               INTERNET
                                  │
                                  ▼
                   +─────────────────────────────+
                   |  Ingress Controller (NGINX) |  <-- IP Pública Externa / Puerto 80
                   |       Ingress Resource      |
                   +─────────────────────────────+
                                  │
         ┌────────────────────────┼────────────────────────┐
   /api/users               /api/products            /api/orders
         │                        │                        │
         ▼                        ▼                        ▼
+──────────────────+     +──────────────────+     +──────────────────+
|  users-svc:3001  |     | products-svc:3002|     |  orders-svc:3003 |
| (Tipo ClusterIP) |     | (Tipo ClusterIP) |     | (Tipo ClusterIP) |
+──────────────────+     +──────────────────+     +──────────────────+
         │                        │                        │
   Endpoints                Endpoints                Endpoints
         │                        │                        │
    ┌────┴────┐              ┌────┴────┐         ┌────┬────┴────┬────┐
    ▼         ▼              ▼         ▼         ▼    ▼         ▼    ▼
 [Pod 1]   [Pod 2]        [Pod 1]   [Pod 2]    [Pod1][Pod2]   [Pod3][Pod4]
 (users-deployment)     (products-deployment)      (orders-deployment)
   (2 réplicas)             (2 réplicas)        (Escalado a 4 réplicas)
```

### 4.1. Manifiestos Declarativos (`3. Kubernetes/manifests/`)

1. **`00-namespace.yaml`:**
   Crea el espacio de nombres `microapp`. Proporciona aislamiento lógico para que los recursos de la tienda no colisionen con los componentes del sistema (`kube-system`, `ingress-nginx`).

2. **Deployments (`01-users.yaml`, `02-products.yaml`, `03-orders.yaml`):**
   - **Réplicas:** 2 réplicas por microservicio como estado deseado base.
   - **Imagen:** `hashicorp/http-echo:1.0.0` configurada para escuchar en su respectivo puerto interno (`3001`, `3002`, `3003`).
   - **Downward API:** Inyecta metadatos del Pod como variables de entorno:
     ```yaml
     env:
     - name: POD_NAME
       valueFrom:
         fieldRef:
           fieldPath: metadata.name
     ```
     El texto de respuesta HTTP incluye `pod: $(POD_NAME)`, permitiendo demostrar el balanceo visualizando cómo cambia el nombre del pod en cada `curl`.
   - **Sondas de Salud (Probes):**
     - `livenessProbe`: Comprueba que el proceso interno esté vivo. Si falla, el Kubelet reinicia el contenedor.
     - `readinessProbe`: Verifica si el pod está listo para recibir tráfico. Si falla, el pod es retirado temporalmente de los endpoints del Service.
   - **Políticas y Recursos:** `restartPolicy: Always`, con límites y solicitudes garantizadas de CPU y memoria.

3. **Services (`ClusterIP`):**
   - Exponen internamente los puertos `3001`, `3002` y `3003`.
   - **¿Por qué `ClusterIP`?** Es la mejor práctica de arquitectura en microservicios. Proporciona una IP virtual fija y un nombre DNS interno (`users-svc.microapp.svc.cluster.local`). Los microservicios no deben exponerse directamente a Internet; el único punto de contacto exterior debe ser el Ingress Controller.

4. **Ingress Resource (`04-ingress.yaml`):**
   - Utiliza la clase `ingressClassName: nginx`.
   - Define reglas de enrutamiento por prefijo de ruta (Prefix Path):
     - `/api/users` -> redirige a `users-svc:3001`
     - `/api/products` -> redirige a `products-svc:3002`
     - `/api/orders` -> redirige a `orders-svc:3003`

---

### 4.2. Automatización y Operación en Azure (`3. Kubernetes/scripts/`)

* **`deploy-aks.sh`:**
  Script integral que en ~5 minutos realiza:
  1. Validación de sesión en Azure CLI / Cloud Shell.
  2. Registro de los proveedores de nube `Microsoft.Compute` y `Microsoft.ContainerService`.
  3. Creación del Resource Group `rg-microapp-aks` en la región permitida para suscripciones académicas (`eastus`).
  4. Creación del clúster AKS con tamaño optimizado `Standard_B2s` (2 nodos).
  5. Instalación del Ingress Controller oficial de NGINX.
  6. Despliegue de los manifiestos de la aplicación en el namespace `microapp`.
* **`destroy-aks.sh`:**
  Ejecuta `az group delete --name rg-microapp-aks --yes --no-wait`. **Indispensable:** elimina todos los recursos de inmediato para proteger los 100 USD de crédito de la suscripción de estudiante.
* **`prueba-k8s.sh`:**
  Batería automatizada de pruebas técnicas que valida:
  1. `kubectl get all -n microapp` y `kubectl get ingress` (Requerimiento 14).
  2. Verificación interna de los Services ClusterIP mediante un pod transitorio (Requerimiento 11).
  3. Enrutamiento externo vía Ingress Controller con múltiples `curl` (Requerimiento 12).
  4. Demostración de escalabilidad horizontal aumentando `orders-deployment` a 4 réplicas con `kubectl scale` y validando distribución entre los 4 pods sin caída de servicio (Requerimiento 13).
* **`deploy-local.sh`:**
  Entorno de prueba local con KinD o Minikube para validar la arquitectura sin requerir conexión a Azure.

---

# <a id="5-guión-para-la-sustentación"></a>5. Guión Paso a Paso para la Sustentación Oral

Utiliza esta estructura ordenada para exponer de forma profesional y precisa:

### Minuto 0 a 1: Presentación y Contexto Arquitectónico
> *"Buenas tardes profesor. Nuestro proyecto implementa la arquitectura de infraestructura y orquestación para una plataforma de comercio electrónico basada en tres microservicios: Usuarios, Productos y Órdenes.*  
> *Desarrollamos la solución en tres niveles: primero, el aprovisionamiento automatizado e infraestructura como código con Terraform y Chef; segundo, el balanceo de carga de alta disponibilidad en Capa 7 con HAProxy; y tercero, la orquestación cloud-native con Kubernetes sobre Azure AKS con Ingress Controller y escalabilidad elástica horizontal."*

---

### Minuto 1 a 3: Demostración del Problema 1 (Terraform + Chef)
> *"Para el Problema 1, asumimos el reto opcional de implementar **Chef** en lugar de scripts o Ansible, para obtener la bonificación de 5 décimas.*  
> *Configuramos un nodo de control que orquesta mediante Terraform dos máquinas target: `vm-microservices` y `vm-haproxy`. La comunicación se realiza estrictamente por autenticación con llaves SSH.*  
> *En `vm-microservices`, Chef instala Docker nativo y despliega los microservicios usando **Docker Compose declarativo** a partir de una plantilla dinámica. Cada contenedor tiene asignado su puerto interno correspondiente (3001, 3002 y 3003) y política `restart: always`.*  
> *Para demostrar que el aprovisionamiento es 100% reproducible como lo exige el requerimiento 4, procederé a ejecutar `terraform destroy` para que observe la limpieza total de los nodos y luego `terraform apply` para reconstruir la infraestructura sin intervención manual."*

**Comandos a ejecutar:**
```bash
vagrant ssh control-node
cd "/vagrant/1-2. Infraestructura/terraform"

# 1. Mostrar estado inicial
bash "/vagrant/1-2. Infraestructura/scripts/verificar.sh"

# 2. Destruir infraestructura
terraform destroy -auto-approve

# 3. Mostrar que los nodos quedaron vacíos
ssh vm-microservices "docker ps"
ssh vm-haproxy "systemctl status haproxy"

# 4. Recrear todo idéntico
terraform apply -auto-approve

# 5. Confirmar operatividad
bash "/vagrant/1-2. Infraestructura/scripts/verificar.sh"
```

---

### Minuto 3 a 5: Demostración del Problema 2 (HAProxy)
> *"En el Problema 2, configuramos HAProxy en el puerto 80 como punto de entrada único de la solución.*  
> *Mediante reglas ACL enrutamos según el prefijo de la URL hacia los backends de usuarios, productos y órdenes. Cada backend distribuye la carga entre dos servidores mediante el algoritmo **Round-Robin**.*  
> *En el puerto 8080 tenemos habilitado el panel de estadísticas con autenticación (`admin` / `admin123`).*  
> *Para garantizar la alta disponibilidad, configuramos `retries 3` y `option redispatch`, junto con chequeos de salud cada 2 segundos. Si un contenedor se detiene, HAProxy lo detecta, lo marca en `DOWN` en el panel y redirige las peticiones entrantes de forma inmediata al servidor restante, manteniendo el servicio 100% disponible para el cliente sin arrojar errores."*

**Comandos a ejecutar:**
```bash
# 1. Abrir en el navegador el dashboard: http://192.168.100.2:8080/stats (admin / admin123)
# 2. Ejecutar la prueba automatizada de balanceo y failover:
bash "/vagrant/1-2. Infraestructura/scripts/prueba-haproxy.sh" users 1
```

---

### Minuto 5 a 8: Demostración del Problema 3 (Kubernetes en Azure AKS)
> *"Para el Problema 3, desplegamos la arquitectura en la nube con **Azure Kubernetes Service (AKS)** dentro del namespace dedicado `microapp`.*  
> *Cada microservicio se ejecuta en un Deployment con réplicas redundantes y puertos internos 3001, 3002 y 3003, expuestos mediante Services de tipo `ClusterIP` para mantener la seguridad perimetral.*  
> *El acceso externo está canalizado por un Ingress Controller NGINX con IP pública, replicando el esquema de enrutamiento por rutas.*  
> *Para demostrar la capacidad de escalado horizontal del requerimiento 13, escalamos el servicio de órdenes de 2 a 4 réplicas con `kubectl scale` y comprobamos que el Ingress y el Service distribuyen el tráfico equitativamente entre los cuatro pods sin interrupción de servicio."*

**Comandos a ejecutar:**
```bash
# En Azure Cloud Shell o terminal conectada a AKS:
# 1. Mostrar estado general del namespace microapp (Requerimiento 14)
kubectl get all -n microapp -o wide
kubectl get ingress -n microapp

# 2. Ejecutar la batería de pruebas integral (Requerimientos 11, 12 y 13):
bash "3. Kubernetes/scripts/prueba-k8s.sh"
```

---

# <a id="6-catálogo-de-cambios-en-caliente"></a>6. Catálogo de Preguntas Conceptuales y Cambios en Caliente

Guía rápida ante solicitudes imprevistas del evaluador durante la sustentación:

---

### Caso 1: *"Cámbienme el algoritmo de balanceo en HAProxy a `leastconn`"*
* **Respuesta Conceptual:**  
  `roundrobin` distribuye secuencialmente de forma equitativa. `leastconn` asigna la nueva petición al servidor con menor número de conexiones activas concurrentes (recomendado para transacciones de larga duración o cargas heterogéneas).
* **Modificación en Caliente:**
  En `1-2. Infraestructura/chef/cookbooks/haproxy/attributes/default.rb`:
  ```ruby
  default['haproxy']['balance'] = 'leastconn'
  ```
  Ejecutar en `control-node`:
  ```bash
  cd "/vagrant/1-2. Infraestructura/terraform" && terraform apply -auto-approve
  ```
* **Directo en la máquina virtual (sin Terraform):**
  ```bash
  ssh vm-haproxy "sudo sed -i 's/balance roundrobin/balance leastconn/g' /etc/haproxy/haproxy.cfg && sudo systemctl reload haproxy"
  ```

---

### Caso 2: *"Cámbienme el puerto o las credenciales del Dashboard de HAProxy"*
* **Modificación en Caliente:**
  En `1-2. Infraestructura/chef/cookbooks/haproxy/attributes/default.rb`:
  ```ruby
  default['haproxy']['stats_port']     = 8888
  default['haproxy']['stats_password'] = 'NuevaClave2026'
  ```
  Ejecutar `terraform apply -auto-approve`.
* **Directo en la máquina virtual:**
  ```bash
  ssh vm-haproxy "sudo sed -i 's/bind \*:8080/bind \*:8888/g' /etc/haproxy/haproxy.cfg && sudo systemctl reload haproxy"
  ```

---

### Caso 3: *"Agreguen una tercera instancia al microservicio de usuarios"*
* **Modificación en Caliente:**
  En `1-2. Infraestructura/chef/cookbooks/microservices/attributes/default.rb`:
  ```ruby
  'users' => { 'port' => 3001, 'instances' => 3 }
  ```
  Ejecutar `terraform apply -auto-approve`.  
  Automáticamente Chef genera el nuevo contenedor `users-service-3` en el puerto `3021` con Docker Compose y actualiza `haproxy.cfg` recargando el servicio sin cortes.

---

### Caso 4: *"¿Por qué usan Services de tipo `ClusterIP` en lugar de `LoadBalancer` o `NodePort`?"*
* **Respuesta Conceptual:**  
  > *"Seguimos el principio de arquitectura perimetral y mínimo privilegio. Los microservicios backend deben permanecer aislados en la red interna del clúster con IPs privadas no enrutables desde Internet. El único punto de entrada público es el Ingress Controller (que sí cuenta con una IP pública expuesta mediante un Azure Load Balancer). Asignar un Service `LoadBalancer` a cada microservicio crearía tres balanceadores de nube independientes, multiplicando los costos en Azure e introduciendo vulnerabilidades de seguridad al exponer los microservicios directamente a Internet."*

---

### Caso 5: *"En Kubernetes, escalen el servicio de productos a 3 réplicas y reduzcan usuarios a 1"*
* **Comando en vivo (Imperativo):**
  ```bash
  kubectl scale deployment products-deployment --replicas=3 -n microapp
  kubectl scale deployment users-deployment --replicas=1 -n microapp
  kubectl get pods -n microapp
  ```
* **Modificación declarativa (YAML):**  
  Editar `replicas: 3` en `manifests/02-products.yaml`, `replicas: 1` en `manifests/01-users.yaml` y ejecutar `kubectl apply -f manifests/`.

---

### Caso 6: *"¿Qué sucede si un Pod falla o es eliminado abruptamente en Kubernetes?"*
* **Demostración en vivo:**
  ```bash
  # Obtener el nombre de un pod activo de orders
  POD=$(kubectl get pods -n microapp -l app=orders-service -o jsonpath='{.items[0].metadata.name}')
  # Eliminarlo
  kubectl delete pod "$POD" -n microapp
  # Verificar autorreparación instantánea
  kubectl get pods -n microapp -l app=orders-service
  ```
* **Explicación:**  
  El Deployment está respaldado por un controlador de tipo `ReplicaSet`. Su bucle de reconciliación compara continuamente el estado actual con el estado deseado. Al detectar que el número de pods vivos es menor que el deseado, el Controller Manager programa inmediatamente la creación de un nuevo Pod sin intervención humana.

---

### Caso 7: *"¿Cómo pruebo un Service de Kubernetes directamente sin pasar por el Ingress?"*
* **Opción A (Port-Forwarding):**
  ```bash
  kubectl port-forward svc/users-svc 8081:3001 -n microapp
  # En otra terminal:
  curl http://localhost:8081
  ```
* **Opción B (Pod efímero de prueba dentro del clúster):**
  ```bash
  kubectl run curl-debug --image=curlimages/curl --rm -it --restart=Never -- curl http://users-svc.microapp.svc.cluster.local:3001
  ```

---

### Caso 8: *"¿Cómo se garantiza que Docker y los contenedores arranquen si se reinicia la máquina `vm-microservices`?"*
* **Respuesta Conceptual:**
  1. En el sistema operativo, el servicio Docker está habilitado a nivel de systemd (`systemctl enable docker`).
  2. En el archivo declarativo `docker-compose.yml`, cada contenedor cuenta con la directiva `restart: always`. Al reiniciar el demonio o la máquina virtual, el motor de Docker reanuda automáticamente todos los contenedores sin requerir volver a correr Chef o Terraform.

---

# 🛑 RECORDATORIO FINAL DE COSTOS EN AZURE
Una vez concluida la sesión de evaluación con el profesor, liberar los recursos de inmediato ejecutando:
```bash
bash "3. Kubernetes/scripts/destroy-aks.sh"
```
O directamente en la consola de Azure:
```bash
az group delete --name rg-microapp-aks --yes --no-wait
```
Esto garantiza la preservación de los fondos de la suscripción para prácticas futuras.
