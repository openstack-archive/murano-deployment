How to apply Heat patches
==========================

1. Copy both patches from this dir to the machine with Openstack
   installation.

2. Login to the machine with Openstack installation and gain root
   rights.

3. Go to the location where the heat python package is installed:
   cd /usr/lib/python2.7/dist-package

4. Apply each patch by issuing the following command:
   patch -b -p1 < /path/to/the/patch-file

5. Restart the heat service:
   service heat-engine restart
