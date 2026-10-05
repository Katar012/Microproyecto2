variable "haproxy_ip" {
  type        = string
  default     = "192.168.100.2"
  description = "IP privada de vm-haproxy (debe coincidir con el Vagrantfile)"
}

variable "microservices_ip" {
  type        = string
  default     = "192.168.100.3"
  description = "IP privada de vm-microservices (debe coincidir con el Vagrantfile)"
}

variable "ssh_user" {
  type        = string
  default     = "vagrant"
  description = "Usuario con el que Terraform entra por SSH a las VMs target"
}

# Antes entrabamos con contraseña (vagrant/vagrant). Ahora Terraform usa la llave
# privada que el control-node genera en su provision (ssh-keygen) y que copia a las
# VMs target con ssh-copy-id. Asi cumplimos "llaves SSH correspondientes".
variable "ssh_private_key_path" {
  type        = string
  default     = "/home/vagrant/.ssh/id_rsa"
  description = "Ruta (dentro del control-node) de la llave privada SSH"
}

variable "ubuntu_version" {
  type        = string
  default     = "22.04"
  description = "Version de Ubuntu que se exige en las VMs target (se valida antes de aprovisionar)"
}
