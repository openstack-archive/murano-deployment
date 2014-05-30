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
GIT_CMD=$(which git)
GIT_WORKING_DIR=${WORKSPACE:-/opt/git}
WEB_SERVICE_SYSNAME=${WEB_SERVICE_SYSNAME:-httpd}
WEB_SERVICE_USER=${WEB_SERVICE_USER:-apache}
WEB_SERVICE_GROUP=${WEB_SERVICE_GROUP:-apache}

#Functions:
function do_cleanup()
{
    local retval=0
    pip uninstall pycrypto -y
    rm -rf /tmp/keystone-signing-muranoapi || retval=1
    rm -rf /tmp/keystone-signing-muranorepository || retval=1
    if [ $retval -ne 0 ]; then
        echo "\"${FUNCNAME[0]}\" fails!"
    fi
    return $retval
}
#
function prepare_component()
{
    local retval=0
    local git_url="https://git.openstack.org/stackforge/$COMPONENT_NAME"
    local component_clone_dir="${GIT_WORKING_DIR}/${COMPONENT_NAME}"
    if [ -d "$component_clone_dir" ]; then
        rm -rf $component_clone_dir
    fi
    $GIT_CMD clone $git_url $component_clone_dir
    if [ $? -ne 0 ]; then
        echo "Error occured during git clone $git_url $component_clone_dir!"
        return 1
    fi
    cd $component_clone_dir
    bash setup.sh uninstall >> /dev/null
    $GIT_CMD fetch ${ZUUL_URL}/stackforge/${COMPONENT_NAME} ${ZUUL_REF}
    if [ $? -ne 0 ]; then
        echo "Error occured during git fetch ${ZUUL_URL}/stackforge/${COMPONENT_NAME} ${ZUUL_REF}!"
        return 1
    fi
    $GIT_CMD checkout FETCH_HEAD
    if [ $? -ne 0 ]; then
        echo "Error occured during git checkout FETCH_HEAD!"
        return 1
    fi
    bash setup.sh install
    if [ $? -ne 0 ]; then
        echo "Install of the \"$COMPONENT_NAME\" fails!"
        return 1
    fi
    case $COMPONENT_NAME in
        "murano-dashboard")
            case $distro_based_on in
                "debian")
                    WEB_SERVICE_SYSNAME="apache2"
                    WEB_SERVICE_USER="horizon"
                    WEB_SERVICE_GROUP="horizon"
                    ;;
                "redhat")
                    WEB_SERVICE_SYSNAME="httpd"
                    WEB_SERVICE_USER="apache"
                    WEB_SERVICE_GROUP="apache"
                    ;;
            esac
            chown -R $WEB_SERVICE_USER:$WEB_SERVICE_GROUP /var/lib/openstack-dashboard/
            chmod 600 /var/lib/openstack-dashboard/secret_key
            rm -rf /var/cache/murano-dashboard/*
            local horizon_etc_cfg=$(find /etc/openstack-dashboard -name "local_setting*" | head -n 1)
            if [ $? -ne 0 ]; then
                echo "Can't find horizon config under \"/etc/openstack-dashboard...\""
                retval=1
            else
                iniset '' 'DEBUG' 'True' "$horizon_etc_cfg"
                iniset '' 'OPENSTACK_HOST' "\"$OS_HOST\"" "$horizon_etc_cfg"
            fi
            service $WEB_SERVICE_SYSNAME restart || retval=$?
            ;;
        "murano")
            echo "Handling \"$COMPONENT_NAME\" for future use"
            ;;
    esac
    return $retval
}
#
#Starting up:
if [ ! $# -ge 4 ]; then
    echo "Usage: $(basename $0) zuul_ref component_name os_host zuul_url"
    exit 1
else
    readonly ZUUL_REF=$1
    readonly COMPONENT_NAME=$2
    readonly OS_HOST=$3
    readonly ZUUL_URL=$4
fi
do_cleanup || exit $?
get_os || exit $?
prepare_component || exit $?
exit 0
