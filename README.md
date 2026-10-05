# 📋 Índice

* [¿Que hay hecho?](#que-hay-hecho)
* [1. Infraestructura](#1-infraestructura)
  * [1.1. Chef](#11-chef)
* [2. HAProxy](#2-haproxy)
  * [¿Que hace haproxy.cfg?](#que-hace-haproxycfg)
* [3. Kubernetes](#3-kubernetes)
* [4. Probar](#4-probar)
  * [Probar Infraestructura](#probar-infraestructura)
  * [Probar HAProxy](#probar-haproxy)
  * [Probar Kubernetes](#probar-kubernetes)
---

# <a id="que-hay-hecho"></a>¿Que hay hecho?

1. Infraestructura :white_check_mark: (FALTA CONFIGURAR TERRAFORM DESTROY y TERRAFORM APPLY)
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
2. `/microservices/` crea contenedores docker
3. `/haproxy/` instala y habilita docker

Luego en `/chef/roles/` Chef organiza un rol para cada VM:

1. `/microservices.rb` contiene los cookbooks `/docker/` y `/microservices/`
2. `/haproxy.rb` contiene el cookbook `/haproxy/`

Por ultimo en `/chef/nodes/` Chef asigna esos roles a cada VM:

1. `/vm-microservices.json` le da el rol `/microservices.rb` a `vm-microservices`
2. `/vm-haproxy.json` le da el rol `/haproxy.rb` a `vm-microservices`

Chef le devuelve esto a Terraform. Las otras 2 VMs son configuradas.

---

# <a id="2-haproxy"></a>2. HAProxy

En el cookbook `/haproxy/` hay un recipe `default.rb`, este no solo instala HAProxy.  
Le dice a la VM que cree un `haproxy.cfg` con el contenido de `/cookbooks/haproxy/templates/default/haproxy.cfg.erb`.

### <a id="que-hace-haproxycfg"></a>¿Que hace haproxy.cfg?

1. Habilita estadisticas, health checks y balanceo en los contenedores docker que se crearon en `vm-microservices` a partir de los cookbooks `/docker/` y `/microservices/`
2. Eso es todo jajaja

---

# <a id="3-kubernetes"></a>3. Kubernetes

No hay nada aun.

---

# <a id="4-probar"></a>4. Probar

Primero clona el repo y posicionate en la raiz.

### <a id="probar-infraestructura"></a>Probar Infraestructura

1. `vagrant up` levantamos maquinas
2. `vagrant ssh control-node` entramos a control-node
3. `cd /vagrant/1-2.\ Infraestructura/terraform` para ir a la carpeta compartida, raiz del repo
4. `ssh vagrant@192.168.100.3 "docker ps"` verificamos que vm-microservices tenga contenedores
5. `ssh vagrant@192.168.100.2 "sudo systemctl status haproxy"` verificamos que vm-haproxy tenga haproxy
6. falta adecuar para que `terraform destroy` y `terraform apply` demuestren que el aprovisionamiento es reproducible

### <a id="probar-haproxy"></a>Probar HAProxy

1. Ingresar al <a href="http://192.168.100.2:8080/stats">Dashboard</a>
2. `for i in {1..6}; do curl -s http://192.168.100.2/api/users; echo ""; done` verificar balanceo entre dos nodos del servicio users
3. `ssh vagrant@192.168.100.3 "docker ps"` desde control-node 
4. Tomar cualquier CONTAINER ID y ejecutar `ssh vagrant@192.168.100.3 "docker stop [CONTAINER_ID]"`
5. Verificar nuevamente en el dashboard, y volver a correr el punto 2 hacia el servicio del cual se tumbo un contenedor

---
