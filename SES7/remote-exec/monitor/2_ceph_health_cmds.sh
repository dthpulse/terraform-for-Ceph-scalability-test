set -ex

echo "WWWWW $0 WWWWW"

### Getting Ceph health
echo "ceph health"
ceph health
echo "ceph -s"
ceph -s
