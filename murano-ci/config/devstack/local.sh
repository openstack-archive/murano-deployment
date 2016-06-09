#!/bin/bash -x
#

# Keep track of the devstack directory
TOP_DIR=$(cd $(dirname "$0") && pwd)
ADMIN_RCFILE=$TOP_DIR/openrc

#In Devstack Mitaka keystone v3 is needed in order to
#OS client works
export IDENTITY_API_VERSION=3

if [ -e "$ADMIN_RCFILE" ]; then
    source $ADMIN_RCFILE admin admin
else
    echo "Can't source '$ADMIN_RCFILE'!"
    exit 1
fi

# Import common functions
source $TOP_DIR/functions

# Use openrc + stackrc + localrc for settings
source $TOP_DIR/stackrc

source $TOP_DIR/lib/neutron-legacy

#Create monitoring user for Zabbix
#---------------------------------

openstack user create  --project service --password your_password monitoring

# Setup ci tenant and ci users
#-----------------------------
CI_TENANT_ID=$(openstack project create --description 'CI tenant' ci \
 | grep ' id ' | get_field 2)

CI_USER_ID=$(openstack user create  --project $CI_TENANT_ID --password swordfish ci-user \
 | grep ' id ' | get_field 2)

ADMIN_USER_ID=$(openstack user list | grep ' admin' |  get_field 1)

ADMIN_ROLE_ID=$(openstack role list | grep ' admin' | get_field 1)
MEMBER_ROLE_ID=$(openstack role list | grep Member | get_field 1)
_MEMBER_ROLE_ID=$(openstack role list | grep _member_ | get_field 1)
HEAT_STACK_OWNER_ROLE_ID=$(openstack role list \
    | grep heat_stack_owner | get_field 1)

openstack role add \
    --user $CI_USER_ID \
    --project $CI_TENANT_ID \
    $MEMBER_ROLE_ID

openstack role add \
    --user $CI_USER_ID \
    --project $CI_TENANT_ID \
    $HEAT_STACK_OWNER_ROLE_ID

openstack role add \
    --user $ADMIN_USER_ID \
    --project $CI_TENANT_ID \
    $MEMBER_ROLE_ID

openstack role add \
    --user $ADMIN_USER_ID \
    --project $CI_TENANT_ID \
    $_MEMBER_ROLE_ID

openstack role add \
    --user $CI_USER_ID \
    --project $CI_TENANT_ID \
    $ADMIN_ROLE_ID

openstack role add \
    --user $ADMIN_USER_ID \
    --project $CI_TENANT_ID \
    $ADMIN_ROLE_ID
#-----------------------------


# Setup networks and security group rules
#----------------------------------------

CI_SUBNET_CIDR=10.50.10.0/24
CI_SUBNET_ALLOCATION_POOL=start=10.50.10.10,end=10.50.10.100
CI_SUBNET_DNS=8.8.8.8

CI_NET_ID=$(openstack network create \
    --project ${CI_TENANT_ID} ci-private-network \
    | grep ' id ' | get_field 2)

CI_SUBNET_ID=$(openstack subnet create \
    --project ${CI_TENANT_ID} \
    --network ${CI_NET_ID} \
    --subnet-range ${CI_SUBNET_CIDR} \
    --allocation-pool ${CI_SUBNET_ALLOCATION_POOL} \
    --dns-nameserver ${CI_SUBNET_DNS} \
    --ip-version 4 ci-private-subnet \
    | grep ' id ' | get_field 2)

CI_ROUTER_ID=$(openstack router create --project ${CI_TENANT_ID} ci-router \
    | grep ' id ' | get_field 2)
EXT_NET_ID=$(openstack network list --external | grep ' public' | get_field 1)

#currently there is no such option in openstack client
neutron router-gateway-set ${CI_ROUTER_ID} ${EXT_NET_ID}

openstack router add subnet ${CI_ROUTER_ID} ${CI_SUBNET_ID}

CI_DEFAULT_SECURITY_GROUP_ID=$(openstack security group list | grep  ${CI_TENANT_ID} \
    | grep ' default ' | get_field 1)

openstack security group rule create \
    --protocol icmp \
    --ingress \
    ${CI_DEFAULT_SECURITY_GROUP_ID}

openstack security group rule create \
    --protocol icmp \
    --egress \
    ${CI_DEFAULT_SECURITY_GROUP_ID}

openstack security group rule create \
    --protocol tcp \
    --dst-port 1:65535 \
    --ingress \
    ${CI_DEFAULT_SECURITY_GROUP_ID}

openstack security group rule create \
    --protocol tcp \
    --dst-port 1:65535 \
    --egress \
    ${CI_DEFAULT_SECURITY_GROUP_ID}

openstack security group rule create \
    --protocol udp \
    --dst-port 1:65535 \
    --ingress \
    ${CI_DEFAULT_SECURITY_GROUP_ID}

