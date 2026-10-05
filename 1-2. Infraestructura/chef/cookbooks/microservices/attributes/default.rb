# Atributos del cookbook microservices = FUENTE UNICA DE VERDAD de la aplicacion.
#
# - La receta microservices/default.rb los usa para crear los contenedores.
# - La plantilla haproxy.cfg.erb los usa para generar los backends de HAProxy.
#
# Asi, si cambias aqui el numero de instancias o un puerto, los contenedores y
# el balanceador SIEMPRE quedan sincronizados (no hay que tocar dos archivos).

# Imagen que hace de microservicio (servidor HTTP minimo que responde un texto)
default['microapp']['image'] = 'hashicorp/http-echo:1.0.0'

# Separacion entre puertos de host de las instancias de un mismo servicio:
#   instancia 1 -> puerto base (3001), instancia 2 -> 3011, instancia 3 -> 3021 ...
default['microapp']['port_step'] = 10

# port = puerto INTERNO del contenedor (el que pide el enunciado: 3001/3002/3003)
# instances = cuantas copias del contenedor se levantan (minimo 2 para round-robin)
default['microapp']['services'] = {
  'users'    => { 'port' => 3001, 'instances' => 2 },
  'products' => { 'port' => 3002, 'instances' => 2 },
  'orders'   => { 'port' => 3003, 'instances' => 2 },
}
