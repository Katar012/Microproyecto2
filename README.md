# 📋 Índice

* [¿Que hay hecho?](#que-hay-hecho)
* [1. Infraestructura](#1-infraestructura)
  * [1.1. Chef](#11-chef)
  * [1.2. Microservicios](#12-microservicios)
* [2. HAProxy](#2-haproxy)
  * [2.1. ¿Que hace haproxy.cfg?](#21-que-hace-haproxycfg)
* [3. Kubernetes](#3-kubernetes)
* [4. Como probar](#4-como-probar)
  * [4.1 Probar Infraestructura](#41-probar-infraestructura)
  * [4.2 Probar HAProxy](#42-probar-haproxy)
  * [4.3 Probar Kubernetes](#43-probar-kubernetes)
* [NOTAS PARA DESARROLLO](#notas-para-desarrollo)
  * [ARBOL DE CARPETAS](#arbol-de-carpetas)
---

# <a id="que-hay-hecho"></a>¿Que hay hecho?

1. Infraestructura :white_check_mark:
2. HAProxy :white_check_mark:
3. Kubernetes :x:

---

# <a id="1-infraestructura"></a>1. Infraestructura

Es un `Vagrantfile` que crea 3 VMs, el `Vagrantfile` configura la VM `control-node`.  
El `Vagrantfile` le pide a Terraform que configure las otras 2 VMs, `vm-haproxy` y `vm-microservices`.  
Terraform se apoya sobre scripts (recetas/recipes) de Chef.

> 📌 **NOTA:** El `Vagrantfile` crea carpetas compartidas desde la raiz del repo hacia las VMs.

### <a id="11-chef"></a>1.1. Chef

Chef tiene cookbooks dentro de `/chef/cookbooks/` por cada accion que debe hacerse:

1. `/docker/` instala y habilita docker
1. `/mysql/` instala y habilita mysql
2. `/microservices/` crea contenedores docker
3. `/haproxy/` instala y habilita haproxy

Luego en `/chef/roles/` Chef organiza un rol para cada VM:

1. `/microservices.rb` contiene los cookbooks `/docker/`, `/microservices/` y `/mysql/`
2. `/haproxy.rb` contiene el cookbook `/haproxy/`

Por ultimo en `/chef/nodes/` Chef asigna esos roles a cada VM:

1. `/vm-microservices.json` le da el rol `/microservices.rb` a `vm-microservices`
2. `/vm-haproxy.json` le da el rol `/haproxy.rb` a `vm-microservices`

Chef le devuelve esto a Terraform. Las otras 2 VMs son configuradas.

---

### <a id="12-microservicios"></a>1.2. Microservicios

Los <a href="https://github.com/Katar012/Microservicios">Microservicios</a> son 3 contenedores Docker que simulan un comercio basico, estos corren dentro de vm-microservices

---

# <a id="2-haproxy"></a>2. HAProxy

En el cookbook `/haproxy/` hay un recipe `default.rb`, este no solo instala HAProxy.  
Le dice a la VM que cree un `haproxy.cfg` con el contenido de `/cookbooks/haproxy/templates/default/haproxy.cfg.erb`.

### <a id="21-que-hace-haproxycfg"></a>¿Que hace haproxy.cfg?

1. Habilita estadisticas, health checks y balanceo en los contenedores docker que se crearon en `vm-microservices` a partir de los cookbooks `/docker/` y `/microservices/`
2. Eso es todo jajaja

---

# <a id="3-kubernetes"></a>3. Kubernetes

No hay nada aun.

---

# <a id="4-como-probar"></a>4. Como probar

Primero clona el repo y posicionate en la raiz.

### <a id="41-probar-infraestructura"></a>4.1. Probar Infraestructura

1. `vagrant up` levantamos maquinas
2. `vagrant ssh control-node` entramos a control-node
3. `cd /vagrant/1-2.\ Infraestructura/terraform` para ir a la carpeta compartida, raiz del repo
4. `ssh vagrant@192.168.100.3 "docker ps"` verificamos que vm-microservices tenga contenedores
5. `ssh vagrant@192.168.100.2 "sudo systemctl status haproxy"` verificamos que vm-haproxy tenga haproxy
6. `terraform destroy` destruye las instancias aprovisionadas
7. `terraform apply` las reconstruye

### <a id="42-probar-haproxy"></a>4.2. Probar HAProxy

1. Ingresar al <a href="http://192.168.100.2/stats">Dashboard: </a>`admin/admin123`
2. Abrir dos terminales en vm-microservices!!  `vagrant ssh vm-microservices`x2!!
3. En una ingresar `sudo docker logs --tail 6 -f users-service-1` en la otra ingresar `sudo docker logs --tail 6 -f users-service-2`
4. Desde cualquier terminal externa `for i in {1..6}; do curl -s http://192.168.100.2/api/users > /dev/null; done`
5. accedemos a control-node `vagrant ssh control-node`
6. `ssh vagrant@192.168.100.3 "docker ps"` desde control-node y elegimos cualquier servicio como users-service-1 
7. Ejecutar `ssh vagrant@192.168.100.3 "docker stop users-service-1"`
8. Verificar nuevamente en el dashboard, y volver a correr desde el punto 2 hacia el servicio del cual se tumbo un contenedor

### <a id="43-probar-kubernetes"></a>4.3. Probar Kubernetes

1. No hay nada aun.
2. Pero podemos probar los microservicios mientras tanto
3. Para probarlos desde terminal con curl este es un ejemplo: `curl -i -X POST http://192.168.56.3:3001/api/users   -H "Content-Type: application/json"   -d '{"name":"Jaime","email":"jaime@gmail.com","username":"jaime","password":"123"}'`
4. Mejor aun, probarlo desde el <a href="http://192.168.100.2">frontend</a> con esas credenciales que acabamos de crear

---

# <a id="notas-para-desarrollo"></a>NOTAS PARA DESARROLLO (Pa que se las pegues a la ia)

* GRACIAS POR LEER
* En el repositorio hay un monton de notas.txt guias
* La contraseña de cada maquina virtual es `vagrant`
* Frontend ubicado en: http://192.168.100.2/
* Dashboard ubicado en: http://192.168.100.2/stats/
* Usuario y contraseña del <a href="http://192.168.100.2/stats">Dashboard: </a>`admin/admin123`
* EXTREMA precaucion con los creditos de Azure en el desarrollo del punto 3
* NO EDITAR ESTE README DIOS MIO NO EDITAR

### <a id="arbol-de-carpetas"></a>ARBOL DE CARPETAS

---
```text
Microproyecto2
├── 1-2. Infraestructura
│   ├── chef
│   │   ├── cookbooks
│   │   │   ├── docker
│   │   │   │   ├── metadata.rb
│   │   │   │   └── recipes
│   │   │   │       └── default.rb
│   │   │   ├── haproxy
│   │   │   │   ├── metadata.rb
│   │   │   │   ├── notas.txt
│   │   │   │   ├── recipes
│   │   │   │   │   └── default.rb
│   │   │   │   └── templates
│   │   │   │       └── default
│   │   │   │           └── haproxy.cfg.erb
│   │   │   ├── microservices
│   │   │   │   ├── metadata.rb
│   │   │   │   └── recipes
│   │   │   │       └── default.rb
│   │   │   ├── mysql
│   │   │   │   ├── files
│   │   │   │   │   └── default
│   │   │   │   │       ├── orders_db.sql
│   │   │   │   │       ├── products_db.sql
│   │   │   │   │       └── users_db.sql
│   │   │   │   ├── metadata.rb
│   │   │   │   └── recipes
│   │   │   │       └── default.rb
│   │   │   └── notas.txt
│   │   ├── nodes
│   │   │   ├── notas.txt
│   │   │   ├── vm-haproxy.json
│   │   │   └── vm-microservices.json
│   │   ├── notas.txt
│   │   ├── roles
│   │   │   ├── haproxy.rb
│   │   │   ├── microservices.rb
│   │   │   └── notas.txt
│   │   └── solo.rb
│   └── terraform
│       ├── main.tf
│       ├── outputs.tf
│       ├── providers.tf
│       ├── terraform.tfstate
│       ├── terraform.tfstate.backup
│       └── variables.tf
├── 3. Kubernetes
├── Diagrama.png
├── README.md
└── Vagrantfile
```
---

