DevStack Scripts
================

A bunch of scripts that helps to deploy DevStack in a lab environment.

Single Node and Multi Node deployment modes are supported.

However, these scripts require careful configuration before being applied to the system.

Quick Start
===========

As *root* do the steps below:

* Create group *stack* and user *stack*

::

    groupadd stack
    useradd -g stack -s /bin/bash -m stack

* Alter sudoers config

::

    echo 'stack ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/stack
    chmod 0440 /etc/sudoers.d/stack

* Clone this repo to *stack* home dir

::

    su stack
    cd
    git clone https://github.com/Mirantis/murano-deployment.git
    cd murano-deployment/devstack-scripts

* Check configuration files and start devstack

::

    ./start-devstack.sh standalone


SEE ALSO
========
* `Murano <http://murano.mirantis.com>`__
* `DevStack <http://devstack.org>`__

