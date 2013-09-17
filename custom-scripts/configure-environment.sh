#!/bin/bash

#set -o xtrace
set -o errexit

source ./functions.sh
source ./local.rc


title "Configuring Compute Nodes"
for node_name in $COMPUTE_NODE_LIST ; do
    ssh_script $node_name configure-nwfilter.sh
    ssh_script $node_name configure-ramdrive.sh
done

for node_name in $METADATA_NODE_LIST ; do
    ssh_script $node_name configure-metadata.sh
done

title "Configuring RabbitMQ Nodes"
for node_name in $RABBITMQ_NODE_LIST ; do
    ssh_script $node_name configure-rabbitmq.sh -b \
      $RABBITMQ_LOGIN $RABBITMQ_PASSWORD $RABBITMQ_VHOST
done


rm -rf /opt/openstack | true
mkdir -p /opt/openstack/ssl | true


if [ -n "$PUPPET_HOST" ] ; then
    title "Getting Windows Image"
    scp root@$PUPPET_HOST:/home/murano/ws-2012-std.qcow2 /opt/openstack
    [ -f /opt/openstack/ws-2012-std.qcow2 ] || \
      die "Image '/opt/openstack/ws-2012-std.qcow2' not found."

    title "Getting SSL Certificates"
    scp root@$PUPPET_HOST:/etc/puppet/files/openstack_ssl/* /opt/openstack/ssl
    [ -f /opt/openstack/ssl/cacert.pem ] || \
      die "Image '/opt/openstack/ssl/cacert.pem' not found."

    title "Getting OpenStack Credential File"
    scp root@$PUPPET_HOST:/home/murano/openrc /opt/openstack
    [ -f /opt/openstack/openrc ] || \
      die "Image '/opt/openstack/openrc' not found."

    source /opt/openstack/openrc set

    title "Getting List of Images From Glance"
    glance --insecure image-list

    title "Removing Windows Image"
    glance --insecure image-delete ws-2012-std | true
    echo 'Done.'

    title "Adding New Image Into Glance"
    echo 'This might take a few minutes ...'
    glance --insecure image-create \
      --name ws-2012-std \
      --disk-format qcow2 \
      --container-format bare \
      --file /opt/openstack/ws-2012-std.qcow2 \
      --is-public true \
      --property murano_image_info='{"type":"ws-2012-std","title":"Windows Server 2012 Standard"}'
fi
