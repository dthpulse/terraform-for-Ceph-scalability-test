### Terraform for SES scalability test on OpenStack

  *For SES7 read document under SES7 directory also.*

#### Prerequisities 

- SLE image has to be ready and prepared for SES cluster installation as documentation says

- *storage-automation* private key

- *storage-automation* public key under authorized_keys on all nodes

##### cloud-init

- example of *cloud.cfg* is under *cloud* directory. 

- to apply new *cloud.cfg* delete all content under directory */var/lib/cloud/* and restart *cloud-init* service.

