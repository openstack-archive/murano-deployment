DevStack Scripts
================

A bunch of scripts that help to deploy DevStack in a lab environment.

Single Node and Multi Node deployment modes are supported.

However, these scripts require careful configuration before being applied to the system.

Quick Start
===========

As user *root* do the steps below:

* Create folder for cloned repository

::

	mkdir -p /opt/git
	cd /opt/git

* Clone the *murano-deployment* repo

::

	git clone git://github.com/stackforge/murano-deployment.git

* Change directory to cloned repo and execute *install-devstack.sh*

::

	cd murano-deployment/devstack-scripts
	./install-devstack.sh

* Configure devstack's localrc file that will replace one in devstack's folder

::

	vim /etc/devstack-scripts/standalone/$(hostname).devstack.localrc

* Configure devstack-scripts's localrc file

::

	vim /etc/devstack-scripts/$(hostname).devstack-scripts.localrc


As user *stack* run *start-devstack.sh*:

::

	su stack
	cd /opt/git/murano-deployment/devstack-scripts
	./start-devstack.sh


SEE ALSO
========
* `Murano <http://murano.mirantis.com>`__
* `DevStack <http://devstack.org>`__