openstack security group rule create \
    --protocol udp \
    --dst-port 1:65535 \
    --egress \
    ${CI_DEFAULT_SECURITY_GROUP_ID}

MURANO_ROUTER_ID=$(openstack router create --project ${CI_TENANT_ID} murano-default-router \
    | grep ' id ' | get_field 2)

neutron router-gateway-set ${MURANO_ROUTER_ID} ${EXT_NET_ID}

#----------------------------------------

# Create nano flavor if not present
if [[ -z $(openstack flavor list | grep m1.nano) ]]; then
     openstack flavor create --ram 64 --vcpus 1 m1.nano
fi

# Create micro flavor if not present
if [[ -z $(openstack flavor list | grep m1.micro) ]]; then
     openstack flavor create --ram 128 --vcpus 1 m1.micro
fi

# Create heat flavor if not present
if [[ -z $(openstack flavor list | grep m1.heat) ]]; then
     openstack flavor create --ram 512 --vcpus 1 m1.heat
fi

# Create tiny flavor if not present
if [[ -z $(openstack flavor list | grep m1.tiny) ]]; then
     openstack flavor create --ram 512 --vcpus 1 --disk 1 m1.tiny
fi

# Create small flavor if not present
if [[ -z $(openstack flavor list | grep m1.small) ]]; then
     openstack flavor create --ram 2048 --vcpus 1 --disk 20 m1.small
fi

# Create medium flavor if not present
if [[ -z $(openstack flavor list | grep m1.medium) ]]; then
     openstack flavor create --ram 4096 --vcpus 2 --disk 40 m1.medium
fi

# Create large flavor if not present
if [[ -z $(openstack flavor list | grep m1.large) ]]; then
     openstack flavor create --ram 8192 --vcpus 4 --disk 80 m1.large
fi

# Create xlarge flavor if not present
if [[ -z $(openstack flavor list | grep m1.xlarge) ]]; then
     openstack flavor create --ram 16384 --vcpus 8 --disk 160 m1.xlarge
fi

# Update user quotas
#-------------------
openstack quota set \
    --instances 20 \
    --cores 40 \
    --secgroups 20 \
    --subnets 20 \
    --routers 20 \
    ${CI_TENANT_ID}

#-------------------


# Network re-setup
#-----------------
OVS_PHYSICAL_BRIDGE=br0
OVS_BR_EX=br-ex
sudo ip link add patch-in type veth peer name patch-out
sudo ip link set up dev patch-in
sudo ip link set up dev patch-out
sudo ovs-vsctl list-ports $OVS_PHYSICAL_BRIDGE | grep -q patch-in \
    || sudo ovs-vsctl add-port $OVS_PHYSICAL_BRIDGE patch-in
sudo ovs-vsctl list-ports $OVS_BR_EX | grep -q patch-out \
    || sudo ovs-vsctl add-port $OVS_BR_EX patch-out
#-----------------

#Configure DNS for murano environments
#-------------------------------------

MURANO_ENV_DNS='8.8.8.8,8.8.4.4'

if is_service_enabled q-dhcp; then
    stop_process q-dhcp
    pid=$(ps aux | awk '/[d]nsmasq.+interface=(tap|ns-)/ { print $2 }')
    [ ! -z "$pid" ] && sudo kill -9 $pid
    iniset $Q_DHCP_CONF_FILE DEFAULT dnsmasq_dns_servers $MURANO_ENV_DNS
    run_process q-dhcp "$AGENT_DHCP_BINARY --config-file $NEUTRON_CONF --config-file=$Q_DHCP_CONF_FILE"
fi

# Configure RabbitMQ
#-------------------
RABBIT_USER=${RABBIT_USER:-muranouser}
RABBIT_PASSWD=${RABBIT_PASSWD:-murano}
RABBIT_VHOST=${RABBIT_VHOST:-muranovhost}

RMQ_PLUG=$(dpkg-query -L rabbitmq-server | grep "bin/rabbitmq-plugins" | tail -n1)
if [[ -z "$(sudo $RMQ_PLUG list -e | grep rabbitmq_management)" ]]; then
    echo " * Enabling RabbitMQ management plugin"
    sudo $RMQ_PLUG enable rabbitmq_management
    sudo service rabbitmq-server restart
fi

if [[ -z "$(sudo rabbitmqctl list_users | grep murano)" ]]; then
    echo " * Adding user account settings for \"$RABBIT_USER\" ..."
    sudo rabbitmqctl add_user $RABBIT_USER $RABBIT_PASSWD
    sudo rabbitmqctl set_user_tags $RABBIT_USER administrator
    sudo rabbitmqctl add_vhost $RABBIT_VHOST
    sudo rabbitmqctl set_permissions -p $RABBIT_VHOST $RABBIT_USER ".*" ".*" ".*"
else
    echo " * User \"$RABBIT_USER\" already exists."
fi
#-------------------
