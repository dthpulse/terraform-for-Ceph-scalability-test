#!/bin/bash

# cat conf/floating_ips.txt >> /etc/hosts


for minion in `cat conf/floating_ips.txt | grep $(grep minions_basename terraform.tfvars | cut -d = -f 2 | sed 's/"//g') | awk '{print $2}'`
do
	scp -i ~/.ssh/storage-automation conf/master.conf $minion:/etc/salt/minion.d/
	ssh -i ~/.ssh/storage-automation $minion "systemctl start salt-minion; systemctl enable salt-minion"
done

# rm -f conf/floating_ips.txt master.conf
