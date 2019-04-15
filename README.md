### Terraform for SES scalability test on OpenStack

  *For SES7 read document under SES7 directory also.*

#### Prerequisities 

- SLE image has to be ready and prepared for SES cluster installation as documentation says

- *storage-automation* private key

- *storage-automation* public key under authorized_keys on all nodes

#### How to run

- edit *`terraform.tfvars`* 

- run 

```bash
terraform validate
```

```bash
terraform plan
```

```bash
terraform apply
```

- before recreating the cluster:

   - remove entries from your */etc/hosts* file

   - remove entries from your *~/.ssh/known_hosts* file or remove this file

   - delete files:

```bash
conf/floating_ips.txt
conf/master.conf
```

#### Additional OpenStack image prerequisities:

##### cloud-init

- example of *cloud.cfg* is under *cloud* directory. 

- to apply new *cloud.cfg* delete all content under directory */var/lib/cloud/* and restart *cloud-init* service.

##### Name resolution

- to apply name resolution against name servers on OpenStack run command

```bash 
netconfig update -f
```
 
##### SSH

- set *PasswordAuthentication* to *yes*

- set *StrictHostKeyChecking* to *no*
