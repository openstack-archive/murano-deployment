#!/bin/bash -x

source ./functions.sh

process_config "$CONFIG_FILE" 'export'


GetOSVersion


case $os_VENDOR in
	'Red Hat'|'CentOS')
		#yum install -y
	;;
	'Debian'|'Ubuntu')
		apt-get install --yes zip kvm libvirt-bin virtinst samba
	;;
	*)
	;;
esac


SAMBA_CONF=/etc/samba/smb.conf


mkdir -p $IMAGE_BUILDER_ROOT/share/files
mkdir -p $IMAGE_BUILDER_ROOT/share/images
mkdir -p $IMAGE_BUILDER_ROOT/share/scripts
mkdir -p $IMAGE_BUILDER_ROOT/libvirt/images


iniset $SAMBA_CONF "image-builder-share" "comment" "Image Builder Share"
iniset $SAMBA_CONF "image-builder-share" "path" "$IMAGE_BUILDER_ROOT/share"
iniset $SAMBA_CONF "image-builder-share" "browsable" "yes"
iniset $SAMBA_CONF "image-builder-share" "guest ok" "yes"
iniset $SAMBA_CONF "image-builder-share" "guest account" "nobody"
iniset $SAMBA_CONF "image-builder-share" "read only" "no"
iniset $SAMBA_CONF "image-builder-share" "create mask" "0755"


restart smbd
restart nmbd

