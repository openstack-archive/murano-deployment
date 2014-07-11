export OS_PASSWORD=
export OS_USERNAME=
export OS_TENANT_NAME=
export OS_AUTH_URL=http://127.0.0.1:5000/v2.0/

VANILLA2_IMAGE_PATH=/home/ubuntu/images/sahara-icehouse-vanilla-2.3.0-ubuntu-13.10.qcow2
VANILLA_IMAGE_PATH=/home/ubuntu/QA/sahara-icehouse-vanilla-1.2.1-ubuntu-13.10.qcow2
HDP_IMAGE_PATH=/home/ubuntu/QA/centos-6_4-64-hdp-1.3-sk
UBUNTU_IMAGE_PATH=/home/ubuntu/images/ubuntu-12.04.qcow2
IDH_IMAGE_PATH=/home/ubuntu/images/centos-6.4-idh.qcow2
#IDH3_IMAGE_PATH=/home/ubuntu/images/centos-6.4-idh-3.qcow2
IDH3_IMAGE_PATH=/home/ubuntu/images/centos_sahara_idh_3.0.2.qcow2
# setup ci tenant and ci users

CI_TENANT_ID=$(keystone tenant-create --name ci --description 'CI tenant' | grep id | awk '{print $4}')
CI_USER_ID=$(keystone user-create --name ci-user --tenant_id $CI_TENANT_ID --pass nova |  grep id | awk '{print $4}')
ADMIN_USER_ID=$(keystone user-list | grep admin | awk '{print $2}' | head -n 1)
MEMBER_ROLE_ID=$(keystone role-list | grep Member | awk '{print $2}')
HEAT_OWNER_ROLE_ID=$(keystone role-list | grep heat_stack_owner | awk '{print $2}')
keystone user-role-add --user $CI_USER_ID --role $MEMBER_ROLE_ID --tenant $CI_TENANT_ID
keystone user-role-add --user $ADMIN_USER_ID --role $MEMBER_ROLE_ID --tenant $CI_TENANT_ID
keystone user-role-add --user $CI_USER_ID --role $HEAT_OWNER_ROLE_ID --tenant $CI_TENANT_ID
keystone user-role-add --user $ADMIN_USER_ID --role $HEAT_OWNER_ROLE_ID --tenant $CI_TENANT_ID
_MEMBER_ROLE_ID=$(keystone role-list | grep _member_ | awk '{print $2}')
keystone user-role-add --user $ADMIN_USER_ID --role $_MEMBER_ROLE_ID --tenant $CI_TENANT_ID
ADMIN_ROLE_ID=$(keystone role-list | grep admin | awk '{print $2}')
keystone user-role-add --user $CI_USER_ID --role $ADMIN_ROLE_ID --tenant $CI_TENANT_ID
keystone user-role-add --user $ADMIN_USER_ID --role $ADMIN_ROLE_ID --tenant $CI_TENANT_ID

# setup quota for ci tenant

nova-manage project quota $CI_TENANT_ID --key ram --value 200000
nova-manage project quota $CI_TENANT_ID --key instances --value 64
nova-manage project quota $CI_TENANT_ID --key cores --value 150
cinder quota-update --volumes 100 $CI_TENANT_ID
cinder quota-update --gigabytes 2000 $CI_TENANT_ID
neutron quota-update --tenant_id $CI_TENANT_ID --port 64
neutron quota-update --tenant_id $CI_TENANT_ID --floatingip 64
# create qa flavor

nova flavor-create --is-public true qa-flavor 20 2048 40 1
nova flavor-delete m1.small
nova flavor-create --is-public true m1.small 2 1024 20 1
# add images for tests

glance image-create --name ubuntu-vanilla-2.3-latest --file $VANILLA2_IMAGE_PATH --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_2.3.0'='True' --property '_sahara_tag_vanilla'='True' --property '_sahara_username'='ubuntu'
glance image-create --name savanna-itests-ci-vanilla-image --file $VANILLA_IMAGE_PATH --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_1.2.1'='True' --property '_sahara_tag_1.1.2'='True' --property '_sahara_tag_vanilla'='True' --property '_sahara_username'='ubuntu'
glance image-create --name savanna-itests-ci-hdp-image-jdk-iptables-off --file $HDP_IMAGE_PATH --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_1.3.2'='True' --property '_sahara_tag_hdp'='True' --property '_sahara_username'='root'
#glance image-create --name intel-noepel --file $IDH_IMAGE_PATH --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_2.5.1'='True' --property '_sahara_tag_idh'='True' --property '_sahara_username'='cloud-user'
#glance image-create --name centos-idh-3.0.2 --file $IDH3_IMAGE_PATH --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_3.0.2'='True' --property '_sahara_tag_idh'='True' --property '_sahara_username'='cloud-user'
glance image-create --name ubuntu-12.04 --location http://cloud-images.ubuntu.com/releases/precise/release/ubuntu-12.04-server-cloudimg-amd64-disk1.img --disk-format qcow2 --container-format bare --is-public=true

# make Neutron networks shared

PRIVATE_NET_ID=$(neutron net-list | grep private | awk '{print $2}')
PUBLIC_NET_ID=$(neutron net-list | grep public | awk '{print $2}')
FORMAT=" --request-format xml"

neutron net-update $FORMAT $PRIVATE_NET_ID --shared True
neutron net-update $FORMAT $PUBLIC_NET_ID --shared True

neutron subnet-update private-subnet --dns_nameservers list=true 8.8.8.8 8.8.4.4

nova --os-username ci-user --os-password nova --os-tenant-name ci keypair-add public-jenkins > /dev/null

bash /home/ubuntu/devstack/sec_gr.sh ci

# setup security groups (nova-network only)

#nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0
#nova secgroup-add-rule default tcp 22 22 0.0.0.0/0

# enable auto assigning of floating ips

#ps -ef | grep -i "nova-network" | grep -v grep | awk '{print $2}' | xargs sudo kill -9
#sudo sed -i -e "s/default_floating_pool = public/&\nauto_assign_floating_ip = True/g" /etc/nova/nova.conf
#screen -dmS nova-network /bin/bash -c "/usr/local/bin/nova-network --config-file /etc/nova/nova.conf || touch /opt/stack/status/stack/n-net.failure"

# switch to ci-user credentials

#export OS_PASSWORD=nova
#export OS_USERNAME=ci-user
#export OS_TENANT_NAME=ci
#export OS_AUTH_URL=http://172.18.168.42:5000/v2.0/

# setup security groups

#nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0
#nova secgroup-add-rule default tcp 22 22 0.0.0.0/0

#setup the default security group for Neutron

CI_TENANT_ID=$(keystone tenant-list | grep $1 | awk '{print $2}' | head -n 1)


for group in $(neutron security-group-list | grep default | awk -F '|' '{ print $2 }')
do
    neutron security-group-show $group | grep $CI_TENANT_ID > /dev/null
    if [ $? == 0 ]
    then
        neutron security-group-rule-create --protocol icmp --direction ingress $group
        neutron security-group-rule-create --protocol icmp --direction egress $group
        neutron security-group-rule-create --protocol tcp --port-range-min 1 --port-range-max 65535 --direction ingress $group
        neutron security-group-rule-create --protocol tcp --port-range-min 1 --port-range-max 65535 --direction egress $group
        neutron security-group-rule-create --protocol udp --port-range-min 1 --port-range-max 65535 --direction egress $group
        neutron security-group-rule-create --protocol udp --port-range-min 1 --port-range-max 65535 --direction ingress $group
        break
    fi
done
