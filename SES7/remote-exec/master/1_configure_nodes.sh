set -ex

echo "WWWWW $0 WWWWW"

export PDSH_SSH_ARGS_APPEND="-i ~/.ssh/storage-automation"

. /root/terraform.tfvars

sleep 600

cat ~/conf/hosts >> /etc/hosts

master=$(awk '/master/{print $1}' /etc/hosts)

awk '!/ecp-registry/{print $1}' ~/conf/hosts > /tmp/pdsh_hosts_ips.txt

cp ~/conf/ssh/config ~/.ssh/

pdsh -w ^/tmp/pdsh_hosts_ips.txt "zypper --gpg-auto-import-keys ar -G -f $ses_repo_url ${ses_repo_url##*/}"
pdsh -w ^/tmp/pdsh_hosts_ips.txt "zypper --gpg-auto-import-keys ar -G -f http://download.suse.de/ibs/SUSE:/CA/SLE_15_SP2/SUSE:CA.repo"
pdsh -w ^/tmp/pdsh_hosts_ips.txt "zypper -qqq in -y -t pattern base enhanced_base"
pdsh -w ^/tmp/pdsh_hosts_ips.txt -x $master "zypper -qqq in --allow-vendor-change -y salt-minion bc vim less ca-certificates-suse jq netcat-openbsd which"
pdsh -w $master "zypper -qqq in --allow-vendor-change -yl salt salt-master salt-minion bc vim less ceph-salt ca-certificates-suse jq netcat-openbsd which"

pdcp -w ^/tmp/pdsh_hosts_ips.txt ~/conf/bashrc /root/.bashrc
pdcp -w ^/tmp/pdsh_hosts_ips.txt ~/conf/minions.conf /etc/salt/minion.d/minions.conf
pdcp -w ^/tmp/pdsh_hosts_ips.txt ~/conf/ssh/id_rsa* ~/.ssh/
pdcp -w ^/tmp/pdsh_hosts_ips.txt -x $master ~/conf/ssh/config ~/.ssh/
pdsh -w ^/tmp/pdsh_hosts_ips.txt "mkdir /etc/containers"
pdcp -w ^/tmp/pdsh_hosts_ips.txt ~/conf/containers/registries.conf /etc/containers/registries.conf
pdcp -w ^/tmp/pdsh_hosts_ips.txt ~/conf/hosts /tmp/hosts
pdsh -w ^/tmp/pdsh_hosts_ips.txt -x $master "cat /tmp/hosts >> /etc/hosts"
pdsh -w ^/tmp/pdsh_hosts_ips.txt "cat ~/.ssh/id_rsa2.pub >> ~/.ssh/authorized_keys"

sleep 30

cp ~/conf/master.conf /etc/salt/master.d/master.conf
systemctl enable salt-master
systemctl start salt-master

sleep 10

pdsh -w ^/tmp/pdsh_hosts_ips.txt "systemctl enable salt-minion; systemctl start salt-minion"

sleep 600

salt-key -Ay

unset PDSH_SSH_ARGS_APPEND

