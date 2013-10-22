#!/bin/bash
#    Copyright (c) 2013 Mirantis, Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.
#
#    Ubuntu script.

# Keep track of the devstack directory
TOP_DIR=$(cd $(dirname "$0") && pwd)

# Import common functions
source $TOP_DIR/functions

# Use openrc + stackrc + localrc for settings
source $TOP_DIR/stackrc

# Destination path for installation ``DEST``
DEST=${DEST:-/opt/stack}
source $TOP_DIR/localrc
# Get OpenStack admin auth
source $TOP_DIR/openrc admin admin

# VARIABLES defenition
# murano api service
MURANO_API_SERVICENAME=murano-api
MURANO_API_REPO=${MURANO_API_REPO:-${GIT_BASE}/stackforge/murano-api.git}
MURANO_API_BRANCH=${MURANO_API_BRANCH:-master}

# murano conductor service
MURANO_CONDUCTOR_SERVICENAME=murano-conductor
MURANO_CONDUCTOR_REPO=${MURANO_CONDUCTOR_REPO:-${GIT_BASE}/stackforge/murano-conductor.git}
MURANO_CONDUCTOR_BRANCH=${MURANO_CONDUCTOR_BRANCH:-master}

# murano dashboard for horizon
MURANO_DASHBOARD_SERVICENAME=murano-dashboard
MURANO_DASHBOARD_REPO=${MURANO_DASHBOARD_REPO:-${GIT_BASE}/stackforge/murano-dashboard.git}
MURANO_DASHBOARD_BRANCH=${MURANO_DASHBOARD_BRANCH:-master}

# python-muranoclient
PYTHON_MURANOCLIENT_SERVICENAME=python-muranoclient
PYTHON_MURANOCLIENT_REPO=${PYTHON_MURANOCLIENT_REPO:-${GIT_BASE}/stackforge/python-muranoclient.git}
PYTHON_MURANOCLIENT_BRANCH=${PYTHON_MURANOCLIENT_BRANCH:-master}

# OPTIONAL HEAT-HORIZON
HEAT_HORIZON_SERVICENAME=heat-horizon
HEAT_HORIZON_REPO=${HEAT_HORIZON_REPO:-${GIT_BASE}/steveb/heat-horizon.git}
HEAT_HORIZON_BRANCH=${HEAT_HORIZON_BRANCH:-master}

# set rabbitMQ murano  credentials
RABBIT_USER=${RABBIT_USER:-murano}
RABBIT_PASSWD=${RABBIT_PASSWD:-murano}
RABBIT_VHOST=${RABBIT_VHOST:-murano}
RABBIT_WWW_ENABLED=${RABBIT_WWW_ENABLED:-True}

# Functions

