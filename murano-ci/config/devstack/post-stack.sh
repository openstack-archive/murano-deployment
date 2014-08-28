#!/bin/bash

instances_mount_point=/opt/stack/data/nova/instances

sudo service libvirt-bin stop

sleep 5

cd ${instances_mount_point}/..

tar czvf instances.tar.gz instances

sudo mount -a

tar xzvf instances.tar.gz

sudo service libvirt-bin start

if [ ! -f /etc/cron.daily/devstack ]; then
    sudo sh -c "echo '#!/bin/sh
sudo -u stack bash -c /opt/stack/rotate-devstack-logs.sh' > /etc/cron.daily/devstack"
fi
