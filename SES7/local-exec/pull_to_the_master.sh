set -ex

. terraform/terraform.tfvars

master=$(awk '/master/{print $1}' conf/floating_ips.txt)

until nc -z $master 22
do
    sleep 60
done

scp -o "StrictHostKeyChecking=no" -i ~/.ssh/storage-automation -r conf terraform/terraform.tfvars root@$master:~

scp -o "StrictHostKeyChecking=no" -i ~/.ssh/storage-automation ~/.ssh/storage-automation* root@$master:~/.ssh/
