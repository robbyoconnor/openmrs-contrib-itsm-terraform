# state file stored in S3
terraform {
  backend "s3" {
    bucket = "openmrs-terraform-state-files"
    key    = "mokolo.tfstate"
  }
}

# Change to ${var.tacc_url} if using tacc datacenter
provider "openstack" {
  auth_url = "${var.iu_url}"
}

data "terraform_remote_state" "base" {
    backend = "s3"
    config {
        bucket = "openmrs-terraform-state-files"
        key    = "basic-network-setup.tfstate"
    }
}

# Description of arguments can be found in
# ../modules/single-machine/variables.tf in this repository
module "single-machine" {
  source            = "../modules/single-machine"

  # Change values in variables.tf file instead
  flavor            = "${var.flavor}"
  hostname          = "${var.hostname}"
  region            = "${var.region}"
  update_os         = "${var.update_os}"
  use_ansible       = "${var.use_ansible}"
  ansible_inventory = "${var.ansible_inventory}"
  has_data_volume   = "${var.has_data_volume}"
  data_volume_size  = "${var.data_volume_size}"
  has_backup        = "${var.has_backup}"
  dns_cnames        = "${var.dns_cnames}"
  extra_security_groups = ["${openstack_compute_secgroup_v2.bamboo-remote-agent.name}"]


  # Global variables
  # Don't change values below
  image             = "${var.image}"
  project_name      = "${var.project_name}"
  ssh_username      = "${var.ssh_username}"
  ssh_key_file      = "${var.ssh_key_file}"
  domain_dns        = "${var.domain_dns}"
  ansible_repo      = "${var.ansible_repo}"
}

resource "dme_record" "private-dns" {
  domainid    = "${var.domain_dns["openmrs.org"]}"
  name        = "sonar-internal"
  type        = "A"
  value       = "${module.single-machine.private_address}"
  ttl         = 300
  gtdLocation = "DEFAULT"
}


resource "openstack_compute_secgroup_v2" "bamboo-remote-agent" {
  name        = "${var.project_name}-bamboo-server-agents-sonar"
  description = "Allow bamboo agents to connect to mysql sonar server (terraform)."

  # Bamboo agents Jetstream in IU (works with the private IP only)
  rule {
    from_port      = 3306
    to_port        = 3306
    ip_protocol    = "tcp"
    from_group_id  = "${data.terraform_remote_state.base.secgroup-bamboo-remote-agent-id-iu}"
  }

  ##### after migration, the agents shoud connect using the private DNS - ITSM-4090
  # yak jetstream
  rule {
    from_port   = 3306
    to_port     = 3306
    ip_protocol = "tcp"
    cidr        = "149.165.168.253/32"
  }

  # yokobue jetstream
  rule {
    from_port   = 3306
    to_port     = 3306
    ip_protocol = "tcp"
    cidr        = "149.165.169.187/32"
  }

  # yue jetstream
  rule {
    from_port   = 3306
    to_port     = 3306
    ip_protocol = "tcp"
    cidr        = "149.165.168.182/32"
  }
}