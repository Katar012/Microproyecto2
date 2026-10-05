# 📋 Índice

* [¿Qué hay implementado?](#que-hay-implementado)
* [1. Infraestructura](#1-infraestructura)
  * [1.1. Chef](#11-chef)
  * [1.2. Optimizaciones de Infraestructura y Orquestación](#12-optimizaciones-de-infraestructura)
* [2. HAProxy](#2-haproxy)
  * [2.1. Arquitectura de haproxy.cfg](#21-arquitectura-de-haproxycfg)
  * [2.2. Resiliencia, Monitoreo y Alta Disponibilidad](#22-resiliencia-y-alta-disponibilidad)
* [3. Kubernetes (Orquestación en la Nube)](#3-kubernetes)
  * [3.1. Arquitectura de los Manifiestos](#31-arquitectura-de-los-manifiestos)
  * [3.2. Scripts de Despliegue y Automatización](#32-scripts-de-despliegue)
  * [3.3. Módulo Opcional: Terraform + AKS](#33-modulo-opcional-terraform-aks)
* [4. Guía de Ejecución y Pruebas](#4-guia-de-ejecucion-y-pruebas)
  * [4.1. Verificación de Infraestructura (Problema 1)](#41-verificacion-infraestructura)
  * [4.2. Verificación de Balanceo y Failover (Problema 2)](#42-verificacion-haproxy)
  * [4.3. Verificación de Kubernetes en Azure AKS (Problema 3)](#43-verificacion-kubernetes)
* [5. Documentación Adicional](#5-documentacion-adicional)
  * [Árbol de Carpetas del Proyecto](#arbol-de-carpetas)

---

# <a id="que-hay-implementado"></a>¿Qué hay implementado?

1. **Problema 1: Aprovisionamiento de Infraestructura** :white_check_mark:  
   Aprovisionamiento automatizado de máquinas virtuales con Vagrant, Terraform y Chef (Cinc-Client en modo Chef-Zero). Incluye ciclo de vida 100% reproducible con `terraform destroy` y `terraform apply`, autenticación segura por llaves SSH y orquestación declarativa de contenedores con Docker Compose.
2. **Problema 2: Balanceo de Carga con HAProxy** :white_check_mark:  
   Punto de entrada único en puerto 80 con enrutamiento basado en prefijos de URL (`/api/users`, `/api/products`, `/api/orders`), balanceo Round-Robin hacia instancias redundantes, health checks continuos con reconexión transparente (`retries 3`, `option redispatch`), trazabilidad mediante cabeceras HTTP y dashboard de métricas en puerto 8080 protegido por credenciales.
3. **Problema 3: Orquestación con Kubernetes** :white_check_mark:  
   Despliegue cloud-native en Azure Kubernetes Service (AKS) dentro de un namespace dedicado (`microapp`), Deployments con réplicas redundantes y políticas de reinicio, Services `ClusterIP` para aislamiento perimetral, Ingress Controller NGINX para enrutamiento por rutas, escalado elástico horizontal en caliente y scripts de automatización para Azure y entornos locales.

---

# <a id="1-infraestructura"></a>1. Infraestructura

La topología del laboratorio local se define en un `Vagrantfile` que levanta 3 máquinas virtuales con Ubuntu 22.04 LTS:
- `control-node` (`192.168.100.10`): Nodo administrador donde residen Terraform v1.x y Chef Workstation.
- `vm-haproxy` (`192.168.100.2`): Nodo destino dedicado al servicio de balanceo perimetral HAProxy.
- `vm-microservices` (`192.168.100.3`): Nodo destino dedicado al motor Docker y a los microservicios.

El flujo de aprovisionamiento opera de la siguiente manera:
1. `Vagrantfile` aprovisiona `control-node`, genera un par de llaves SSH (`id_rsa`), las copia hacia `vm-haproxy` y `vm-microservices`, y ejecuta `terraform apply`.
2. Terraform se conecta por SSH a cada nodo target mediante llave pública/privada, transfiere la estructura de `/chef` a `/tmp/chef` y ejecuta `cinc-client` de forma local (Chef-Zero).

> 📌 **NOTA:** La raíz del repositorio se monta como carpeta compartida (`/vagrant`) en `control-node`.

### <a id="11-chef"></a>1.1. Chef

El aprovisionamiento de software se estructura en cookbooks modulares dentro de `1-2. Infraestructura/chef/cookbooks/`:

1. `/docker/`: Instala paquetes de transporte, descarga la llave GPG oficial de Docker, configura el repositorio APT oficial según la arquitectura de la máquina (`amd64` / `arm64`), instala Docker Engine, Containerd, Docker Compose Plugin y agrega al usuario `vagrant` al grupo `docker`.
2. `/microservices/`: Orquesta declarativamente las instancias de los servicios `users`, `products` y `orders` con Docker Compose a través de una plantilla ERB dinámica.
3. `/haproxy/`: Instala HAProxy, socat y renderiza `/etc/haproxy/haproxy.cfg` a partir de la plantilla `haproxy.cfg.erb`.

Estructura de roles y nodos:
- En `/chef/roles/`:
  - `microservices.rb`: Asigna `recipe[docker]` y `recipe[microservices]`.
  - `haproxy.rb`: Asigna `recipe[haproxy]`.
- En `/chef/nodes/`:
  - `vm-microservices.json`: Vincula el rol `microservices` al nodo.
  - `vm-haproxy.json`: Vincula el rol `haproxy` al nodo.

### <a id="12-optimizaciones-de-infraestructura"></a>1.2. Optimizaciones de Infraestructura y Orquestación

1. **Dimensionamiento y Estabilidad de Recursos:**  
   Se ajustaron las asignaciones de memoria en el `Vagrantfile` (1024 MB para `vm-haproxy`, 1536 MB para `vm-microservices` y 1024 MB para `control-node`, totalizando ~3.5 GB), permitiendo una ejecución estable, fluida y sin agotamiento de memoria física.
2. **Ciclo de Vida 100% Reproducible (`terraform destroy` y `terraform apply`):**  
   Se implementaron provisioners `remote-exec` con la directiva `when = destroy` en `main.tf`. Al invocar `terraform destroy`, Terraform purga de manera controlada los contenedores, los volúmenes, Docker, HAProxy y los directorios de trabajo. Un `terraform apply` posterior reconstruye el entorno completo desde cero de forma idéntica e idempotente.
3. **Autenticación SSH Criptográfica:**  
   Se configuró el uso exclusivo de llaves SSH (`/home/vagrant/.ssh/id_rsa`) en las conexiones de Terraform, garantizando seguridad y eliminando credenciales en texto plano.
4. **Idempotencia mediante Hashes de Contenido:**  
   Terraform calcula el hash criptográfico SHA1 de los cookbooks y roles de Chef (`triggers`). Si se modifica una receta, únicamente se re-aprovisiona la máquina virtual directamente afectada.
5. **Orquestación Declarativa con Docker Compose:**  
   En lugar de ejecutar comandos sueltos de `docker run`, los microservicios se definen declarativamente en `/opt/microapp/docker-compose.yml` mediante la plantilla `docker-compose.yml.erb`. Esto centraliza el control de los 6 contenedores, sus puertos de host y contenedor, sus etiquetas y su política `restart: always`.

---

# <a id="2-haproxy"></a>2. HAProxy

En el nodo `vm-haproxy`, HAProxy actúa como balanceador de carga perimetral y punto de entrada unificado para todas las peticiones externas.

### <a id="21-arquitectura-de-haproxycfg"></a>2.1. Arquitectura de haproxy.cfg

1. **Frontend `http_front` en puerto 80:**  
   Recibe el tráfico HTTP y aplica listas de control de acceso (ACLs) según el prefijo de la URL:
   - Prefijo `/api/users` -> redirige a `users_back`
   - Prefijo `/api/products` -> redirige a `products_back`
   - Prefijo `/api/orders` -> redirige a `orders_back`
   - Cualquier otra ruta no mapeada devuelve un código `404 Not Found` informando las rutas disponibles.
2. **Backends con Balanceo Round-Robin:**  
   Cada backend distribuye la carga entre 2 instancias del microservicio alojadas en `vm-microservices`:
   - `users_back`: `users1` (puerto 3001) y `users2` (puerto 3011).
   - `products_back`: `products1` (puerto 3002) y `products2` (puerto 3012).
   - `orders_back`: `orders1` (puerto 3003) y `orders2` (puerto 3013).
3. **Dashboard de Métricas en puerto 8080:**  
   Panel web accesible en `http://192.168.100.2:8080/stats`, protegido con autenticación básica HTTP (`admin` / `admin123`). Permite visualizar en tiempo real el estado de cada servidor, tráfico cursado y tasas de error.

### <a id="22-resiliencia-y-alta-disponibilidad"></a>2.2. Resiliencia, Monitoreo y Alta Disponibilidad

1. **Configuración Centralizada (Fuente Única de Verdad):**  
   Los puertos, número de réplicas e IPs se definen en `cookbooks/microservices/attributes/default.rb` y `cookbooks/haproxy/attributes/default.rb`. La plantilla `haproxy.cfg.erb` se compila a partir de estos atributos, asegurando sincronización total entre la infraestructura y el balanceador.
2. **Health Checks Activos:**  
   Directiva `check inter 2s fall 2 rise 2` con `option httpchk GET /health`. Si un contenedor se detiene, en 4 segundos pasa a estado `DOWN`. Al reanudarse, tras 2 chequeos exitosos retorna a `UP`.
3. **Conmutación por Error sin Caídas (`Zero-Downtime Failover`):**  
   Mediante `retries 3` y `option redispatch`, si un contenedor falla justo cuando entra una petición, HAProxy reenvía de inmediato el paquete a la instancia sana sin retornar errores HTTP 502/503 al cliente.
4. **Trazabilidad HTTP:**  
   Se inyecta la cabecera `X-Backend-Server: <nombre_servidor>` en cada respuesta HTTP, permitiendo auditar visualmente el balanceo secuencial con herramientas como `curl -i`.

---

# <a id="3-kubernetes"></a>3. Kubernetes (Orquestación en la Nube)

En la carpeta `3. Kubernetes/` se encuentra la solución cloud-native para orquestar los microservicios en un clúster gestionado de **Azure Kubernetes Service (AKS)** o en clústeres locales.

### <a id="31-arquitectura-de-los-manifiestos"></a>3.1. Arquitectura de los Manifiestos (`3. Kubernetes/manifests/`)

- `00-namespace.yaml`: Crea el namespace aislado `microapp` para separar la aplicación de los servicios de sistema.
- `01-users.yaml`, `02-products.yaml`, `03-orders.yaml`:
  - **Deployments:** Despliegan 2 réplicas del microservicio correspondiente (`hashicorp/http-echo:1.0.0`) escuchando en sus puertos internos dedicados (`3001`, `3002`, `3003`). Utilizan la **Downward API** de Kubernetes para inyectar el nombre del pod (`$(POD_NAME)`) en la respuesta HTTP, permitiendo comprobar qué pod atiende cada solicitud. Incluyen `livenessProbe`, `readinessProbe` y límites de CPU y memoria.
  - **Services:** De tipo `ClusterIP`. Exponen los puertos internos de forma privada dentro de la red del clúster (`users-svc:3001`, `products-svc:3002`, `orders-svc:3003`), aislando el tráfico backend del acceso directo a Internet.
- `04-ingress.yaml`: Recurso Ingress con `ingressClassName: nginx` que actúa como puerta de enlace externa, enrutando por prefijo de ruta hacia los respectivos Services `ClusterIP`.

### <a id="32-scripts-de-despliegue"></a>3.2. Scripts de Despliegue y Automatización (`3. Kubernetes/scripts/`)

- `deploy-aks.sh`: Automatiza el aprovisionamiento completo en Azure:
  1. Valida la sesión activa de Azure CLI o Azure Cloud Shell.
  2. Registra los proveedores `Microsoft.Compute` y `Microsoft.ContainerService`.
  3. Crea el Resource Group `rg-microapp-aks` en la región permitida (`eastus`).
  4. Crea el clúster AKS con tamaño de VM optimizado (`Standard_B2s`).
  5. Instala el Ingress Controller NGINX y vincula credenciales de `kubectl`.
  6. Aplica todos los manifiestos YAML y espera a que los pods alcancen el estado `Running`.
- `destroy-aks.sh`: Script de limpieza que elimina el Resource Group completo en Azure de forma no bloqueante (`--no-wait`), evitando consumos innecesarios de crédito en la suscripción.
- `prueba-k8s.sh`: Script de validación integral:
  - Inspecciona el estado de todos los recursos con `kubectl get all -n microapp`.
  - Verifica la conectividad interna directa a los Services `ClusterIP`.
  - Evalúa el enrutamiento HTTP externo a través del Ingress Controller (`/api/users`, `/api/products`, `/api/orders`).
  - Realiza la prueba de escalabilidad horizontal elástica aumentando `orders-deployment` a 4 réplicas con `kubectl scale`, validando la distribución de tráfico entre los 4 pods sin caída de servicio.
- `deploy-local.sh`: Provisión alternativa para clústeres locales (KinD / Minikube) con mapeo de puertos 80/443 para pruebas previas sin costo.

### <a id="33-modulo-opcional-terraform-aks"></a>3.3. Módulo Opcional: Terraform + AKS (`3. Kubernetes/terraform-aks/`)

Contiene los manifiestos de Terraform (`main.tf`, `variables.tf`, `providers.tf`, `outputs.tf`) para aprovisionar el clúster de AKS mediante Infraestructura como Código utilizando el proveedor `azurerm`.

---

# <a id="4-guia-de-ejecucion-y-pruebas"></a>4. Guía de Ejecución y Pruebas

### <a id="41-verificacion-infraestructura"></a>4.1. Verificación de Infraestructura (Problema 1)

1. En la máquina anfitriona, dentro de la raíz del proyecto:
   ```bash
   vagrant up
   ```
2. Conectarse a la máquina de control:
   ```bash
   vagrant ssh control-node
   ```
3. Ejecutar la inspección del estado de los nodos:
   ```bash
   bash "/vagrant/1-2. Infraestructura/scripts/verificar.sh"
   ```
4. **Validación del Ciclo de Reproducibilidad:**
   ```bash
   cd "/vagrant/1-2. Infraestructura/terraform"
   
   # 1. Destrucción controlada
   terraform destroy -auto-approve
   
   # Confirmar que los nodos quedaron desprovisionados
   ssh vm-microservices "docker ps"              # Salida vacía
   ssh vm-haproxy "systemctl status haproxy"     # Servicio inactivo / no encontrado
   
   # 2. Re-aprovisionamiento idéntico
   terraform apply -auto-approve
   
   # 3. Confirmar que la infraestructura vuelve a estar operativa
   bash "/vagrant/1-2. Infraestructura/scripts/verificar.sh"
   ```

### <a id="42-verificacion-haproxy"></a>4.2. Verificación de Balanceo y Failover (Problema 2)

1. **Acceso al Dashboard de Métricas:**  
   Navegar a [http://192.168.100.2:8080/stats](http://192.168.100.2:8080/stats) (Usuario: `admin` | Contraseña: `admin123`). Confirmar que los 3 backends reportan estado `UP` en color verde.
2. **Validación Automatizada de Balanceo y Detección de Caídas:**  
   Desde `control-node`:
   ```bash
   bash "/vagrant/1-2. Infraestructura/scripts/prueba-haproxy.sh" users 1
   ```
   El script ejecuta:
   - Peticiones HTTP continuas mostrando la alternancia Round-Robin entre `users1` y `users2`.
   - Detención del contenedor `users-service-1` con `docker stop`.
   - Envío de ráfagas HTTP demostrando cero errores de cliente mientras HAProxy marca el nodo en `DOWN`.
   - Reactivación del contenedor con `docker start` y su retorno automático a estado `UP`.

### <a id="43-verificacion-kubernetes"></a>4.3. Verificación de Kubernetes en Azure AKS (Problema 3)

#### Despliegue en Azure Cloud Shell / Azure CLI:
```bash
# 1. Clonar el repositorio y posicionarse en la rama de trabajo
git clone -b problema3pepe https://github.com/Katar012/Microproyecto2.git
cd Microproyecto2/"3. Kubernetes"/scripts

# 2. Ejecutar el despliegue automatizado del clúster AKS
bash deploy-aks.sh

# 3. Ejecutar las pruebas de verificación y escalado horizontal
bash prueba-k8s.sh

# 4. Al finalizar la evaluación, destruir el clúster para liberar recursos
bash destroy-aks.sh
```

---

# <a id="5-documentacion-adicional"></a>5. Documentación Adicional

* Para una explicación conceptual profunda, análisis de componentes y guía detallada de preguntas y modificaciones en caliente, consultar el archivo [`GUIA_SUSTENTACION.md`](./GUIA_SUSTENTACION.md).
* Credenciales de acceso predeterminadas:
  * SSH en máquinas locales: usuario `vagrant`, clave `vagrant` (o llave `id_rsa`).
  * Panel HAProxy: usuario `admin`, contraseña `admin123`.

### <a id="arbol-de-carpetas"></a>Árbol de Carpetas del Proyecto

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
│   │   │   │   ├── recipes/
│   │   │   │   │   └── default.rb
│   │   │   │   └── templates/
│   │   │   │       └── default/
│   │   │   │           └── docker-compose.yml.erb
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
