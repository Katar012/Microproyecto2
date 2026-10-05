# 📋 Índice

* [¿Que hay hecho?](#que-hay-hecho)
* [1. Infraestructura](#1-infraestructura)
  * [1.1. Chef](#11-chef)
* [2. HAProxy](#2-haproxy)
  * [¿Que hace haproxy.cfg?](#que-hace-haproxycfg)
* [3. Kubernetes](#3-kubernetes)

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
