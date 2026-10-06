name 'microservices'
description 'Rol para el nodo con Docker y Microservicios'
run_list(
  'recipe[docker]',
  'recipe[mysql]',
  'recipe[microservices]'
)
