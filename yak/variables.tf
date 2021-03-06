# Description of arguments can be found in
# ../modules/single-machine/variables.tf in this repository

variable "flavor" {
  default = "m1.small"
}

variable "region" {
  default = "iu"
}

variable "hostname" {
  default = "yak"
}

variable "update_os" {
  default = true
}

variable "use_ansible" {
  default = true
}

variable "ansible_inventory" {
  default = "prod-tier2"
}

variable "has_data_volume" {
  default = false
}

variable "data_volume_size" {
  default = 10
}

variable "has_backup" {
  default = false
}

variable "dns_cnames" {
  default = []
}

variable "description" {
  default = "Bamboo agent"
}
