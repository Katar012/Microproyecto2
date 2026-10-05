# 🎓 GUÍA MAESTRA DE SUSTENTACIÓN - MICROPROYECTO 2
### Computación en la Nube · Universidad Autónoma de Occidente (UAO)

Esta guía está diseñada para que entiendas **cada línea de código, cada comando y cada decisión arquitectónica** del proyecto, y para que en la sustentación individual hables con la seguridad y propiedad de un Ingeniero Cloud Senior.

---

# 📑 TABLA DE CONTENIDO
1. [¿De qué va el proyecto? (Visión Global)](#1-de-qué-va-el-proyecto)
2. [Problema 1: Aprovisionamiento Automatizado (Vagrant + Terraform + Chef)](#2-problema-1-aprovisionamiento-automatizado)
3. [Problema 2: Balanceo de Carga y Tolerancia a Fallos (HAProxy)](#3-problema-2-balanceo-de-carga-con-haproxy)
4. [Problema 3: Orquestación de Microservicios con Kubernetes (AKS)](#4-problema-3-orquestación-con-kubernetes)
5. [Guión para Exponer (Qué decir exactamente ante el profesor)](#5-guión-para-exponer)
6. [Catálogo de "Cambios en Caliente" (Preguntas trampa y cómo responderlas en vivo)](#6-catálogo-de-cambios-en-caliente)

---

# <a id="1-de-qué-va-el-proyecto"></a>1. ¿De qué va el proyecto? (Visión Global)

El proyecto simula una plataforma moderna de **comercio electrónico** desacoplada en 3 microservicios independientes:
1. **Users Service** (`users-service`): Gestión de registro, autenticación y perfiles de usuario. Puerto interno: `3001`.
2. **Products Service** (`products-service`): Catálogo, stock de productos e imágenes. Puerto interno: `3002`.
3. **Orders Service** (`orders-service`): Gestión del ciclo de vida y estado de las órdenes de compra. Puerto interno: `3003`.

### El objetivo del curso evaluado aquí:
No se evalúa la lógica interna de negocio de los microservicios (por eso usamos la imagen ligera estándar `hashicorp/http-echo`), sino **la infraestructura y las operaciones Cloud (DevOps)**:
1. **Infraestructura como Código (IaC) y Gestión de Configuración (CM):** Cómo aprovisionar máquinas virtuales de forma 100% automatizada y reproducible usando **Terraform** y **Chef** (0.5 décimas adicionales frente a Ansible).
2. **Alta Disponibilidad, Enrutamiento y Balanceo:** Cómo centralizar el tráfico en un punto único de entrada (**HAProxy**), enrutar por prefijos de URL (`/api/users`, `/api/products`, `/api/orders`), balancear carga con Round-Robin y garantizar que si un servidor se cae, el usuario final ni se entere (**Zero-Downtime Failover**).
3. **Orquestación Cloud-Native:** Cómo llevar esa misma arquitectura a un clúster de **Kubernetes** administrado en la nube (**Azure Kubernetes Service - AKS**), utilizando Namespaces, Deployments, Services ClusterIP, Ingress Controllers y escalabilidad elástica horizontal.

---

# <a id="2-problema-1-aprovisionamiento-automatizado"></a>2. Problema 1: Aprovisionamiento Automatizado

```text
+-------------------------------------------------------------------------+
|                              HOST FÍSICO                                |
|                                                                         |
|  +--------------------+     SSH (Llave id_rsa)    +------------------+  |
|  |    control-node    | ------------------------> |    vm-haproxy    |  |
|  |  (192.168.100.10)  |                           | (192.168.100.2)  |  |
|  |                    |                           | HAProxy Service  |  |
|  |  - Terraform v1.x  |                           +------------------+  |
|  |  - Chef Workstn    |     SSH (Llave id_rsa)    +------------------+  |
|  |  - Llaves SSH      | ------------------------> | vm-microservices |  |
|  +--------------------+                           | (192.168.100.3)  |  |
|           |                                       | Docker Engine    |  |
|           +------ Carpeta compartida (/vagrant)   | 6 Contenedores   |  |
+-------------------------------------------------------------------------+
```

### ¿Qué hace cada archivo?

* **`Vagrantfile`**: Define el laboratorio virtual en VirtualBox con 3 VMs bajo la red privada `192.168.100.0/24`.
  - Configura la memoria optimizada (1GB para `vm-haproxy`, 1.5GB para `vm-microservices`, 1GB para `control-node`) para no sobrecargar la RAM física del equipo.
  - En `control-node`, instala Terraform, Chef Workstation, genera la llave SSH `id_rsa` y la transfiere automáticamente a las otras dos VMs mediante `sshpass` y `ssh-copy-id`.
  - Lanza automáticamente `terraform init` y `terraform apply`.

* **`1-2. Infraestructura/terraform/`**:
  - `providers.tf`: Declara el proveedor `hashicorp/null`. Un `null_resource` no crea VMs en AWS o Azure (las VMs ya las creó Vagrant en local), sino que actúa como el orquestador que gestiona el ciclo de vida, ejecutando provisioners SSH (`file` y `remote-exec`).
  - `variables.tf`: Define las IPs privadas (`192.168.100.2`, `192.168.100.3`), usuario (`vagrant`) y la ruta de la llave privada SSH (`/home/vagrant/.ssh/id_rsa`).
  - `main.tf`:
    - **Validación del SO**: Antes de ejecutar nada, valida que las máquinas target sean `Ubuntu 22.04` leyendo `/etc/os-release`.
    - **Triggers y Hashes**: Calcula un hash SHA1 de todos los archivos de Chef. Si editas un cookbook o una receta, Terraform detecta el cambio e invalida únicamente el recurso afectado.
    - **Provisioner `file`**: Copia la carpeta local de Chef `/chef` hacia `/tmp/chef` en la máquina destino.
    - **Provisioner `remote-exec`**: Instala `cinc-client` (distribución 100% libre y compatible de Chef Infra) y ejecuta:
      ```bash
      sudo cinc-client -z -c /tmp/chef/solo.rb -j /tmp/chef/nodes/vm-microservices.json
      ```
      El flag `-z` ejecuta Chef en modo **Chef-Zero** (servidor local en memoria), sin requerir un servidor central de Chef costoso.
    - **Reproducibilidad y Destrucción (`when = destroy`)**:
      Si se ejecuta `terraform destroy`, Terraform entra por SSH a cada nodo y desinstala limpiamente Docker, los contenedores, HAProxy y Cinc, purgando repositorios y directorios. Al volver a correr `terraform apply`, el ambiente queda idéntico sin intervención humana.
  - `outputs.tf`: Expone las IPs de las máquinas, las URLs de los servicios y los comandos de verificación rápida.

* **`1-2. Infraestructura/chef/`**:
  - `solo.rb`: Archivo de configuración fundamental para Chef-Solo / Chef-Zero. Le indica a Chef las rutas donde residen los cookbooks (`/tmp/chef/cookbooks`) y los roles (`/tmp/chef/roles`).
  - `cookbooks/docker/recipes/default.rb`: Instala paquetes de transporte SSL, descarga la llave GPG oficial de Docker, configura el repositorio APT oficial según la arquitectura del procesador (`amd64` / `arm64`), instala Docker Engine y añade al usuario `vagrant` al grupo `docker`.
  - `cookbooks/microservices/attributes/default.rb`: **Fuente Única de Verdad**. Define el mapa de servicios:
    - `users`: puerto base 3001, 2 instancias.
    - `products`: puerto base 3002, 2 instancias.
    - `orders`: puerto base 3003, 2 instancias.
  - `cookbooks/microservices/templates/default/docker-compose.yml.erb`: Plantilla que genera `/opt/microapp/docker-compose.yml` de forma dinámica a partir de los atributos.
  - `cookbooks/microservices/recipes/default.rb`: En lugar de ejecutar comandos sueltos de `docker run` imperativos, orquesta los microservicios usando **Docker Compose declarativo**. Renderiza el archivo `docker-compose.yml` y ejecuta `docker compose up -d --remove-orphans`:
    - Contenedor 1 de users: mapea puerto host `3001` -> contenedor `3001`.
    - Contenedor 2 de users: mapea puerto host `3011` -> contenedor `3001`.
    - Configura `restart: always` para que si la máquina virtual se reinicia, Docker levante automáticamente los contenedores.
    - Facilita la administración con comandos estándar (`docker compose ps`, `docker compose logs`, `docker compose down`).
  - `roles/microservices.rb` y `roles/haproxy.rb`: Agrupan las recetas que corresponden a cada función.
  - `nodes/vm-microservices.json` y `nodes/vm-haproxy.json`: Asocian cada máquina con su respectivo rol.

---

# <a id="3-problema-2-balanceo-de-carga-con-haproxy"></a>3. Problema 2: Balanceo de Carga con HAProxy

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
        |   balance roundrobin  |             |  balance roundrobin   |
        +───────────────────────+             +───────────────────────+
           │                 │
     Round-Robin       Round-Robin
           │                 │
           ▼                 ▼
   users1 (3001)       users2 (3011)
  (En vm-microservices: 192.168.100.3)
```

### Componentes Clave en `haproxy.cfg.erb`:
1. **Frontend `http_front` en puerto 80**:
   - `acl is_users path_beg /api/users`: Evalúa si la URL solicitada inicia con `/api/users`.
   - `acl is_products path_beg /api/products`: Evalúa prefijo `/api/products`.
   - `acl is_orders path_beg /api/orders`: Evalúa prefijo `/api/orders`.
   - `use_backend users_back if is_users`: Redirecciona al backend correspondiente.
   - `default_backend not_found`: Si piden una ruta distinta, responde `HTTP 404 Not Found` informando las rutas válidas.

2. **Backends con Balanceo y Health Check**:
   - `balance roundrobin`: Distribuye las solicitudes equitativamente (Petición 1 al Servidor 1, Petición 2 al Servidor 2, etc.).
   - `option httpchk GET /health`: Envía periódicamente una petición HTTP GET para verificar que el contenedor responda con código `200 OK`.
   - `check inter 2s fall 2 rise 2`:
     - `inter 2s`: Hace la prueba cada 2 segundos.
     - `fall 2`: Si falla 2 veces consecutivas (4 segundos), marca el servidor como `DOWN`.
     - `rise 2`: Cuando vuelve a responder 2 veces seguidas, lo restaura a `UP`.
   - `retries 3` y `option redispatch`: **Mecanismo de Alta Disponibilidad**. Si un contenedor cae repentinamente y un cliente envía una petición antes de que el health check lo marque en `DOWN`, HAProxy no le bota un error 502 al usuario; reintenta y redirige la petición al otro servidor vivo de inmediato.
   - `http-response set-header X-Backend-Server %[srv_name]`: Inyecta en la cabecera HTTP el nombre del servidor que atendió (`users1` o `users2`), facilitando auditar el balanceo con `curl -i`.

3. **Dashboard de Estadísticas en Puerto 8080 (`listen stats`)**:
   - Escucha en el puerto dedicado `8080` (aislado del tráfico web del puerto 80).
   - URI: `/stats`.
   - Autenticación HTTP Basic con credenciales: `admin` / `admin123`.
   - Muestra en tiempo real:
     - Estado de salud de los nodos (`UP` en verde, `DOWN` en rojo).
     - Conteo de bytes de entrada/salida.
     - Tasa de peticiones procesadas por cada contenedor.

---

# <a id="4-problema-3-orquestación-con-kubernetes"></a>4. Problema 3: Orquestación con Kubernetes

```text
                               INTERNET
                                  │
                                  ▼
                   +─────────────────────────────+
                   |  Ingress Controller (NGINX) |  <-- IP Pública de Azure / Puerto 80
                   |       Ingress Resource      |
                   +─────────────────────────────+
                                  │
         ┌────────────────────────┼────────────────────────┐
   /api/users               /api/products            /api/orders
         │                        │                        │
         ▼                        ▼                        ▼
+──────────────────+     +──────────────────+     +──────────────────+
|  Service (3001)  |     |  Service (3002)  |     |  Service (3003)  |
|     users-svc    |     |   products-svc   |     |    orders-svc    |
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

### Conceptos Clave de Kubernetes Implementados:
1. **Namespace (`microapp`)**:
   - Aislamiento lógico dentro del clúster. Todos los recursos de la tienda viven dentro de este espacio de nombres, impidiendo colisiones con otros servicios del sistema (`kube-system`, `ingress-nginx`).
2. **Deployments**:
   - Declaran el estado deseado: imagen `hashicorp/http-echo:1.0.0`, número de réplicas (`replicas: 2`), límites de recursos (CPU y memoria), y política `restartPolicy: Always`.
   - Si un Pod se cae o se elimina manualmente, el controlador de réplicas (`ReplicaSet`) crea inmediatamente un nuevo Pod para satisfacer el número deseado (**autorreparación / self-healing**).
   - Inyección de variables con **Downward API**: Inyectamos el nombre del Pod (`metadata.name`) en el texto de respuesta para comprobar en vivo qué Pod atiende cada petición.
3. **Services (`ClusterIP`)**:
   - `users-svc` (puerto 3001), `products-svc` (puerto 3002), `orders-svc` (puerto 3003).
   - Un Service actúa como una IP virtual interna estable con balanceo de carga automático entre todos los Pods seleccionados por las etiquetas `app: users-service`. Los Pods son efímeros y cambian de IP al recrearse, pero el Service nunca cambia de IP ni de nombre DNS.
4. **Ingress y Ingress Controller**:
   - El Ingress Controller (NGINX) es el componente de software (reverse proxy) que escucha el tráfico proveniente de Internet a través de un Azure Load Balancer.
   - El Ingress Resource (`04-ingress.yaml`) define las reglas de enrutamiento basadas en HTTP path:
     - Si la petición va a `/api/users`, la enruta al servicio `users-svc:3001`.
     - Si va a `/api/products`, a `products-svc:3002`.
     - Si va a `/api/orders`, a `orders-svc:3003`.
5. **Escalabilidad Horizontal (`kubectl scale`)**:
   - Se demuestra escalando `orders-deployment` de 2 a 4 réplicas:
     ```bash
     kubectl scale deployment orders-deployment --replicas=4 -n microapp
     ```
   - Kubernetes lanza dos nuevos pods, espera a que pasen sus pruebas de `readinessProbe` y los añade instantáneamente al pool del Service `orders-svc`. Al hacer peticiones con `curl`, se evidencia que el tráfico se reparte entre los 4 pods sin caída de servicio.

---

# <a id="5-guión-para-exponer"></a>5. Guión para Exponer (Qué decir ante el profesor)

Utiliza este orden para presentar tu proyecto de forma impecable:

### 1. Saludo e Introducción (30 segundos)
> *"Buenas tardes profesor. Nuestro proyecto implementa la arquitectura de microservicios de comercio electrónico en tres etapas: primero, aprovisionamiento automatizado y reproducible con Terraform y Chef; segundo, balanceo de carga y alta disponibilidad perimetral con HAProxy; y tercero, orquestación en la nube con Kubernetes en Azure AKS con Ingress Controller y escalabilidad horizontal."*

### 2. Demostración del Problema 1: Terraform + Chef (2 minutos)
> *"Para el Problema 1, optamos por el reto de utilizar **Chef** en lugar de Ansible para obtener la bonificación de 5 décimas.*  
> *Creamos una arquitectura de 3 nodos administrada por `control-node`. Al ejecutar `terraform apply`, Terraform se conecta vía SSH por llaves públicas/privadas hacia `vm-microservices` y `vm-haproxy`.*  
> *A través de Cinc-Client y Chef-Zero, aplicamos el rol de microservicios que instala Docker nativo y despliega los contenedores de usuarios, productos y órdenes con política `restart: always`.*  
> *Para demostrar que el aprovisionamiento es 100% reproducible como pide la guía, voy a ejecutar `terraform destroy` para que observe cómo se purga la infraestructura dejándola limpia, y luego `terraform apply` para reconstruirla automáticamente en minutos."*

**Comandos a ejecutar en pantalla:**
```bash
vagrant ssh control-node
cd "/vagrant/1-2. Infraestructura/terraform"
bash "/vagrant/1-2. Infraestructura/scripts/verificar.sh"
terraform destroy -auto-approve
terraform apply -auto-approve
bash "/vagrant/1-2. Infraestructura/scripts/verificar.sh"
```

### 3. Demostración del Problema 2: HAProxy (2 minutos)
> *"En el Problema 2, configuramos HAProxy en el puerto 80 como punto único de entrada.*  
> *El enrutamiento se gestiona mediante reglas ACL según el prefijo de la URL: `/api/users`, `/api/products` y `/api/orders`.*  
> *Cada microservicio cuenta con dos instancias balanceadas bajo el algoritmo **Round-Robin**.*  
> *En el puerto 8080 habilitamos el panel de estadísticas protegido con credenciales.*  
> *Para evidenciar la tolerancia a fallos, ejecutamos nuestro script de prueba que realiza peticiones continuas mientras detenemos un contenedor con `docker stop`. Gracias a las directivas `retries 3` y `option redispatch`, HAProxy redirige inmediatamente el tráfico al servidor alterno sin arrojar errores al cliente, marcando el nodo en `DOWN` en el dashboard."*

**Comandos a ejecutar en pantalla:**
```bash
# Mostrar el dashboard en el navegador: http://192.168.100.2:8080/stats (admin / admin123)
# Ejecutar la prueba automática de failover:
bash "/vagrant/1-2. Infraestructura/scripts/prueba-haproxy.sh" users 1
```

### 4. Demostración del Problema 3: Kubernetes en Azure AKS (3 minutos)
> *"Para el Problema 3, desplegamos la arquitectura en **Azure Kubernetes Service (AKS)**.*  
> *Aislamos los recursos en el namespace `microapp`. Cada microservicio corre en un Deployment con réplicas redundantes y puertos internos 3001, 3002 y 3003, expuestos internamente mediante Services de tipo `ClusterIP`.*  
> *El acceso externo lo canalizamos a través del Ingress Controller NGINX, replicando exactamente el esquema de enrutamiento por rutas del Problema 2.*  
> *Para demostrar la escalabilidad horizontal exigida en el punto 13, escalamos el servicio de órdenes de 2 a 4 réplicas con `kubectl scale` y evidenciamos cómo el Ingress y el Service distribuyen las peticiones de inmediato entre los cuatro pods sin interrupciones."*

**Comandos a ejecutar en pantalla:**
```bash
# 1. Mostrar estado general de los recursos (Requerimiento 14)
kubectl get all -n microapp -o wide
kubectl get ingress -n microapp

# 2. Ejecutar la batería de pruebas y escalado:
bash "3. Kubernetes/scripts/prueba-k8s.sh"
```

---

# <a id="6-catálogo-de-cambios-en-caliente"></a>6. Catálogo de "Cambios en Caliente"

Los profesores suelen pedir pequeñas modificaciones en vivo durante la sustentación para comprobar si tú hiciste el trabajo o si solo memorizaste comandos. Aquí tienes la respuesta exacta para cada escenario:

---

### Pregunta 1: *"Cámbienme el algoritmo de balanceo en HAProxy de roundrobin a leastconn"*
**Explicación teórica:** `roundrobin` reparte las solicitudes secuencialmente una a una. `leastconn` le envía la petición al servidor que tenga menor número de conexiones activas en ese momento (ideal para sesiones largas o APIs pesadas).  
**Cómo hacerlo:**
1. Abre el archivo de atributos de Chef en `1-2. Infraestructura/chef/cookbooks/haproxy/attributes/default.rb`:
   ```ruby
   default['haproxy']['balance'] = 'leastconn'
   ```
2. En `control-node`, corre:
   ```bash
   cd "/vagrant/1-2. Infraestructura/terraform"
   terraform apply -auto-approve
   ```
   *(Terraform detecta el cambio en los archivos de Chef, recompila la plantilla `haproxy.cfg` y recarga HAProxy en caliente sin tumbar el servicio)*.
3. Si el profesor te pide hacerlo directo sobre el archivo de configuración en la máquina virtual:
   ```bash
   ssh vm-haproxy "sudo sed -i 's/balance roundrobin/balance leastconn/g' /etc/haproxy/haproxy.cfg && sudo systemctl reload haproxy"
   ```

---

### Pregunta 2: *"Cámbienme la contraseña o el puerto del dashboard de estadísticas"*
**Cómo hacerlo:**
1. En `1-2. Infraestructura/chef/cookbooks/haproxy/attributes/default.rb`, modifica:
   ```ruby
   default['haproxy']['stats_port']     = 8888
   default['haproxy']['stats_password'] = 'NuevaClave2026'
   ```
2. Ejecuta `terraform apply -auto-approve`.
3. Para hacerlo directo en la VM `vm-haproxy`:
   ```bash
   ssh vm-haproxy
   sudo nano /etc/haproxy/haproxy.cfg
   # En la sección "listen stats", cambias el bind *:8888 y stats auth admin:NuevaClave2026
   sudo systemctl reload haproxy
   ```

---

### Pregunta 3: *"Agreguen una tercera instancia al microservicio de usuarios"*
**Cómo hacerlo:**
1. En `1-2. Infraestructura/chef/cookbooks/microservices/attributes/default.rb`, cambia:
   ```ruby
   'users' => { 'port' => 3001, 'instances' => 3 }
   ```
2. Ejecuta `terraform apply -auto-approve`.
3. Automáticamente:
   - Chef levanta el contenedor `users-service-3` en el puerto `3021`.
   - HAProxy agrega la línea `server users3 192.168.100.3:3021 check` y recarga la configuración.

---

### Pregunta 4: *"En Kubernetes, cámbiame el número de réplicas de products a 3 y de users a 1"*
**Cómo hacerlo con comando imperativo (al instante):**
```bash
kubectl scale deployment products-deployment --replicas=3 -n microapp
kubectl scale deployment users-deployment --replicas=1 -n microapp
kubectl get pods -n microapp
```
**Cómo hacerlo de forma declarativa:**
1. Abre `3. Kubernetes/manifests/01-users.yaml` y cambia `replicas: 1`.
2. Abre `3. Kubernetes/manifests/02-products.yaml` y cambia `replicas: 3`.
3. Aplica los cambios:
   ```bash
   kubectl apply -f "3. Kubernetes/manifests/"
   ```

---

### Pregunta 5: *"¿Por qué los Services son de tipo ClusterIP y no LoadBalancer o NodePort?"*
**Respuesta teórica:**  
> *"Porque seguimos el principio de mínimo privilegio y arquitectura perimetral. Los microservicios residen en una red privada dentro del clúster y no deben exponerse directamente a Internet. El único punto de contacto con el mundo exterior es el **Ingress Controller**, que cuenta con una IP pública externa (mediante su propio LoadBalancer de Azure). El Ingress se encarga de recibir el tráfico HTTP exterior y enrutarlo internamente a los Services `ClusterIP` correspondientes por DNS interno (`users-svc.microapp.svc.cluster.local`). Usar LoadBalancer en cada servicio encarecería la factura de Azure (un balanceador de nube por microservicio) y violaría la seguridad de la red."*

---

### Pregunta 6: *"¿Qué sucede si un Pod de Kubernetes muere o lo eliminan?"*
**Demostración en vivo:**
1. Elimina un pod cualquiera:
   ```bash
   POD=$(kubectl get pods -n microapp -l app=orders-service -o jsonpath='{.items[0].metadata.name}')
   kubectl delete pod "$POD" -n microapp
   ```
2. Muestra inmediatamente el estado:
   ```bash
   kubectl get pods -n microapp -l app=orders-service
   ```
3. **Explicación:** El Deployment tiene un controlador `ReplicaSet` cuyo bucle de reconciliación detecta que hay 1 pod vivo cuando el estado deseado es 2. En milisegundos crea un pod de reemplazo sin que los usuarios perciban caída.

---

### Pregunta 7: *"¿Cómo pruebo directamente un Service de Kubernetes sin pasar por el Ingress?"*
**Cómo hacerlo (Port-Forward):**
```bash
# Redirige el puerto 3001 del Service a tu máquina local:
kubectl port-forward svc/users-svc 8081:3001 -n microapp
# En otra terminal:
curl http://localhost:8081
```

---

# 🛑 ¡REGLA DE ORO DE AZURE ANTES DE DESCONECTARSE!
Al finalizar la sustentación con el profesor, ejecuta de inmediato:
```bash
cd "3. Kubernetes/scripts"
bash destroy-aks.sh
```
O en la consola de Azure:
```bash
az group delete --name rg-microapp-aks --yes --no-wait
```
Con esto aseguras que tu suscripción de Azure for Students conserve su crédito para las materias siguientes.
