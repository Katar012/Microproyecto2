terraform {
  required_version = ">= 1.0.0"
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    ssh = {
      source  = "loafoe/ssh"
      version = "~> 2.6"
    }
  }
}
