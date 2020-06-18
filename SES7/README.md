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

  - on ecp-registry server mount current SLE image to */srv/www/htdocs/current_os*

  - on ecp-registry server mount current SES image to */srv/www/htdocs/current_ses*

  - add repositories for actual distro.
    
	Example:

	```bash
    zypper ar -f http://ecp-registry/current_os.repo
	```

  - add repositories for *pdsh* and install the *pdsh* package

    ```
	zypper --gpg-auto-import-keys ar -f -G  https://download.opensuse.org/repositories/network:utilities/SLE_15/network:utilities.repo
	zypper --gpg-auto-import-keys ar -f -G https://download.opensuse.org/repositories/network:cluster/SLE_15_SP2/network:cluster.repo
	zypper in -y pdsh
	```

  - install *kernel-default* instead of kernel-default-base

	See [Create repositories for JeOS](https://gitlab.suse.de/denispolom/terraform_ses_scalability_test/-/wikis/Create_repositories_for_JeOS)

#### How it works

1. Edit *`terraform/terraform.tfvars`*

2. Run *`deploy_cluster.sh --help`* 

3. You need your OpenStack RC file to be able to destroy the environment

#### Scripts and their location

- under directory *`local-exec`* are scripts that runs localy. Read Terraform documentation for more informations.

- under directory *`remote-exec`* are scripts that runs on deployed instances. These are scripts for deployment of SES or its services or BV testing itself. To include new scripts into the testing edit **main.tf** file and add entry under **null_resource**.

  ```
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

  ```
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
