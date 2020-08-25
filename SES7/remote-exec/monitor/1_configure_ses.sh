set -ex

echo "WWWWW $0 WWWWW"

ceph config set global osd_pool_default_pg_autoscale_mode off

ceph config set global mon_allow_pool_delete true

ceph config set global mon_clock_drift_allowed 2.0

ceph config set osd debug_ms 1

ceph config set mon cluster_network 172.16.0.0/23

ceph config set osd public_network 172.18.0.0/23

ceph config dump
