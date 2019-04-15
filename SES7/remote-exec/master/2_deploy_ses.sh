set -ex

echo "WWWWW $0 WWWWW"

monitors=($monitors)
osd_nodes=($osd_nodes)

systemctl restart salt-master

sleep 600

salt \* saltutil.sync_all

sleep 15

ceph-salt config "/Ceph_Cluster/Minions add *" 
ceph-salt config "/Ceph_Cluster/Roles/Admin add $master"

ceph-salt config "/Ceph_Cluster/Roles/Bootstrap set ${monitors[0]}"

for i in ${monitors[@]}
do
    ceph-salt config "/Ceph_Cluster/Roles/Admin add $i"
done

ceph-salt config "/SSH generate"
ceph-salt config "/Time_Server/Server_Hostname set $master"
ceph-salt config "/Time_Server/External_Servers add 0.us.pool.ntp.org"
ceph-salt config "/Containers/Images/ceph set registry.suse.de/suse/sle-15-sp2/update/products/ses7/milestones/containers/ses/7/ceph/ceph"
ceph-salt config ls

ceph-salt status

ceph-salt export > myconfig.json

ceph-salt deploy --non-interactive

cat <<EOF > cluster.yaml
service_type: mon
placement:
  host_pattern: '*monitor*'
---
service_type: mgr
placement:
  host_pattern: '*monitor*'
---
service_type: osd
placement:
  host_pattern: '*osd*'
data_devices:
  all: true
EOF

ceph orch apply -i cluster.yaml

# wait until all OSDs are deployed
for i in ${osd_nodes[@]%%.*}
do  
    until [ "$(ceph orch device ls | grep LVM | awk "/$i/{print \$6 | \"sort -u\"}")" == "False" ]
    do  
        sleep 60
    done
done

ceph -s

