#!/bin/bash
#    Copyright (c) 2014 Mirantis, Inc.
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
CI_ROOT_DIR=$(cd $(dirname "$0") && cd .. && pwd)
#Include of the common functions library file:
INC_FILE="${CI_ROOT_DIR}/scripts/common.inc"
if [ -f "$INC_FILE" ]; then
    source "$INC_FILE"
else
    echo "\"$INC_FILE\" - file not found, exiting!"
    exit 1
fi
#Basic parameters:
DAEMON_USER="murano"
DAEMON_GROUP="murano"
DAEMON_CONF="/etc/murano/murano.conf"
MANAGE_CMD=$(which murano-manage)
MANAGE_DB_CMD=$(which murano-db-manage)
#Set up this variable if necessary like RUN_DB_SYNC=true configure_api.sh param0 paramN
RUN_DB_SYNC=${RUN_DB_SYNC:-false}
#Functions:
function check_prerequisites()
{
    local retval=0
    if [ ! -f "$DAEMON_CONF" ]; then
        echo "$DAEMON_CONF not found!${warn_message}"
        retval=1
    fi
    getent group $DAEMON_GROUP > /dev/null
    if [ $? -ne 0 ]; then
        echo "System group $DAEMON_GROUP not found!"
        retval=1
    fi
    getent passwd $daemonuser > /dev/null
    if [ $? -ne 0 ]; then
        echo "System user $DAEMON_USER not found!"
        retval=1
    fi
    if [ $(sudo find /etc/init.d/ -name "murano-*" | wc -l) -ne 2 ]; then
        echo "Check that /etc/init.d contains of SysV init scripts named \"murano-api\" and \"murano-engine\"!"
        retval=1
    fi
    if [ ! -f "$MANAGE_CMD" ]; then
        echo "murano-manage not found!"
        retval=1
    fi
    return $retval
}

function configure_api()
{
    local retval=0

    iniset 'DEFAULT' 'amqp_auto_delete' "false" "$DAEMON_CONF"
    iniset 'DEFAULT' 'amqp_durable_queues' "false" "$DAEMON_CONF"
    iniset 'DEFAULT' 'amqp_auto_delete' "false" "$DAEMON_CONF"
    iniset 'DEFAULT' 'rabbit_retry_interval' "1" "$DAEMON_CONF"
    iniset 'DEFAULT' 'rabbit_retry_backoff' "2" "$DAEMON_CONF"
    iniset 'DEFAULT' 'rabbit_max_retries' "0" "$DAEMON_CONF"
    iniset 'DEFAULT' 'rabbit_ha_queues' "false" "$DAEMON_CONF"
    iniset 'DEFAULT' 'rabbit_max_retries' "0" "$DAEMON_CONF"
    iniset 'DEFAULT' 'rabbit_virtual_host' "$RMQ_VHOST" "$DAEMON_CONF"
    iniset 'DEFAULT' 'rabbit_password' "$RMQ_PASSWD" "$DAEMON_CONF"
    iniset 'DEFAULT' 'rabbit_userid' "$RMQ_USER" "$DAEMON_CONF"
    iniset 'DEFAULT' 'rabbit_use_ssl' "$RMQ_SSL" "$DAEMON_CONF"
    iniset 'DEFAULT' 'rabbit_port' "$RMQ_PORT" "$DAEMON_CONF"
    iniset 'DEFAULT' 'rabbit_host' "$RMQ_HOST" "$DAEMON_CONF"

    iniset 'keystone_authtoken' 'auth_host' "$AUTH_HOST" "$DAEMON_CONF"
    iniset 'keystone_authtoken' 'auth_protocol' "http" "$DAEMON_CONF"

    iniset 'keystone' 'auth_url' "$(shield_slashes http://${AUTH_HOST}:5000/v3)" "$DAEMON_CONF"

    iniset 'rabbitmq' 'virtual_host' "$RMQ_VHOST" "$DAEMON_CONF"
    iniset 'rabbitmq' 'password' "$RMQ_PASSWD" "$DAEMON_CONF"
    iniset 'rabbitmq' 'login' "$RMQ_USER" "$DAEMON_CONF"
    iniset 'rabbitmq' 'port' "$RMQ_PORT" "$DAEMON_CONF"
    iniset 'rabbitmq' 'host' "$RMQ_HOST" "$DAEMON_CONF"

    return $retval
}
#Staring up:
if [ ! $# -ge 6 ]; then
    echo "Usage: $(basename $0) rabbitmq_host rabbitmq_port rabbitmq_usessl rabbitmq_userid rabbitmq_vhost auth_host"
    exit 1
else
    readonly RMQ_HOST=$1
    readonly RMQ_PORT=$2
    readonly RMQ_SSL=$3
    readonly RMQ_USER=$4
    readonly RMQ_PASSWD="swordfish"
    readonly RMQ_VHOST=$5
    readonly AUTH_HOST=$6
fi
check_prerequisites || exit $?
configure_api || exit $?
if [ "$RUN_DB_SYNC" == true ]; then
    su -c "$MANAGE_DB_CMD --config-file $DAEMON_CONF upgrade" -s /bin/bash $DAEMON_USER
    if [ $? -ne 0 ]; then
        echo "\"$MANAGE_DB_CMD --config-file $DAEMON_CONF upgrade\" fails!"
        exit 1
    fi
fi
service murano-api restart || exit $?
service murano-engine restart || exit $?
exit 0
