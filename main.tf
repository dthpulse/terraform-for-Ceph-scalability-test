#
# reads variable from terraform.tfvars 
#
variable "openstack_tenant" {}
variable "openstack_username" {}
variable "openstack_password" {}
variable "regcode" {}
variable "keypair" {}
variable "ses_repo_url" {}
variable "minions_basename" {}
variable "master_basename" {}
variable "image_name" {}
variable "flavor_name" {}

#
# number of osd nodes
#
variable "count" {
  default = 3
}

#
# setting up provider
#
provider "openstack" {
  tenant_name         = "${var.openstack_tenant}"
  user_name           = "${var.openstack_username}"
  password            = "${var.openstack_password}"
  user_domain_name    = "ldap_users"
  project_domain_name = "default"
  auth_url            = "https://engcloud.prv.suse.net:5000/v3"
  region              = "CustomRegion"
}

#
# OSD nodes 
#
resource "openstack_compute_instance_v2" "osd-node" {
  count           = "${var.count}"
  name            = "${var.minions_basename}-${count.index + 1}"
  image_name      = "${var.image_name}"
  flavor_name     = "${var.flavor_name}"
  key_pair        = "${var.keypair}"
  security_groups = ["default"]
  stop_before_destroy = true
  network {
    name = "fixed"
  }
}

#
# master
#
resource "openstack_compute_instance_v2" "master" {
  name            = "${var.master_basename}"
  image_name      = "${var.image_name}"
  flavor_name     = "${var.flavor_name}"
  key_pair        = "${var.keypair}"
  security_groups = ["default"]
  stop_before_destroy = true
  network {
    name = "fixed"
  }
  depends_on = ["openstack_compute_instance_v2.osd-node"]
}

#
# floating IPs for OSD nodes
#
resource "openstack_networking_floatingip_v2" "osd_nodes_ip" {
  count = "${var.count}"
  pool = "floating"
}

# network settings for OSD nodes
# creates master.conf
resource "openstack_compute_floatingip_associate_v2" "osd_nodes_ip" {
  count                 = "${var.count}"
  floating_ip           = "${openstack_networking_floatingip_v2.osd_nodes_ip.*.address[count.index]}"
  instance_id           = "${openstack_compute_instance_v2.osd-node.*.id[count.index]}"
  fixed_ip              = "${openstack_compute_instance_v2.osd-node.*.network.0.fixed_ip_v4[count.index]}"
  wait_until_associated = true
  provisioner "remote-exec" {
    inline = [
      "zypper ar -f ${var.ses_repo_url} sesrepo",
      "zypper -qqq in -yl salt-minion",
    ]
    connection {
      host     = "${self.floating_ip}"
      type     = "ssh"
      user     = "root"
      password = "susetesting"
    }
  }
  provisioner "local-exec" {
    command = "echo \"${openstack_networking_floatingip_v2.osd_nodes_ip.*.address[count.index]} ${var.minions_basename}-${count.index + 1}\" >> conf/floating_ips.txt"
  }
}

#
# floating IP for master
#
resource "openstack_networking_floatingip_v2" "master_ip" {
  pool = "floating"
depends_on = ["openstack_networking_floatingip_v2.osd_nodes_ip"]
}

# network settings for master
# creates master.conf
resource "openstack_compute_floatingip_associate_v2" "master_ip" {
  depends_on = ["openstack_networking_floatingip_v2.osd_nodes_ip"]
  count                 = "1"
  floating_ip           = "${openstack_networking_floatingip_v2.master_ip.*.address[count.index]}"
  instance_id           = "${openstack_compute_instance_v2.master.*.id[count.index]}"
  fixed_ip              = "${openstack_compute_instance_v2.master.*.network.0.fixed_ip_v4[count.index]}"
  wait_until_associated = true
  depends_on = ["openstack_networking_floatingip_v2.osd_nodes_ip"]
  provisioner "remote-exec" {
    inline = [
      "zypper ar -f ${var.ses_repo_url} sesrepo",
      "zypper -qqq in -yl deepsea salt-minion",
    ]
  }
  connection {
    host     = "${self.floating_ip}"
    type     = "ssh"
    user     = "root"
    password = "susetesting"
  }
  depends_on = ["openstack_networking_floatingip_v2.osd_nodes_ip"]
  provisioner "local-exec" {
    command = "echo \"${openstack_networking_floatingip_v2.master_ip.*.address[count.index]} ${var.master_basename}\" >> conf/floating_ips.txt"
  }
  provisioner "local-exec" {
    command = "echo \"master: ${openstack_compute_floatingip_associate_v2.master_ip.fixed_ip}\" > conf/master.conf"
  }
  depends_on = ["openstack_networking_floatingip_v2.osd_nodes_ip"]
  provisioner "local-exec" {
    command = "bash conf/configure_master_conf.sh"
  }
  depends_on = ["openstack_networking_floatingip_v2.osd_nodes_ip"]
  provisioner "remote-exec" {
    inline = [
      "echo \"master: ${openstack_compute_floatingip_associate_v2.master_ip.fixed_ip}\" > /etc/salt/minion.d/master.conf",
      "systemctl enable salt-minion salt-master",
      "systemctl start salt-master salt-minion",
      "sleep 120",
      "salt-key -Ay",
    ]
  }
  depends_on = ["openstack_networking_floatingip_v2.osd_nodes_ip"]
}

#
# creates volumes for OSDs 
#
resource "openstack_blockstorage_volume_v2" "volume_1" {
  count = "${var.count}"
  name = "volume-${count.index + 1}"
  size = 1
}

# attaching created volumes to OSD nodes
resource "openstack_compute_volume_attach_v2" "va_1" {
  count = "${var.count}"
  instance_id = "${openstack_compute_instance_v2.osd-node.*.id[count.index]}"
  volume_id   = "${openstack_blockstorage_volume_v2.volume_1.*.id[count.index]}"
}

#
# output
#
output "osd_nodes" {
  value = "${openstack_compute_instance_v2.osd-node.*.name}"
}

output "master" {
  value = "${openstack_compute_instance_v2.master.*.name}"
}

output "osd_nodes_floating_ip" {
  value = "${openstack_compute_floatingip_associate_v2.osd_nodes_ip.*.floating_ip}"
}

output "master_floating_ip" {
  value = "${openstack_compute_floatingip_associate_v2.master_ip.*.floating_ip}"
}
