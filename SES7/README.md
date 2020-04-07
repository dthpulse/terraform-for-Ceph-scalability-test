### Terraform for SES7

#### Prerequisities

- Terraform v0.12.19 or higher

- **storage-automation** key in */root/.ssh* directory

- OpenStack RC file

- SLE image has to be ready and prepared for SES cluster installation as documetntation says

- *storage-automation* private key

- *pdsh* installed on your host

#### Preparing JeOS image

Follow [this](https://gitlab.suse.de/denispolom/vagrant_ses/tree/master/openstack#preparing-image-for-the-openstack-instances) for preparing the JeOS image.

Additionally:

  - add repositories for actual distro.
    
	Example:

	```bash
    zypper ar -f http://ecp-registry/sle15sp2snap7/Product-SLES Product-SLES
	zypper ar -f http://ecp-registry/sle15sp2snap7/Module-Server-Applications Module-Server-Applications
	zypper ar -f http://ecp-registry/sle15sp2snap7/Module-Basesystem Module-Basesystem
	```

  - add repositories for *pdsh* and install the *pdsh* package

    ```
	zypper --gpg-auto-import-keys ar -f -G  https://download.opensuse.org/repositories/network:utilities/SLE_15/network:utilities.repo
	zypper --gpg-auto-import-keys ar -f -G https://download.opensuse.org/repositories/network:cluster/SLE_15_SP2/network:cluster.repo
	zypper in -y pdsh
	```

	See [Create repositories for JeOS](https://gitlab.suse.de/denispolom/terraform_ses_scalability_test/-/wikis/Create_repositories_for_JeOS)

#### How it works

1. Edit *`terraform/terraform.tfvars`*

2. Run *`deploy_cluster.sh --help`* 

3. You need your OpenStack RC file to be able to destroy the environment

#### Scripts and their location

- under directory *`local-exec`* are scripts that runs localy. Read Terraform documentation for more informations.

- under directory *`remote-exec`* are scripts that runs on deployed instances. These are scripts for deployment of SES or its services or BV testing itself. To include new scripts into the testing edit **main.tf** file and add entry under **null_resource**.

  ```json
  resource "null_resource" "scripts" {
    count = "1"
    connection {
        type = "ssh"
        user = "root"
        host = "${openstack_networking_floatingip_v2.monitor_nodes_ip.*.address[count.index]}"
        #script_path = "/root/haha.sh"
        private_key = "${file(var.ssh_key_path)}"
        password    = "${var.ssh_password}"
    }
    provisioner "remote-exec" {
        script = "remote-exec/update_monitors.sh"
    }
    depends_on = [openstack_compute_floatingip_associate_v2.master_ip]
  }
  ```

  For example you want to add script **remote-exec/my_new_script.sh** that will be run after *update_monitors.sh* then it would looks like this:

  ```json
    resource "null_resource" "scripts" {
    count = "1"
    connection {
        type = "ssh"
        user = "root"
        host = "${openstack_networking_floatingip_v2.monitor_nodes_ip.*.address[count.index]}"
        #script_path = "/root/haha.sh"
        private_key = "${file(var.ssh_key_path)}"
        password    = "${var.ssh_password}"
    }
    provisioner "remote-exec" {
        script = "remote-exec/update_monitors.sh"
    }
    provisioner "remote-exec" {
        script = "remote-exec/my_new_script.sh"
    }
    depends_on = [openstack_compute_floatingip_associate_v2.master_ip]
  }
  ```