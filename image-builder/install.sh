#!/bin/bash

apt-get install zip kvm libvirt-bin virtinst samba

mkdir -p /opt/image-builder/share/files
mkdir -p /opt/image-builder/share/images
mkdir -p /opt/image-builder/share/scripts
mkdir -p /opt/image-builder/libvirt/images

if grep -q 'image-builder-share' /etc/samba/smb.conf ; then
    echo "Samba configureation already updated"
else
    echo "Updating samba configuration"
    cat << EOF >> /etc/samba/smb.conf

[image-builder-share]
    comment = Image Builder Share
    path = /opt/samba/image-builder
    browsable = yes
    guest ok = yes
    guest account = nobody
    read only = no
    create mask = 0755
EOF

    restart smbd
    restart nmbd
fi
