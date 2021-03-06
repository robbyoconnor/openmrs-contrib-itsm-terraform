# Description of arguments can be found in
# ../modules/single-machine/variables.tf in this repository

variable "flavor" {
  default = "m1.medium"
}

variable "region" {
  default = "iu"
}

variable "hostname" {
  default = "melong"
}

variable "update_os" {
  default = true
}

variable "use_ansible" {
  default = false
}

variable "ansible_inventory" {
  default = "prod-tier1"
}

variable "has_data_volume" {
  default = true
}

variable "data_volume_size" {
  default = 40
}

variable "has_backup" {
  default = true
}

variable "dns_cnames" {
  default = ["issues"]
}

output "power_state" {
  value = "${module.single-machine.power_state}"
}

variable "description" {
  default = "Issue tracker"
}
