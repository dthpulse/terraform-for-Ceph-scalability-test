set -ex

echo "WWWWW $0 WWWWW"

monitors=($monitors)
osd_nodes=($osd_nodes)

ceph orch apply rgw --realm_name=default --zone_name=default 1 ${monitors[0]%%.*}:$(nslookup ${monitors[0]} | tail -2 | cut -d : -f2)	

radosgw-admin zone list --format=json | jq -r .zones[]

radosgw-admin realm list --format=json | jq -r .realms[]

test radosgw-admin realm list --format=json | jq -r .realms[]
test radosgw-admin zone list --format=json | jq -r .zones[]


