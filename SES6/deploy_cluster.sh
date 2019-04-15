#!/usr/bin/env bash

trap 'revert_master_sleep ;exit' INT

TEMP=$(getopt -o h --long "help,apply,existing,destroy,rsa,rcfile:,basename:,osd:,mon:,workers:,registry:, \
	name:,username:,password:,tenant:,keypair:,cluster-network:,public-network:,image-name:,mon-flavor:, \
	osd-flavor:,master-flavor:,ses-repo-url:,master-sleep:," \
	-n 'deploy_cluster.sh' -- "$@")

if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

apply=false
destroy=false
rsa=false
existing=false
domain="openstack.local"

all_given_args="$(echo $TEMP | tr ' ' '\n' | grep "\-\-")"
apply_required_args=(apply basename osd mon workers rsa registry name username password image-name)
destroy_required_args=(destroy name)
existing_required_args=(existing name)

function helpme () {
    cat << EOF

    usage: deploy_cluster.sh --help
    deploy_cluster.sh [arguments]

    Deploy SES cluster on ECP OpenStack
    
    arguments to deploy SES:
      --apply                                   runs 'terraform apply -auto-approve'
                                                with given configuration
      --rsa                                     creates ssh RSA keys
      --basename BASENAME                       basename for deployed nodes
      --osd NUMBER                              number of OSD nodes
      --mon NUMBER                              number of Monitor nodes
      --workers NUMBER                          number of salt-master worker threads
      --registry IP                             IP of registry server 172.16.0.6
      --name NAME                               name of your project under which terraform files 
                                                will be saved
      --username USERNAME                       username for login to ECP
      --password PASSWORD                       password for login to ECP
      --image-name IMAGE                        OpenStack image name

      Optional arguments:
        --ses-repo-url URL                      URL to SES repo http://ecp-registry/ses7m1
        --tenant TENANT_NAME
        --keypair KEY
        --cluster-network IP
        --public-network IP
        --mon-flavor FLAVOR
        --osd-flavor FLAVOR
        --master-flavor FLAVOR
        --master-sleep SECONDS                  time to sleep after salt-master is restarted.
                                                Default is 600s. Value depends on workers number.
                                                Larger is workers number then larger is time to 
                                                wait for salt-master till all workers are listening.
                                                600s is meant for large number of workers > 100.  

    arguments to deploy SES from existing project:
      --existing
      --name NAME                               name of existing project that was destroyed
                                                and needs to be deployed again
    arguments to destroy SES cluster:
      --destroy                                 runs 'terraform destroy -auto-approve'
      --name NAME                               name of your project to be destroyed
      --rcfile PATH                             Path to OpenStack rc file.

EOF
}

function arguments_check () {
required_args=($@)
for i in ${required_args[@]}
do
    echo "$all_given_args" | grep -w $i 2>&1 > /dev/null
    if [ $? -ne 0 ]
    then
        echo "Missing required parameter: --${i}"
	exit 1
    fi
done
}

function terraform_apply () {
    local name=$1
    cd projects/$name || exit 1
    terraform init terraform/
	mkdir terraform/log 2>/dev/null
    TF_LOG=TRACE TF_LOG_PATH=terraform/log/terraform.log terraform apply -auto-approve \
	    -state=terraform/terraform.tfstate -var-file=terraform/terraform.tfvars terraform/
    cd - 2>&1 >/dev/null
}

function tweak_terraform_tfvars () {

    cat << EOF > projects/$name/terraform/terraform.tfvars
tenant="ses"
regcode="1253ad01b6b7498eab1841c256de05f4"
keypair="storage-automation"
cluster_network="scalability1"
public_network="scalability2"
mon_flavor="c8.large"
osd_flavor="m1.small"
master_flavor="c8.large"
ssh_key_path="$HOME/.ssh/storage-automation"
ssh_password="susetesting"
ses_repo_url="URL"
username=USERNAME
password=PASSWORD
basename=BASENAME
image_name=IMAGE
osd=NUM
mon=NUM
EOF

    for argument in $@
    do
	argument=${argument:2}
        argument=${argument//-/_}
        arg_variable=$(eval echo \$$argument)
        sed -i "s/^$argument=.*/$argument=\"$arg_variable\"/" projects/$name/terraform/terraform.tfvars
    done
}

function master_sleep () {
    if [ ! -z "$master_sleep" ]
    then
        sed -i "s/sleep 600/sleep $master_sleep/" \
                remote-exec/deploy_ses.sh \
                remote-exec/configure_nodes.sh
    fi
}

function revert_master_sleep () {
    # revert master-sleep
    if [ ! -z "$master_sleep" ]
    then
        sed -i "s/sleep $master_sleep/sleep 600/" \
                remote-exec/deploy_ses.sh \
                remote-exec/configure_nodes.sh
    fi
}

# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"

while true
do
    case $1 in
        --apply) apply=true; shift;;
        --existing) existing=true; shift;;
	--destroy) destroy=true; shift;;
	--rsa) rsa=true; shift;;
	--rcfile) rcfile=$2 ; shift 2;;
	--basename) basename=$2; shift 2;;
	--osd) osd=$2; shift 2;;
	--mon) mon=$2; shift 2;;
	--workers) workers=$2; shift 2;;
	--registry) registry=$2; shift 2;;
	--name) name=$2; shift 2;;
	--username) username=$2; shift 2;;
	--password) password=$2; shift 2;;
	--ses-repo-url) ses_repo_url=$(echo $2 | sed 's/\//\\\//g'); shift 2;;
	--tenant) tenant=$2; shift 2;;
	--keypair) keypair=$2; shift 2;;
	--cluster-network) cluster_network=$2; shift 2;;
	--public-network) public_network=$2; shift 2;;
	--image-name) image_name=$2; shift 2;;
	--mon-flavor) mon_flavor=$2; shift 2;;
	--osd-flavor) osd_flavor=$2; shift 2;;
	--master-flavor) master_flavor=$2; shift 2;;
	--master-sleep) master_sleep=$2; shift 2;;
        --help|-h) helpme; exit;;
	--) shift; break;;
	*) break;;
    esac
