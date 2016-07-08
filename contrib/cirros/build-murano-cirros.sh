#!/bin/bash

set -o xtrace
set -o errexit

arch=${1:-i386}
# Image Builder Root
IBR=${IBR:-/tmp/murano-cirros/$arch}
LOOP_DEV=${LOOP_DEV:-loop0}
DEBUG='false'


die() {
	cat "

***** ***** ***** ***** *****
$@
***** ***** ***** ***** *****
"
}

apt-get install kpartx |:

mkdir -p $IBR |:

case $arch in
  i386)
	wget -O $IBR/cirros.img https://launchpad.net/cirros/trunk/0.3.0/+download/cirros-0.3.0-i386-disk.img
	if [ "$DEBUG" = 'true' ] ; then
		wget -O $IBR/murano-agent https://www.dropbox.com/sh/zthldcxnp6r4flm/Os1Q9W5ZIx/murano-agent-i386
	else
		wget -O $IBR/murano-agent https://www.dropbox.com/sh/zthldcxnp6r4flm/Os1Q9W5ZIx/murano-agent-i386
	fi
  ;;
  x86_64)
	wget -O $IBR/cirros.img https://launchpad.net/cirros/trunk/0.3.0/+download/cirros-0.3.0-x86_64-disk.img
	if [ "$DEBUG" = 'true' ] ; then
		wget -O $IBR/murano-agent https://www.dropbox.com/sh/zthldcxnp6r4flm/CAEdNRkJAD/murano-agent-x86_64-debug
	else
		wget -O $IBR/murano-agent https://www.dropbox.com/sh/zthldcxnp6r4flm/7dsz0mMg1_/murano-agent-x86_64
	fi
  ;;
  *)
	die "Unsupported arch '$arch'"
  ;;
esac


qemu-img convert -O raw $IBR/cirros.img $IBR/cirros.raw

mkdir /mnt/image |:

losetup --all | grep -q $LOOP_DEV && \
	die "Device /dev/$LOOP_DEV already exists."


losetup /dev/$LOOP_DEV $IBR/cirros.raw
kpartx -a /dev/$LOOP_DEV
mount /dev/mapper/${LOOP_DEV}p1 /mnt/image


cp ./config.local.sh /mnt/image/var/lib/cloud
patch -d /mnt/image/etc/init.d < ./cloud-userdata.patch

cp $IBR/murano-agent /mnt/image/usr/sbin
chmod 755 /mnt/image/usr/sbin/murano-agent
chown root:root /mnt/image/usr/sbin/murano-agent

cp ./murano-agent.init /mnt/image/etc/init.d/murano-agent
chmod 755 /mnt/image/etc/init.d/murano-agent
chown root:root /mnt/image/etc/init.d/murano-agent
cd /mnt/image/etc/rc3.d && ln -s ../init.d/murano-agent S47-murano-agent

cd $IBR
sleep 5

umount /mnt/image
kpartx -d /dev/$LOOP_DEV
losetup -d /dev/$LOOP_DEV


qemu-img convert -O qcow2 $IBR/cirros.raw $IBR/murano-cirros.qcow2

