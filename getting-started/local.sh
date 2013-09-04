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

# set rabbitMQ murano  credentials
RABBIT_USER=${RABBIT_USER:-muranouser}
RABBIT_PASSWD=${RABBIT_PASSWD:-murano}
RABBIT_VHOST=${RABBIT_VHOST:-muranovhost}
RABBIT_WWW_ENABLED=${RABBIT_WWW_ENABLED:-True}


# Functions

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
    nova secgroup-add-rule default tcp 1 65535 0.0.0.0/0
    sleep 2
    nova secgroup-add-rule default udp 1 65535 0.0.0.0/0
    sleep 2
    nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0
    sleep 2
}

# Add Murano key
function add_nova_keys {
    if [[ -z "$(nova keypair-list | grep murano_)" ]] ; then
        echo " * Creating keypair 'murano_*' ..."
            sleep 5
        nova keypair-add murano_key > ~/.ssh/murano_key.pub
            sleep 2
            nova keypair-add murano-lb-key > ~/.ssh/murano-lb-key.pub
    else
        echo " * Keypair 'murano_*' already exists"
    fi
}

# Main workflow
replace_nova_flavors
add_nova_secgroups
add_nova_keys

configure_rabbitmq

# Restart Apache2
restart_service apache2
