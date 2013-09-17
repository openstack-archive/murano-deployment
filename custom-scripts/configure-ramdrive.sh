#!/bin/bash

target_dir=${1:-'/var/lib/nova/instances'}
tmpfs_size=${2:-160G}


echo ''
echo 'Removing running instances'

for name in $(virsh list --name) ; do
    echo ''
    echo "Destroying instance '$name' ..."
    virsh destroy --domain $name
done

parent_dir=$(dirname "$target_dir")
child_dir=$(basename "$target_dir")

old_pwd=$(pwd)

if [ -z "$(mount | grep $target_dir)" ] ; then
    echo ''
    echo "Preparing to mount tmpfs to '$target_dir' ..."

    cd $parent_dir

    echo ''
    echo "Removing cached images from '$target_dir/_base/' ..."
    rm -f $target_dir/_base/*

    if [ -f "$child_dir.tar.gz" ] ; then
        rm -f "$child_dir.tar.gz"
    fi

    tar czvf "$child_dir.tar.gz" "$child_dir"

    mount -t tmpfs -o size=$tmpfs_size tmpfs "$target_dir"

    tar xzvf "$child_dir.tar.gz"
else
    echo ''
    echo "'$target_dir' already mounted."
fi

cd $old_pwd
