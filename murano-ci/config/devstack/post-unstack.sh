#!/bin/bash

source openrc admin admin

instances_mount_point=/opt/stack/data/nova/instances

echo "Destroying all KVM instances ..."
for inst in $(sudo virsh list --all | tail -n +3 | awk '{print $2}'); do
    sudo virsh destroy ${inst}
    sudo virsh undefine ${inst}
done

sleep 5

echo "Stopping libvirt-bin ..."
sudo service libvirt-bin stop

sleep 5

echo "Killing the rest KVM processes ..."
sudo killall -9 kvm

sleep 5

echo "Remove route ..."
sudo route del -net ${FIXED_RANGE} dev ${OVS_PHYSICAL_BRIDGE}

echo "Cleaning directory with instances ..."
cd ${instances_mount_point} && sudo rm -rf *
cd /opt/stack

echo "Unmounting SSD drive ..."
if [ -z "$(mount | grep '${instances_mount_point}')" ]; then
    echo "'${instances_mount_point}' is not mounted"
else
    timeout=60
    while [ $timeout -gt 0 ]; do
        sleep 5
        timeout=$((timeout - 5))
        sudo umount ${instances_mount_point} && break
    done
fi

echo "Starting libvirt-bin ..."
sudo service libvirt-bin start

echo "Remove rotated logs ..."
find /opt/stack/log -regex '.*\/screen.*\.log\.[0-9]+' -delete
