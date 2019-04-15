set -ex

master=$master
monitors=($monitors)
osd_nodes=($osd_nodes)

echo "deepsea_minions: '*'" > /srv/pillar/ceph/deepsea_minions.sls

salt-run state.orch ceph.stage.0
salt-run state.orch ceph.stage.1


cat << EOF > /srv/pillar/ceph/proposals/policy.cfg
cluster-ceph/cluster/*.sls
role-master/cluster/${master}*.sls
role-admin/cluster/${master}*.sls
config/stack/default/global.yml
config/stack/default/ceph/cluster.yml
role-prometheus/cluster/${master}*.sls
role-grafana/cluster/${master}*.sls
EOF

for i in ${monitors[@]}
do
    echo "role-mon/cluster/${i}*.sls" >> /srv/pillar/ceph/proposals/policy.cfg
    echo "role-mgr/cluster/${i}*.sls" >> /srv/pillar/ceph/proposals/policy.cfg
done

for i in ${osd_nodes[@]}
do
    echo "role-storage/cluster/${i}*.sls" >> /srv/pillar/ceph/proposals/policy.cfg
done

sleep 5

salt-run state.orch ceph.stage.2

cat << EOF > /srv/salt/ceph/configuration/files/drive_groups.yaml
default:
  target: '*'
  data_devices:
    all: true
EOF

sleep 5

salt-run state.orch ceph.stage.3
salt-run state.orch ceph.stage.4
