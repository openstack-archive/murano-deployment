CirrOS Notes
############


Launching CirrOS in KVM
=======================

* Install KVM on your host

::
	># apt-get install kvm libvirt-bin
..

* Download CirrOS image from launchpad

::
	># wget https://launchpad.net/cirros/trunk/0.3.0/+download/cirros-0.3.0-x86_64-disk.img -O cirros.qcow2
..

* Start CirrOS

::
	># kvm -m 512 -drive file=cirros.qcow2 -net nic,model=virtio -net tap,ifname=tap0 -nographic
..

* To poweroff the system and return to your console type

::
	>$ sudo poweroff
..

Modifying the image
===================

http://alexeytorkhov.blogspot.ru/2009/09/mounting-raw-and-qcow2-vm-disk-images.html

* Get additional files to support muptipart userdat:

::
	>$ cd /tmp
	>$ git clone https://github.com/dmitry-teselkin/cirros.git
..

* Convert Cirros image into RAW format:

::
	>$ cd /tmp/cirros
	>$ wget https://launchpad.net/cirros/trunk/0.3.0/+download/cirros-0.3.0-i386-disk.img
	>$ qemu-img convert -O raw cirros-0.3.0-i386-disk.img cirros-raw.img
..

* Mount the RAW image:

::
	># mkdir /mnt/image
	># losetup /dev/loop0 cirros-raw.img
	># kpartx -a /dev/loop0
	># mount /dev/mapper/loop0p1 /mnt/image
	># cd /mnt/image
..

* Copy new files and apply patche:

::
	># cp /tmp/cirros/config.local.sh /mnt/image/var/lib/cloud
	># patch -d /mnt/image/etc/init.d < /tmp/cirros/cloud-userdata.patch
..

* Do everything else you need.

..warning ::

	Be careful creating links - use only relative paths for link targets!
..

* Unmount the image and convert it back to QCOW:

::
	># cd /tmp/cirros
	># umount /mnt/image
	># kpartx -d /dev/loop0
	># losetup -d /dev/loop0
	># qemu-img convert -O qcow2 cirros-raw.img murano-cirros.qcow2
..

