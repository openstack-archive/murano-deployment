#!/bin/bash -xe

sudo su - jenkins -c "echo '
OPENSTACK_HOST=${OPENSTACK_HOST}
APT_PROXY_HOST=${APT_PROXY_HOST}
RABBITMQ_MGMT_PORT=15672
RABBITMQ_URL=${OPENSTACK_HOST}
RABBITMQ_HOST=${OPENSTACK_HOST}
RABBITMQ_PORT=5672
ADMIN_USERNAME=ci-user
ADMIN_PASSWORD=swordfish
ADMIN_TENANT=ci
KEYSTONE_URL=${OPENSTACK_HOST}
LINUX_IMAGE=cloud-fedora-v3
' > /home/jenkins/credentials"

if [ -n "${JENKINS_PUBLIC_KEY}" ]; then
    sudo su - jenkins -c "echo '${JENKINS_PUBLIC_KEY}' >> /home/jenkins/.ssh/authorized_keys.bak"
fi