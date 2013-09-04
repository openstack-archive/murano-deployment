Murano Getting Started
======================

This folder contains files mentioned in Murano Getting Started guide.

Murano Vagrant Box
==================

This repo contains a few files that are required to build a Murano Devbox using Vagrant.

Required step are quite simple:

Prepare Environment
-------------------

Ubuntu
------

- Install *VirtualBox*:

::

    apt-get install virtualbox


- Install *VirtualBox Extension Pack*. You can find the appropriate version in [VirtualBox Downloads](https://www.virtualbox.org/wiki/Downloads)

- Install *Vagrant*:

::

    apt-get install vagrant --no-install-recommends


- Upgrade *Vagrant*:

    - download latest Vagrant package from [official download site](http://downloads.vagrantup.com/). Example below uses version 1.2.7 for x64 .deb system:

::

    wget http://files.vagrantup.com/packages/7ec0ee1d00a916f80b109a298bab08e391945243/vagrant_1.2.7_x86_64.deb


    - upgrade the existsing installation:

::

    dpkg --install vagrant_1.2.7_x86_64.deb


Launch The Box
--------------

- This repository is already fetched somewhere on your machine, I suppose. If not - please clone it now.

- Change directory to cloned repository folder.

- **IMPORTANT STEP:** Edit the *lab-binding.rc* file.

- Launch the box:

::

    ./launch-the-box.sh


- The script will do the following:

    - Download the box.
    - Add the box into vagrant.

- Vagrant will do the rest:

    - Start the box.
    - Download and install *Murano* components.

- When everything is done open the [http://127.0.0.1:8080/horizon](http://127.0.0.1:8080/horizon) link.



SEE ALSO
========
* `Murano <http://murano.mirantis.com>`__

