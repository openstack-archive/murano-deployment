#!/bin/bash

arch=${1:-i386}
# Image Builder Root
IBR=${IBR:-/tmp/murano-cirros/$arch}
LOOP_DEV=${LOOP_DEV:-loop0}


die() {
	cat "

***** ***** ***** ***** *****
$@
***** ***** ***** ***** *****
"
}


case $arch in
  i386)
	wget -d $IBR -O cirros.img https://launchpad.net/cirros/trunk/0.3.0/+download/cirros-0.3.0-i386-disk.img
	wget -d $IBR -O murano-agent https://www.dropbox.com/sh/zthldcxnp6r4flm/Os1Q9W5ZIx/murano-agent-i386
  ;;
  x86_64)
	wget -d $IBR -O cirros.img https://launchpad.net/cirros/trunk/0.3.0/+download/cirros-0.3.0-x86_64-disk.img
	wget -d $IBR -O murano-agent https://www.dropbox.com/sh/zthldcxnp6r4flm/7dsz0mMg1_/murano-agent-x86_64
  ;;
  *)
	die "Unsupported arch '$arch'"
  ;;
esac


qemu-img convert -O raw $IBR/cirros.img $IBR/cirros.raw

mkdir /mnt/image

[ -d /dev/$LOOP_DEV ] && \
	die "Device /dev/$LOOP_DEV already exists."


losetup /dev/$LOOP_DEV cirros.raw
kpartx -a /dev/$LOOP_DEV
mount /dev/mapper/${LOOP_DEV}p1 /mnt/image


cp ./config.local.sh /mnt/image/var/lib/cloud
patch -d /mnt/image/etc/init.d < ./cloud-userdata.patch

cp $IBR/murano-agent /mnt/image/usr/sbin
chmod 755 /mnt/image/usr/sbin/murano-agent
chown root:root /mnt/image/usr/sbin/murano-agent

cp ./murano-agent.init /mnt/image/etc/init.d/murano-agent
chmod 755 /mnt/image/init.d/murano-agent
chown root:root /mnt/image/init.d/murano-agent
cd /mnt/image/rc3.d && ln -s S99-murano-agent ../init.d/murano-agent


umount /mnt/image
kpartx -d /dev/$LOOP_DEV
losetup -d /dev/$LOOP_DEV


qemu-img convert -O qcow2 $IBR/cirros.raw $IBR/murano-cirros.qcow2