function run_shell_setup {
if [[ -f "$1" ]]; then
        echo " * Setting up executable bit for $1"
        sudo chmod 755 $1
        sudo $@
else
        echo " * File $1 not found!"
        exit 1
fi
}
# Configuring murano-api
function configure_murano-api {
        MURANO_API_CONF_DIR=/etc/murano-api
        sudo chown -R $STACK_USER:$STACK_USER $MURANO_API_CONF_DIR
	sudo rm -f $MURANO_API_CONF_DIR/murano.sqlite
	sudo rm -f $MURANO_API_CONF_DIR/murano-api.conf
        sudo cp -f $MURANO_API_CONF_DIR/murano-api.conf.sample $MURANO_API_CONF_DIR/murano-api.conf
        MURANO_API_CONF=$MURANO_API_CONF_DIR/murano-api.conf
	sudo rm -f $MURANO_API_CONF_DIR/murano-api-paste.ini
        sudo cp -f $MURANO_API_CONF_DIR/murano-api-paste.ini.sample $MURANO_API_CONF_DIR/murano-api-paste.ini
        MURANO_API_PASTE_CONF=$MURANO_API_CONF_DIR/murano-api-paste.ini
        # Setting API
        iniset $MURANO_API_CONF DEFAULT verbose True
        iniset $MURANO_API_CONF DEFAULT debug True
        iniset $MURANO_API_CONF DEFAULT bind_host 0.0.0.0
        iniset $MURANO_API_CONF DEFAULT bind_port 8082
        iniset $MURANO_API_CONF DEFAULT log_file /var/log/murano-api.log
        iniset $MURANO_API_CONF DEFAULT sql_connection  sqlite://$MURANO_API_CONF_DIR/murano.sqlite
        iniset $MURANO_API_CONF rabbitmq host $HOST_IP
        iniset $MURANO_API_CONF rabbitmq port 5672
        iniset $MURANO_API_CONF rabbitmq virtual_host $RABBIT_VHOST
        iniset $MURANO_API_CONF rabbitmq login $RABBIT_USER
        iniset $MURANO_API_CONF rabbitmq password $RABBIT_PASSWD
        # Setting paste
        iniset  $MURANO_API_PASTE_CONF filter:authtoken admin_tenant_name admin 
        iniset  $MURANO_API_PASTE_CONF filter:authtoken auth_host $HOST_IP 
        iniset  $MURANO_API_PASTE_CONF filter:authtoken auth_port 35357
        iniset  $MURANO_API_PASTE_CONF filter:authtoken auth_protocol http
        iniset  $MURANO_API_PASTE_CONF filter:authtoken admin_user admin
        iniset  $MURANO_API_PASTE_CONF filter:authtoken admin_password $SERVICE_PASSWORD
        iniset  $MURANO_API_PASTE_CONF filter:authtoken signing_dir /tmp/keystone-signing-muranoapi
	# Register in Keystone
	m_uuid=$(keystone service-create --name muranoapi --type murano --description "Murano-Api Service" | grep id | awk '{print $4}')
	m_url=http://$HOST_IP:8082
	m_region=RegionOne
	keystone endpoint-create --region $m_region --service-id $m_uuid --publicurl $m_url --internalurl $m_url --adminurl $m_url
}
# Configuring murano-conductor
function configure_murano-conductor {
	MURANO_CONDUCTOR_CONF_DIR=/etc/murano-conductor
	sudo chown -R $STACK_USER:$STACK_USER $MURANO_CONDUCTOR_CONF_DIR
	sudo rm -f $MURANO_CONDUCTOR_CONF_DIR/conductor.conf
	sudo cp -f $MURANO_CONDUCTOR_CONF_DIR/conductor.conf.sample $MURANO_CONDUCTOR_CONF_DIR/conductor.conf
	MURANO_CONDUCTOR_CONF=$MURANO_CONDUCTOR_CONF_DIR/conductor.conf
	sudo rm -f $MURANO_CONDUCTOR_CONF_DIR/conductor-paste.ini
        sudo cp -f $MURANO_CONDUCTOR_CONF_DIR/conductor-paste.ini.sample $MURANO_CONDUCTOR_CONF_DIR/conductor-paste.ini
	MURANO_CONDUCTOR_PASTE_CONF=$MURANO_CONDUCTOR_CONF_DIR/conductor-paste.ini
	# Setting CONDUCTOR
	iniset $MURANO_CONDUCTOR_CONF DEFAULT verbose True
	iniset $MURANO_CONDUCTOR_CONF DEFAULT debug True
	iniset $MURANO_CONDUCTOR_CONF DEFAULT log_file /var/log/murano-conductor.log
	iniset $MURANO_CONDUCTOR_CONF DEFAULT data_dir /etc/murano-conductor
	iniset $MURANO_CONDUCTOR_CONF heat auth_url http://$HOST_IP:5000/v2.0
	iniset $MURANO_CONDUCTOR_CONF rabbitmq host $HOST_IP
        iniset $MURANO_CONDUCTOR_CONF rabbitmq port 5672
        iniset $MURANO_CONDUCTOR_CONF rabbitmq virtual_host $RABBIT_VHOST
        iniset $MURANO_CONDUCTOR_CONF rabbitmq login $RABBIT_USER
        iniset $MURANO_CONDUCTOR_CONF rabbitmq password $RABBIT_PASSWD
	# Setting paste
}
# Add murano-dashboard into HORIZON
source $TOP_DIR/lib/horizon
HORIZON_CONF=$HORIZON_DIR/openstack_dashboard/settings.py
function modify_horizon_config {
    if [[ -f $1 ]]; then
    lines=$(sed -ne '/^#START_MURANO_DASHBOARD/,/^#END_MURANO_DASHBOARD/ =' $1)
    if [ -n "$lines" ]; then
        echo " * $1 already has our data, you can change it manualy and restart apache2 service"
    else
        cat >> $1 << "EOF"
#START_MURANO_DASHBOARD
from muranoclient.common import exceptions as muranoclient
RECOVERABLE_EXC = (muranoclient.HTTPException,
                   muranoclient.CommunicationError,
                   muranoclient.Forbidden)
EXTENDED_RECOVERABLE_EXCEPTIONS = tuple(
    exceptions.RECOVERABLE + RECOVERABLE_EXC)
NOT_FOUND_EXC = (muranoclient.HTTPNotFound, muranoclient.EndpointNotFound)
EXTENDED_NOT_FOUND_EXCEPTIONS = tuple(exceptions.NOT_FOUND + NOT_FOUND_EXC)
UNAUTHORIZED_EXC = (muranoclient.HTTPUnauthorized, )
EXTENDED_UNAUTHORIZED_EXCEPTIONS = tuple(exceptions.UNAUTHORIZED + UNAUTHORIZED_EXC)
HORIZON_CONFIG['exceptions']['recoverable'] = EXTENDED_RECOVERABLE_EXCEPTIONS
HORIZON_CONFIG['exceptions']['not_found'] = EXTENDED_NOT_FOUND_EXCEPTIONS
HORIZON_CONFIG['exceptions']['unauthorized'] = EXTENDED_UNAUTHORIZED_EXCEPTIONS
HORIZON_CONFIG['dashboards'] += ('murano',)
HORIZON_CONFIG['default_dashboard'] = 'murano'
HORIZON_CONFIG['user_home'] = 'muranodashboard.views.get_user_home'
INSTALLED_APPS += ('muranodashboard',)
#END_MURANO_DASHBOARD
EOF
    fi
    else
        echo " * File $1 not found!"
        exit 1
    fi
}
# Add optional component
function modify_horizon_config_4_heat_horizon {
    if [[ -f $1 ]]; then
    lines=$(sed -ne '/^#START_HEAT-HORIZON/,/^#END_HEAT-HORIZON/ =' $1)
    if [ -n "$lines" ]; then
    echo " * $1 already has data about HEAT-HORIZON, you can change it manualy and restart apache2 service"
    else
    cat >> $1 << "EOF"
#START_HEAT-HORIZON
HORIZON_CONFIG['dashboards'] += ('thermal',)
INSTALLED_APPS += ('thermal',)
#END_HEAT-HORIZON
EOF
    fi
else
        echo "File $1 not found!"
        exit 1
fi
}
# Enable web management for rabbitMQ
function enable_rabbit_www {
	# Check that RABBIT_SBIN value right and exists !!!
	RABBIT_SBIN=/usr/lib/rabbitmq/lib/rabbitmq_server-2.7.1/sbin
	if [[ -z "$(sudo $RABBIT_SBIN/rabbitmq-plugins list -e | grep rabbitmq_management)" ]] ; then
		echo " * Enabling RabbitMQ management plugin"
		sudo $RABBIT_SBIN/rabbitmq-plugins enable rabbitmq_management
		echo " * Restarting RabbitMQ ..."
		restart_service rabbitmq-server
	else
		echo " * RabbitMQ management plugin already enabled."
	fi
}
# Add murano credentials to rabbitMQ
function configure_rabbitmq {
	echo " * Setting up RabbitMQ..."
	# wait until service brings up and start responding
	MAX_RETR=6
	SLEEP=10
	FAIL=1
	echo " * Waiting for rabbitMQ service ..."
	for _seq in $(seq $MAX_RETR)
	do
		sudo rabbitmqctl status
		if [ $? -ne 0 ]; then
			sleep $SLEEP
		else
			if [[ "$RABBIT_WWW_ENABLED" = "True" ]]; then
                                enable_rabbit_www
                        fi
			sleep 5
			if [[ -z "$(sudo rabbitmqctl list_users | grep murano)" ]]; then
				echo " * Adding user account settings for \"$RABBIT_USER\" ..."
				sudo rabbitmqctl add_user $RABBIT_USER $RABBIT_PASSWD
				sudo rabbitmqctl set_user_tags $RABBIT_USER administrator
				sudo rabbitmqctl add_vhost $RABBIT_VHOST
				sudo rabbitmqctl set_permissions -p $RABBIT_VHOST $RABBIT_USER ".*" ".*" ".*"
			else
				echo " * User \"$RABBIT_USER\" already exists."
			fi	
			FAIL=0
			break
		fi
	done
	if [ $FAIL -ne 0 ]; then
		echo << "EOF"
Something goes wrong with rabbitMQ, try run next lines manualy:
sudo rabbitmqctl add_user $RABBIT_USER $RABBIT_PASSWD
sudo rabbitmqctl set_user_tags $RABBIT_USER administrator
sudo rabbitmqctl add_vhost $RABBIT_VHOST
sudo rabbitmqctl set_permissions -p $RABBIT_VHOST $RABBIT_USER ".*" ".*" ".*"
EOF
	exit 1
	fi
}
# Replace nova flavours
function replace_nova_flavors {
	echo " * Removing nova flavors ..."
	for id in $(nova flavor-list | awk '$2 ~ /[[:digit:]]/ {print $2}') ; do
	    echo " * Removing flavor '$id'"
	    nova flavor-delete $id
	done
	echo " * Creating new flavors ..."
	nova flavor-create m1.small  auto 768  40 1
	nova flavor-create m1.medium auto 1024 40 1
	nova flavor-create m1.large  auto 1280 40 2
}
# Create security group rules
function add_nova_secgroups {
	echo " * Creating security group rules ..."
        sleep 2
        nova secgroup-add-rule default tcp 22 22 0.0.0.0/0
        sleep 2
        nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0
        sleep 2
}
# Add Murano key
function add_nova_keys {
	if [[ -z "$(nova keypair-list | grep murano_)" ]] ; then
	    echo " * Creating keypair 'murano_*' ..."
            sleep 5
	    nova keypair-add murano_key
            sleep 2
            nova keypair-add murano_lb_key
	else
	    echo " * Keypair 'murano_*' already exists"
	fi
}

