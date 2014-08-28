#!/bin/bash

base_image_type=${1:-fedora}
base_image_rev=${2}
base_image_arch=${3}

source openrc admin admin

case ${base_image_type} in
    'fedora')
        base_image_rev=${base_image_rev:-20}
        base_image_arch=${base_image_arch:-x86_64}
        case ${base_image_rev} in
            17|18|19)
                base_image_name="F${base_image_rev}-${base_image_arch}-cfntools"
            ;;
            20)
                base_image_name='Fedora-x86_64-20-20140618-sda'
            ;;
            *)
                echo "Base image revision '${base_image_rev}' is not supported"
                exit 1
            ;;
        esac
        instance_name="fedora-${base_image_rev}-${base_image_arch}-murano"
        instance_name='cloud-fedora-v3'
    ;;
    'ubuntu')
        base_image_rev=${base_image_rev:-12.04}
        base_image_arch=${base_image_arch:-amd64}
        case ${base_image_rev} in
            12.04)
                base_image_name='ubuntu-12.04-server-cloudimg-amd64-disk1'
            ;;
            *)
                echo "Base image revision '${base_image_rev}' is not supported"
                exit 1
            ;;
        esac
        instance_name="ubuntu-${base_image_rev}-${base_image_arch}-murano"
    ;;
    *)
        die "Base image type '${base_image_type}' is not supported."
    ;;
esac

flavor_name='m1.medium'
network_name='ci-private-network'

base_image_id=$(glance image-list | grep " ${base_image_name} " | get_field 1)
if [ -z "${base_image_id}" ]; then
    die "Image '${base_image_name}' not found"
fi
echo "Image found '${base_image_name}' --> '${base_image_id}'"

flavor_id=$(nova flavor-list | grep " ${flavor_name} " | get_field 1)
if [ -z "${flavor_id}" ]; then
    die "Flavor '${flavor_name}' not found"
fi
echo "Flavor found '${flavor_name}' --> '${flavor_id}'"

network_id=$(nova net-list | grep " ${network_name} " | get_field 1)
if [ -z "${network_id}" ]; then
    die "Network '${network_name}' not found"
fi
echo "Network found '${network_name}' --> '${network_id}'"

user_data_file=$(mktemp)

case ${base_image_type} in
    'fedora')
        cat << EOF > ${user_data_file}
#cloud-config
runcmd:
 - "echo 'root:swordfish' | chpasswd"
 - "yum -y update"
 - "yum -y install which git"
 - "mkdir -p /opt/git"
 - "cd /opt/git && git clone https://github.com/stackforge/murano-agent"
 - "cd /opt/git/murano-agent && git checkout release-0.5"
 - "cd /opt/git/murano-agent && bash setup-centos.sh install"
 - "rm -rf /opt/git"
 - "rm -rf /var/lib/cloud/instance"
 - "rm -rf /var/lib/cloud/instances/*"
 - "rm -rf /var/lib/cloud/sem/*"
 - "test -f /etc/murano/agent.conf && poweroff"
EOF
    ;;
    'ubuntu')
        cat << EOF > ${user_data_file}
#cloud-config
runcmd:
 - "echo 'root:swordfish' | chpasswd"
 - "apt-get update"
 - "apt-get --yes upgrade"
 - "apt-get --yes install git python-babel"
 - "mkdir -p /opt/git"
 - "cd /opt/git && git clone https://github.com/stackforge/murano-agent"
 - "cd /opt/git/murano-agent && git checkout release-0.5"
 - "cd /opt/git/murano-agent && bash setup.sh install"
 - "rm -rf /opt/git"
 - "rm -rf /var/lib/cloud/instance"
 - "rm -rf /var/lib/cloud/instances/*"
 - "rm -rf /var/lib/cloud/sem/*"
 - "test -f /etc/murano/agent.conf && poweroff"
EOF
    ;;
esac

echo "Booting instance ..."
instance_id=$(nova --os-username ci-user --os-tenant-name ci boot \
    --image ${base_image_id} \
    --flavor ${flavor_id} \
    --user-data ${user_data_file} \
    --nic net-id=${network_id} \
    ${instance_name} \
    | grep ' id ' | get_field 2)

if [ -z "${instance_id}" ]; then
    die "Instance '${instance_name}' not found"
fi
echo "Instance started '${instance_name}' --> '${instance_id}'"

timeout=300
instance_status=''
while [ ${timeout} -gt 0 -a "${instance_status}" != 'SHUTOFF' ]; do
    sleep 5
    timeout=$((timeout - 5))
    instance_status=$(nova show ${instance_id} | grep " status " | get_field 2)
    echo "Status of instance ${instance_name}(${instance_id}) is '${instance_status}', ${timeout} sec to abort"
done

if [ "${instance_status}" != 'SHUTOFF' ]; then
    echo "Something went wrong with the instance '${instance_id}'"
    nova delete ${instance_id}
    exit 1
fi

echo "Creating snapshot ..."
nova --os-username ci-user --os-tenant-name ci image-create \
    --show --poll ${instance_id} ${instance_name}

echo "Removing instance ..."
nova delete ${instance_id}

echo "Image with murano agent created."
