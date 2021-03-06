set -ex

echo "WWWWW $0 WWWWW"

monitors=($monitors)
osd_nodes=($osd_nodes)

systemctl restart salt-master

sleep 600

salt \* saltutil.sync_all

sleep 15

ceph-salt config /ceph_cluster/minions add "*"
ceph-salt config /ceph_cluster/roles/cephadm add "$master"
ceph-salt config /ceph_cluster/roles/admin add "$master"

ceph-salt config /ceph_cluster/roles/bootstrap set "${monitors[0]}"

for i in ${monitors[@]}
do
    ceph-salt config /ceph_cluster/roles/admin add "$i"
    ceph-salt config /ceph_cluster/roles/cephadm add "$i"
done

ceph-salt config /ssh generate
ceph-salt config /time_server/server_hostname set "$master"
ceph-salt config /time_server/external_servers add "ntp.suse.cz"
ceph-salt config /cephadm_bootstrap/dashboard/username set admin
ceph-salt config /cephadm_bootstrap/dashboard/password set admin
ceph-salt config /cephadm_bootstrap/dashboard/force_password_update disable
ceph-salt config /containers/registries_conf/registries add prefix=registry.suse.de location=172.16.0.24:5000 insecure=true
ceph-salt config /containers/images/ceph set "registry.suse.de/suse/sle-15-sp2/update/products/ses7/milestones/containers/ses/7/ceph/ceph"
ceph-salt config ls

ceph-salt status

ceph-salt export > myconfig.json

ceph-salt apply --non-interactive

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
    while [ ! "$(ceph osd tree --format=json | jq -r '.nodes[] | .name, .status'  | grep -v default | sed 's/null//g' | tr '\n' ' ' | awk "/$i/ && /osd./ && ! /down/{print \$0}")" ] || [  "$(ceph osd tree --format=json | jq -r '.stray[] | .status' | grep down)" ]
    do
        sleep 60
    done

done

ceph -s

ceph mgr module disable dashboard

while [ "$(ceph mgr services --format json | jq -r .dashboard)" != "null" ];do 
    sleep 5
done