# Main workflow
replace_nova_flavors
add_nova_secgroups
add_nova_keys
git_clone $MURANO_API_REPO $DEST/$MURANO_API_SERVICENAME $MURANO_API_BRANCH
run_shell_setup $DEST/$MURANO_API_SERVICENAME/setup.sh install
git_clone $MURANO_CONDUCTOR_REPO $DEST/$MURANO_CONDUCTOR_SERVICENAME $MURANO_CONDUCTOR_BRANCH
run_shell_setup $DEST/$MURANO_CONDUCTOR_SERVICENAME/setup.sh install
git_clone $PYTHON_MURANOCLIENT_REPO $DEST/$PYTHON_MURANOCLIENT_SERVICENAME $PYTHON_MURANOCLIENT_BRANCH
setup_develop $DEST/$PYTHON_MURANOCLIENT_SERVICENAME
git_clone $MURANO_DASHBOARD_REPO $DEST/$MURANO_DASHBOARD_SERVICENAME $MURANO_DASHBOARD_BRANCH
setup_develop $DEST/$MURANO_DASHBOARD_SERVICENAME
# OPTIONAL componet
git_clone $HEAT_HORIZON_REPO $DEST/$HEAT_HORIZON_SERVICENAME $HEAT_HORIZON_BRANCH
setup_develop $DEST/$HEAT_HORIZON_SERVICENAME
#
configure_murano-api
configure_rabbitmq
restart_service $MURANO_API_SERVICENAME
configure_murano-conductor
restart_service $MURANO_CONDUCTOR_SERVICENAME
modify_horizon_config $HORIZON_CONF
# Optional component
modify_horizon_config_4_heat_horizon $HORIZON_CONF
#
restart_service apache2
# Other stuff
WIN_IMG_NAME=ws-2012-full
WIN_IMG_SRC=/home/user/ws-2012-full.qcow2
if [[ -f "$WIN_IMG_SRC" ]]; then
    echo " * Importing precreated Windows 2012  image..."
    glance image-create --name "$WIN_IMG_NAME" --is-public true --container-format ovf --disk-format qcow2 < $WIN_IMG_SRC
fi


