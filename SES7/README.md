### Terraform for SES7

#### Prerequisities

- Terraform v0.12.19 or higher

- **storage-automation** key in */root/.ssh* directory

- OpenStack RC file

- SLE image has to be ready and prepared for SES cluster installation as documetntation says

- *storage-automation* private key

- *pdsh* installed on your host

#### Preparing JeOS image

  - Prepare JeOS image.

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

#### How it works

1. Edit *`terraform/terraform.tfvars`*

2. Run *`deploy_cluster.sh --help`* 

3. You need your OpenStack RC file to be able to destroy the environment

#### Scripts and their location

- under directory *`local-exec`* are scripts that runs localy. Read Terraform documentation for more informations.

- under directory *`remote-exec`* are scripts that runs on deployed instances. These are scripts for deployment of SES or its services or BV testing itself. To include new scripts into the testing just add them under *`remote-exec`* directory into the `master` or `monitor`. Scripts are desired to run on some order use number prefix with underscore on the beginning of the script name.

#### Executing

- run `./deploy_cluster.sh -h` to list or needed options.

  example:

  ```
  ./deploy_cluster.sh --apply --rsa --basename scalam19 --osd 100 --mon 1 --workers 50 \
  --registry 172.16.0.24:5000 --name scalam19 --username openstackusername --password openstactuserpwd \
  --ses-repo-url http://ecp-registry/current_ses.repo --image-name sle15sp2gm-scalability --bv-scripts-master \
  --mon-flavor m1.large --master-flavor m1.xlarge --osd-flavor m1.medium --master-sleep 300
  ```
