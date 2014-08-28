#!/bin/bash

source openrc admin admin

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

sudo route del -net $FIXED_RANGE gw $ROUTER_GW_IP

cd ${instances_mount_point} && sudo rm -rf *
cd /opt/stack

timeout=60
while [ $timeout -gt 0 ]; do
    sleep 5
    timeout=$((timeout - 5))
    sudo umount ${instances_mount_point} && break
done

sudo service libvirt-bin start
