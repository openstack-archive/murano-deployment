# Devstack integration

**WARNING:** Only **single node** devstack deployment is supported at the moment.

## Overview

This folder contains scripts required to add Murano into Devstack's installation process.

## Typography notes

* ># - root's command prompt
* >$ - user's command prompt, when it doesn't matter what user account is used
* >stack$ - **stack** user's command prompt

## System preparation

1. Create user **stack**

```
># adduser stack
```

2. Add user **stack** to sudoers rules

```
># echo 'stack ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/stack
># chmod 440 /etc/sudoers.d/stack
```

3. Install additional software

	* Ubuntu

	```
	># apt-get install git
	```

	* CentOS

	```
	># yum install git
	```

## Installation

1. Create folders where devstack will install all the files

```
># mkdir -p /opt/stack
># chown stack:stack /opt/stack
```

2. Become user **stack** and cd to home directory

```
># su stack
>stack$ cd
```

3. Clone repositories to home directory

	* Clone devstack repository and checkout **havana** branch

	```
	>stack$ cd
	>stack$ git clone https://github.com/openstack-dev/devstack.git
	>stack$ cd devstack
	>stack$ git checkout stable/havana
	```

	* Clone murano-deployment repository

	```
	>stack$ cd
	>stack$ git clone https://github.com/stackforge/murano-deployment.git
	```

4. Copy required files from **murano-deployment** to **devstack**, then configure **local.conf**. You should set at least one configuration parameter there - **HOST_IP** address.

```
>stack$ cd
>stack$ cp -r murano-deployment/devstack-integration/* devstack/
```

5. **OPTIONAL** Replace *local.conf* with another config file, if you need a different type of installation. Available config files and installation types are:

	* local.conf - **DEFAULT**, single-node all-in-one installation. OpenStack + Murano will be installed on your node together.
	* devbox.local.conf - install Murano only. OpenStack must be installed on another node, and your node will be configured to use it.

6. Edit devstack's configuration file

```
>stack$ vim devstack/local.conf
```

7. From **devstack** directory, lauch **stack.sh**

```
>stack$ ./stack.sh
```

8. Open URL **http://<your host ip>/** in web browser. Login with username **admin** and password **swordfiwh**. Open **Murano** tab and enjoy.

