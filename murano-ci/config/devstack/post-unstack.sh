#!/bin/bash

instances_mount_point=/opt/stack/data/nova/instances

for inst in $(sudo virsh list --all | tail -n +3 | awk '{print $2}'); do
    sudo virsh destroy ${inst}
    sudo virsh undefine ${inst}
done

sleep 5

sudo service libvirt-bin stop

sleep 5

sudo killall -9 kvm

sleep 5

cd ${instances_mount_point} && sudo rm -rf *

sleep 5

sudo umount ${instances_mount_point}

sudo service libvirt-bin start

