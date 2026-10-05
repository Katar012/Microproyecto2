name 'haproxy'
maintainer 'Katar012 - jvilamarin31 - AlejandroRodriguezDev'
license 'RE MARICON EL QUE LO LEA'
description 'Instala y habilita el servicio HAProxy'
version '0.2.0'
chef_version '>= 16.0'

# Solo para LEER los atributos node['microapp'] (lista de servicios, puertos e
# instancias). La receta de microservices NO se ejecuta en vm-haproxy, porque
# el run_list del rol haproxy solo tiene recipe[haproxy].
depends 'microservices'
