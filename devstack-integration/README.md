# Devstack integration

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
	># apt-get install git mc
	```

	* CentOS

	```
	># yum install git mc
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
	>stack$ git clone https://githib.com/stackforge/murano-deployment.git
	```

4. Copy required files from **murano-deployment** to **devstack**, then configure **local.conf**. You should set at least one configuration parameter there - **HOST_IP** address.

```
>stack$ cd
>stack$ cp -r murano-deployment/devstack-integration/* devstack/
>stack$ vim devstack/local.conf
```

5. From **devstack** directory, lauch **stack.sh**

```
>stack$ ./stack.sh
```

6. Open URL **http://<your host ip>/** in web browser. Login with username **admin** and password **swordfiwh**. Open **Murano** tab and enjoy.

