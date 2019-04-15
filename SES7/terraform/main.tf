#
# reads variable from terraform.tfvars 
#
variable "tenant" {}
variable "username" {}
variable "password" {}
variable "regcode" {}
variable "keypair" {}
variable "ses_repo_url" {}
variable "basename" {}
variable "cluster_network" {}
variable "public_network" {}
variable "image_name" {}
variable "master_flavor" {}
variable "osd_flavor" {}
variable "mon_flavor" {}
variable "osd" {}
variable "mon" {}
variable "ssh_key_path" {}
variable "ssh_password" {}

variable "conf_path" {
  type = string
  default = "conf"
}

variable "local-exec_path" {
  type = string
  default = "local-exec"
}

variable "master-remote-exec_path" {
  type = string
  default = "remote-exec/master"
}

variable "monitor-remote-exec_path" {
  type = string
  default = "remote-exec/monitor"
}

#
# setting up provider
#
provider "openstack" {
    tenant_name         = var.tenant
    user_name           = var.username
    password            = var.password
    user_domain_name    = "ldap_users"
    project_domain_name = "default"
    auth_url            = "https://engcloud.prv.suse.net:5000/v3"
    region              = "CustomRegion"
}

#
# OSD nodes 
#
resource "openstack_compute_instance_v2" "osd-node" {
    count           = var.osd
    name            = "${var.basename}-osd-${count.index + 1}"
    image_name      = var.image_name
    flavor_name     = var.osd_flavor
    key_pair        = var.keypair
    security_groups = ["default"]
    stop_before_destroy = true
    network {
        name = var.cluster_network
    }
    network {
        name = var.public_network
    }
}

# 
# Monitors
#
resource "openstack_compute_instance_v2" "monitor-node" {
    count           = var.mon
    name            = "${var.basename}-monitor-${count.index + 1}"
    image_name      = var.image_name
    flavor_name     = var.mon_flavor
    key_pair        = var.keypair
    security_groups = ["default"]
    stop_before_destroy = true
    network {
        name = var.cluster_network
    }
    network {
        name = var.public_network
    }
}

#
# master
#
resource "openstack_compute_instance_v2" "master" {
    name            = "${var.basename}-master"
    image_name      = var.image_name
    flavor_name     = var.master_flavor
    key_pair        = var.keypair
    security_groups = ["default"]
    stop_before_destroy = true
    network {
        name = var.cluster_network
    }
    network {
        name = var.public_network
    }
    depends_on = [openstack_compute_instance_v2.osd-node]
}

#
# network settings for OSD nodes
#
resource "null_resource" "osd_nodes_ip" {
    count                 = var.osd
    provisioner "local-exec" {
        command = "echo '${openstack_compute_instance_v2.osd-node.*.network.0.fixed_ip_v4[count.index]} ${var.basename}-osd-${count.index +1}.openstack.local ${var.basename}-osd-${count.index +1}'>> ${var.conf_path}/hosts"
    }
}

#
# floating IPs for Monitor nodes
#
resource "openstack_networking_floatingip_v2" "monitor_nodes_ip" {
    count = var.mon
    pool = "floating"
}

#
# network settings for Monitor nodes
#
resource "openstack_compute_floatingip_associate_v2" "monitor_nodes_ip" {
    count                 = var.mon
    floating_ip           = openstack_networking_floatingip_v2.monitor_nodes_ip.*.address[count.index]
    instance_id           = openstack_compute_instance_v2.monitor-node.*.id[count.index]
    fixed_ip              = openstack_compute_instance_v2.monitor-node.*.network.1.fixed_ip_v4[count.index]
    wait_until_associated = true
    provisioner "local-exec" {
        command = "echo \"${openstack_networking_floatingip_v2.monitor_nodes_ip.*.address[count.index]} ${var.basename}-monitor-${count.index + 1}-openstack.local ${var.basename}-monitor-${count.index + 1}\" >> ${var.conf_path}/floating_ips.txt"
    }
    provisioner "local-exec" {
        command = "echo '${openstack_compute_instance_v2.monitor-node.*.network.0.fixed_ip_v4[count.index]} ${var.basename}-monitor-${count.index +1}.openstack.local ${var.basename}-monitor-${count.index +1}'>> ${var.conf_path}/hosts"
    }
}

#
# floating IP for master
#
resource "openstack_networking_floatingip_v2" "master_nodes_ip" {
    pool = "floating"
    depends_on = [null_resource.osd_nodes_ip]
}

#
# network settings for master
#
resource "openstack_compute_floatingip_associate_v2" "master_nodes_ip" {
    count                 = "1"
    floating_ip           = openstack_networking_floatingip_v2.master_nodes_ip.*.address[count.index]
    instance_id           = openstack_compute_instance_v2.master.*.id[count.index]
    fixed_ip              = openstack_compute_instance_v2.master.*.network.1.fixed_ip_v4[count.index]
    wait_until_associated = true
    provisioner "local-exec" {
        command = "echo \"${openstack_networking_floatingip_v2.master_nodes_ip.*.address[count.index]} ${var.basename}-master.openstack.local ${var.basename}-master\" >> ${var.conf_path}/floating_ips.txt"
    }
    provisioner "local-exec" {
        command = "echo \"master: ${var.basename}-master\" > ${var.conf_path}/minions.conf"
    }
    provisioner "local-exec" {
        command = "echo '${openstack_compute_instance_v2.master.*.network.0.fixed_ip_v4[count.index]} ${var.basename}-master.openstack.local ${var.basename}-master'>> ${var.conf_path}/hosts"
    }
    provisioner "local-exec" {
        command = "bash ${var.local-exec_path}/pull_to_the_master.sh"
    }
    depends_on = [null_resource.osd_nodes_ip]
}

#
# creates volumes for OSDs 
#
resource "openstack_blockstorage_volume_v2" "volume_1" {
    count = var.osd
    name  = "volume-${count.index + 1}"
    size  = 10
}

#
# attaching created volumes to OSD nodes
#
resource "openstack_compute_volume_attach_v2" "va_1" {
    count       = var.osd
    instance_id = openstack_compute_instance_v2.osd-node.*.id[count.index]
    volume_id   = openstack_blockstorage_volume_v2.volume_1.*.id[count.index]
}

#
# output
#
output "osd_nodes" {
    value = openstack_compute_instance_v2.osd-node.*.name
}

output "monitor_nodes" {
    value = openstack_compute_instance_v2.monitor-node.*.name
}

output "master" {
    value = openstack_compute_instance_v2.master.*.name
}

output "monitor_nodes_floating_ip" {
    value = openstack_compute_floatingip_associate_v2.monitor_nodes_ip.*.floating_ip
}

output "master_floating_ip" {
    value = openstack_compute_floatingip_associate_v2.master_nodes_ip.*.floating_ip
}
