terraform {
  required_version = ">= 1.3.0"
  required_providers {
    # null_resource: recurso "vacio" que no crea nada en una nube, pero nos deja
    # colgarle provisioners (file / remote-exec) y un ciclo de vida create/destroy.
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}