done

if [ "$apply" == "true" ]
then
    arguments_check ${apply_required_args[@]}

    if [ -d "projects/$name" ]
    then
        echo "Directory projects/$name exists"
	exit 1
    fi

    mkdir -p projects/$name/conf/{ssh,containers} 2>/dev/null
    ln -s $PWD/local-exec projects/$name/
    ln -s $PWD/remote-exec projects/$name/
    cp -rap $PWD/terraform projects/$name/
    
    # bashrc
    echo "export master=" >> projects/$name/conf/bashrc
    echo "export osd_nodes=" >> projects/$name/conf/bashrc
    echo "export monitors=" >> projects/$name/conf/bashrc

    for i in $(seq 1 $mon)
    do
        sed -i "/^export monitors=/ s/$/${basename}-monitor-${i}.${domain} /" projects/$name/conf/bashrc
    done

    for i in $(seq 1 $osd)
    do
        sed -i "/^export osd_nodes=/ s/$/${basename}-osd-${i}.${domain} /" projects/$name/conf/bashrc
    done

    for i in ${basename}-master
    do
        sed -i "/^export master=/ s/$/${i}.${domain} /" projects/$name/conf/bashrc
    done

    sed -i "s/=${basename:0:1}/=\"${basename:0:1}/g; \
	    s/.$//; \
	    s/$/\"/" \
	    projects/$name/conf/bashrc

    echo -e "\n New conf/bashrc created:"

    echo -e "\n = = ="
    cat "projects/$name/conf/bashrc"
    echo -e " = = =\n"


    # worker threads
    echo "worker_threads: $workers" > projects/$name/conf/master.conf
    echo -e "\n==="
    cat projects/$name/conf/master.conf
    echo -e "===\n"

    # rsa
    if [ "$rsa" == "true" ]
    then
        ssh-keygen -N "" -t rsa -b 4096 -f projects/$name/conf/ssh/id_rsa2 -C "scalability-testing"
    fi

    # ssh config
    cat << EOF > projects/$name/conf/ssh/config
StrictHostKeyChecking no
Host *
IdentityFile /root/.ssh/id_rsa2
EOF

    echo -e "\n Created file conf/ssh/config: \n"
    echo "= = ="
    cat projects/$name/conf/ssh/config
    echo "= = ="

    # registries
    echo "${registry%%:*} ecp-registry.openstack.local ecp-registry" > projects/$name/conf/hosts
    cat << EOF > projects/$name/conf/containers/registries.conf
[[registry]]
prefix = "registry.suse.de"
location = "$registry"
insecure = true
EOF

    master_sleep
   
    # tweak terraform.tfvars
    tweak_terraform_tfvars $all_given_args

    # deploy cluster
    terraform_apply $name

    revert_master_sleep

elif [ "$destroy" == "true" ]
then
    arguments_check ${destroy_required_args[@]}
	cd projects/$name 2>/dev/null || exit 1
    terraform destroy -state=terraform/terraform.tfstate \
	    -var-file=terraform/terraform.tfvars -auto-approve terraform/
    cd - 2>&1 > /dev/null
    if [ ! -z "$rcfile" ]
    then
        . $rcfile
        echo "Removing all available volume resources from OpenStack"
        openstack volume list | awk '/available/ {print $2}' | xargs -I {} openstack volume delete {}
	for i in $(env | grep OS_ | cut -d = -f 1);do unset $i; done
    fi

elif [ "$existing" == "true" ]
then
    arguments_check ${existing_required_args[@]}
    master_sleep
	rm -f projects/$name/conf/floating_ips.txt \
	projects/$name/.terraform \
	projects/$name/terraform/terraform.tfstate* \
	projects/$name/terraform/.terraform.tfstate*
	echo "${registry%%:*} ecp-registry.openstack.local ecp-registry" > projects/$name/conf/hosts
    terraform_apply $name
    revert_master_sleep

else
    exit 1
fi
