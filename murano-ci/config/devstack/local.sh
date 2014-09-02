#!/bin/bash -x
#

# Keep track of the devstack directory
TOP_DIR=$(cd $(dirname "$0") && pwd)
ADMIN_RCFILE=$TOP_DIR/openrc

if [ -e "$ADMIN_RCFILE" ]; then
    source $ADMIN_RCFILE admin admin
else
    echo "Can't source '$ADMIN_RCFILE'!"
    exit 1
fi


# Setup ci tenant and ci users
#-----------------------------
CI_TENANT_ID=$(keystone tenant-create \
    --name ci \
    --description 'CI tenant' \
    | grep ' id ' | get_field 2)
CI_USER_ID=$(keystone user-create \
    --name ci-user \
    --tenant_id $CI_TENANT_ID \
    --pass swordfish \
    | grep ' id ' | get_field 2)

ADMIN_USER_ID=$(keystone user-list | grep admin |  get_field 1)

ADMIN_ROLE_ID=$(keystone role-list | grep admin | get_field 1)
MEMBER_ROLE_ID=$(keystone role-list | grep Member | get_field 1)
_MEMBER_ROLE_ID=$(keystone role-list | grep _member_ | get_field 1)
HEAT_STACK_OWNER_ROLE_ID=$(keystone role-list \
    | grep heat_stack_owner | get_field 1)

keystone user-role-add \
    --user $CI_USER_ID \
    --role $MEMBER_ROLE_ID \
    --tenant $CI_TENANT_ID

keystone user-role-add \
    --user $CI_USER_ID \
    --role $HEAT_STACK_OWNER_ROLE_ID \
    --tenant $CI_TENANT_ID

keystone user-role-add \
    --user $ADMIN_USER_ID \
    --role $MEMBER_ROLE_ID \
    --tenant $CI_TENANT_ID

keystone user-role-add \
    --user $ADMIN_USER_ID \
    --role $_MEMBER_ROLE_ID \
    --tenant $CI_TENANT_ID

keystone user-role-add \
    --user $CI_USER_ID \
    --role $ADMIN_ROLE_ID \
    --tenant $CI_TENANT_ID

keystone user-role-add \
    --user $ADMIN_USER_ID \
    --role $ADMIN_ROLE_ID \
    --tenant $CI_TENANT_ID
#-----------------------------


# Setup networks and security group rules
#----------------------------------------
CI_SUBNET_CIDR=10.50.10.0/24
CI_SUBNET_ALLOCATION_POOL=start=10.50.10.10,end=10.50.10.100
CI_SUBNET_DNS=8.8.8.8
CI_NET_ID=$(neutron net-create \
    --tenant_id ${CI_TENANT_ID} ci-private-network \
    | grep ' id ' | get_field 2)
CI_SUBNET_ID=$(neutron subnet-create \
    --tenant_id ${CI_TENANT_ID} ${CI_NET_ID} ${CI_SUBNET_CIDR} \
    --name ci-private-subnet \
    --allocation-pool ${CI_SUBNET_ALLOCATION_POOL} \
    --dns-nameserver ${CI_SUBNET_DNS} \
    --ip-version 4 \
    | grep ' id ' | get_field 2)
CI_ROUTER_ID=$(neutron router-create --tenant_id ${CI_TENANT_ID} ci-router \
    | grep ' id ' | get_field 2)
EXT_NET_ID=$(neutron net-external-list | grep ' public' | get_field 1)

neutron router-gateway-set ${CI_ROUTER_ID} ${EXT_NET_ID}
neutron router-interface-add ${CI_ROUTER_ID} ${CI_SUBNET_ID}

CI_DEFAULT_SECURITY_GROUP_ID=$(nova --os-tenant-id ${CI_TENANT_ID} secgroup-list \
    | grep ' default ' | get_field 1)

neutron security-group-rule-create \
    --protocol icmp \
    --direction ingress \
    ${CI_DEFAULT_SECURITY_GROUP_ID}

neutron security-group-rule-create \
    --protocol icmp \
    --direction egress \
    ${CI_DEFAULT_SECURITY_GROUP_ID}

neutron security-group-rule-create \
    --protocol tcp \
    --port-range-min 1 \
    --port-range-max 65535 \
    --direction ingress \
    ${CI_DEFAULT_SECURITY_GROUP_ID}

neutron security-group-rule-create \
    --protocol tcp \
    --port-range-min 1 \
    --port-range-max 65535 \
    --direction egress \
    ${CI_DEFAULT_SECURITY_GROUP_ID}

neutron security-group-rule-create \
    --protocol udp \
    --port-range-min 1 \
    --port-range-max 65535 \
    --direction ingress \
    ${CI_DEFAULT_SECURITY_GROUP_ID}

neutron security-group-rule-create \
    --protocol udp \
    --port-range-min 1 \
    --port-range-max 65535 \
    --direction egress \
    ${CI_DEFAULT_SECURITY_GROUP_ID}
#----------------------------------------


# Update user quotas
#-------------------
nova quota-update \
    --instances 20 \
    --cores 40 \
    ${CI_TENANT_ID}

neutron quota-update \
    --tenant-id ${CI_TENANT_ID} \
    --security-group 20 \
    --subnet 20 \
    --router 20
#-------------------


# Network re-setup
#-----------------
OVS_PHYSICAL_BRIDGE=br-eth1
OVS_BR_EX=br-ex
sudo ip addr flush dev $OVS_BR_EX
sudo ip link set up dev $OVS_BR_EX
sudo ip link add patch-in type veth peer name patch-out
sudo ip link set up dev patch-in
sudo ip link set up dev patch-out
sudo ovs-vsctl list-ports $OVS_PHYSICAL_BRIDGE | grep -q patch-in \
    || sudo ovs-vsctl add-port $OVS_PHYSICAL_BRIDGE patch-in
sudo ovs-vsctl list-ports $OVS_BR_EX | grep -q patch-out \
    || sudo ovs-vsctl add-port $OVS_BR_EX patch-out
#-----------------


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

