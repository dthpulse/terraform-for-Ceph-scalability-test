set -ex

. terraform/terraform.tfvars

sleep 60

master=$(awk '/master/{print $1}' conf/floating_ips.txt)

scp -o "StrictHostKeyChecking=no" -i ~/.ssh/storage-automation -r conf terraform/terraform.tfvars root@$master:~

scp -o "StrictHostKeyChecking=no" -i ~/.ssh/storage-automation ~/.ssh/storage-automation* root@$master:~/.ssh/
