# Devstack integration

**WARNING:** Only **single node** devstack deployment is supported at the moment.

**NOTE:** These scripts were tested with the following devstack branches:

* stable/havana


## Overview

This folder contains scripts required to add Murano into Devstack's installation process.


## Installation

This folder contains scripts and configuration files located in folders similar to Devstack's folder structure.
To use the functionality provided by these script only a few simple steps are required:

1. Locate your Devstack's folder. In case you don't have running Devstack installation, please take a look at [http://devstack.org/](Devstack's) Quick Start guide and other documentation.

2. Copy all the files from this folder to your **devstack** folder. This README file might be skipped.

3. Choose one of two configuration files provided here and rename it to 'local.conf'. In case you already have running Devstack installation with existing configuration file, you have to copy only settings located between "MURANO SETTINGS BLOCK" tags.

4. Run Devstack using './stack.sh' command.

5. Open URL **http://\<your host ip\>/** in web browser. Login with credentials from your configuration file. Open **Murano** tab and enjoy.


## Note on available configurations

Two configuration files are provided as example, targeting the following installation modes:

    * single-node.local.conf - single-node all-in-one installation. OpenStack + Murano will be installed on your node together.
    * devbox.local.conf - install Murano only. OpenStack must be installed on another node, and your node will be configured to use it.