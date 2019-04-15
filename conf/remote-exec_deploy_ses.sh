#!/bin/bash

echo "deepsea_minions: '*'" > /srv/pillar/ceph/deepsea_minions.sls

salt-run state.orch ceph.stage.0
salt-run state.orch ceph.stage.1

cat << EOF > /srv/pillar/ceph/proposals/policy.cfg
cluster-ceph/cluster/*.sls
role-master/cluster/`hostname`*.sls
role-admin/cluster/`hostname`*.sls
role-mon/cluster/*.sls
role-mgr/cluster/*.sls
config/stack/default/global.yml
config/stack/default/ceph/cluster.yml
role-storage/cluster/*.sls
EOF

chown salt.salt /srv/pillar/ceph/proposals/policy.cfg

salt-run state.orch ceph.stage.2
salt-run state.orch ceph.stage.3
salt-run state.orch ceph.stage.4
