#!/bin/bash

instances_mount_point=/opt/stack/data/nova/instances

sudo service libvirt-bin stop

sleep 5

cd ${instances_mount_point}/..

tar czvf instances.tar.gz instances

sudo mount -a

tar xzvf instances.tar.gz

sudo service libvirt-bin start

