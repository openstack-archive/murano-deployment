HOW-TO build devstack-based lab
###############################

Initial setup
=============

Prepare your hardware, install Ubuntu Server 12.04 x86_64.

As 'root' prepare your host for devstack:

.. code-block:: console

	# apt-get install git
	# mkdir /opt/stack
	# cd /opt/stack
	# git clone https://github.com/openstack-dev/devstack
	# cd /opt/stack/devstack/tools
	# ./create-stack-user.sh
	# echo 'stack:PASSWORD-FOR-USER-STACK' | chpasswd
	# chown -R stack:stack /opt/stack
	# login -f stack
..

As user 'stack', copy murano-ci scripts:

.. code-block:: console

	$ cd /opt/stack
	$ git clone https://github.com/stackforge/murano-deployment
	$ cd /opt/stack/murano-deployment/murano-ci/config/devstack
	$ cp *.sh /opt/stack/devstack/
	$ cp local.conf /opt/stack/devstack/
	$ cd /opt/stack/devstack
..

Open **local.conf** and replace variables, enclosed into % signs to valid values. These are:

* %DMZ_HOST_IP%
* %DMZ_NETWORK_CIDR%
* %DMZ_ROUTER_IP%
* %DMZ_NETWORK_START_IP%
* %DMZ_NETWORK_END_IP%

 When done, start installation:

.. code-block:: console

	$ ./stack.sh
..

When script finishes, execute post installation script:

.. code-block:: console

	$ ./post-stack.sh
..

If you need and image with Murano Agent installed, build it now.

To build Fedora-based image run:

.. code-block:: console


	$ ./build-murano-image.sh
..

To build Ubuntu-based image run:

.. code-block:: console

	$ ./build-murano-image.sh ubuntu
..

After that open Horizon URL in web browser and check that everything works.

Reinstallation
==============

First, stop devstack, and do a little cleanup:

.. code-block:: console

	$ ./unstack.sh
	$ ./post-unstack.sh
..

Then, install devstack again:

.. code-block:: console

	$ ./stack.sh
	$ ./post-stack.sh
..

If nececcary, build images with Murano:

.. code-block:: console

	$ ./build-murano-image.sh
	$ ./build-murano-image.sh ubuntu
..

.. warning::

	After re-installation of devstack you must update network id in nodepool scripts, as it is changed.
	Without that you won't be able to build any image using nodepool on that lab.
..

