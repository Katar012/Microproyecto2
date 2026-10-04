variable "haproxy_ip" {
  type    = string
  default = "192.168.100.2"
}

variable "microservices_ip" {
  type    = string
  default = "192.168.100.3"
}

variable "ssh_user" {
  type    = string
  default = "vagrant"
}

variable "ssh_password" {
  type    = string
  default = "vagrant"
}
