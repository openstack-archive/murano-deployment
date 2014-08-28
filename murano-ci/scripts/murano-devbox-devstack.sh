#!/bin/bash
# Copyright (c) 2014 Mirantis, Inc.
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

# Error trapping first
#---------------------
set -o errexit

function trap_handler() {
    cat << EOF
********************************************************************************
*
*   Got error in "'$3'", line "'$2'", error code "'$1'"
*
********************************************************************************
EOF
}

function exit_handler() {
    mkdir -p $WORKSPACE/artifacts
    echo $BUILD_STATUS_ON_EXIT > $WORKSPACE/artifacts/build_status
    cat << EOF
********************************************************************************
*
*   Exiting script, exit code "'$1'"
*   Build status: $BUILD_STATUS_ON_EXIT
*
********************************************************************************
EOF
    set +o xtrace
    while [ -f ~/keep-vm-alive ]; do
        sleep 5
    done
}

trap 'trap_handler ${?} ${LINENO} ${0}' ERR
trap 'exit_handler ${?}' EXIT
#---------------------


# Enable debug output
#--------------------
PS4='+ [$(date --rfc-3339=seconds)] '
set -o xtrace
#--------------------


CI_ROOT_DIR=$(cd $(dirname "$0") && cd .. && pwd)


# This file is generated by Nodepool while building snapshots
# It contains credentials to access RabbitMQ and an OpenStack lab
source ~/credentials


# Basic parameters
#-----------------
STACK_HOME='/opt/stack'

GIT_BASE=${GIT_BASE:-https://git.openstack.org}
MURANO_REPO=${MURANO_REPO:-${GIT_BASE}/stackforge/murano}
MURANO_BRANCH=${MURANO_BRANCH:-master}
MURANO_DASHBOARD_REPO=${MURANO_DASHBOARD_REPO:-${GIT_BASE}/stackforge/murano-dashboard}
MURANO_DASHBOARD_BRANCH=${MURANO_DASHBOARD_BRANCH:-master}
MURANO_PYTHONCLIENT_REPO=${MURANO_PYTHONCLIENT_REPO:-${GIT_BASE}/stackforge/python-muranoclient}
MURANO_PYTHONCLIENT_BRANCH=${MURANO_PYTHONCLIENT_BRANCH:-master}

GIT_REF=${GIT_REF:-'master'}
GIT_PROJECT=${GIT_PROJECT:-'stackforge/murano'}

PROJECT_NAME=${GIT_PROJECT##*/}

OPENSTACK_HOST=${OPENSTACK_HOST:-$KEYSTONE_URL}

WORKSPACE=$(cd ${WORKSPACE} && pwd)

TZ_STRING='Europe/Moscow'
#-----------------



# Virtual framebuffer settings
#-----------------------------
VFB_DISPLAY_SIZE='1280x1024'
VFB_COLOR_DEPTH=16
VFB_DISPLAY_NUM=22
#-----------------------------



# Functions
#-------------------------------------------------------------------------------
function get_ip_from_iface() {
    local iface_name=$1

    found_ip_address=$(ifconfig ${iface_name} | awk -F ' *|:' '/inet addr/{print $4}')

    if [ $? -ne 0 ] || [ -z "${found_ip_address}" ]; then
        echo "Can't obtain ip address from interface ${iface_name}!"
        return 1
    else
        readonly found_ip_address
    fi
}


function get_floating_ip() {
    sudo apt-get install --yes python-novaclient

    set +o xtrace
    export OS_USERNAME=${ADMIN_USERNAME}
    export OS_PASSWORD=${ADMIN_PASSWORD}
    export OS_TENANT_NAME=${ADMIN_TENANT}
    export OS_AUTH_URL="http://${OPENSTACK_HOST}:5000/v2.0"
    set -o xtrace

    floating_ip_address=$(nova floating-ip-list | grep " ${found_ip_address} " | cut -d ' ' -f 2)

    if [ -z ""${floating_ip_address} ]; then
        exit 1
    fi

    readonly floating_ip_address
}


function prepare_murano_apps() {
    local start_dir=$1
    local clone_dir="${start_dir}/murano-app-incubator"
    local git_url="https://github.com/murano-project/murano-app-incubator"

    cd ${start_dir}

    if [ "${PROJECT_NAME}" == 'murano' ]; then
        git clone ${git_url} ${clone_dir}

        local app
        cd ${clone_dir}
        for app in io.murano.*; do
            if [ -f "${app}/manifest.yaml" ]; then
                make_package ${app}
            fi
        done
    fi
}


function make_package() {
    local path=$1

    if [[ -z "${path}" ]]; then
        echo "No directory name provided."
        return 1
    fi

    if [[ ! -d "${path}" ]]; then
        echo "Folder '${path}' doesn't exist."
        return 1
    fi

    path=${path%/*}

    pushd ${path}

    zip -r "../${path}.zip" *

    popd
}


function git_clone_devstack() {
    # Assuming the script is run from 'jenkins' user

    sudo mkdir -p "${STACK_HOME}"
    sudo chown -R jenkins:jenkins "${STACK_HOME}"
    git clone https://github.com/openstack-dev/devstack ${STACK_HOME}/devstack

    #source ${STACK_HOME}/devstack/functions-common
}


function deploy_devstack() {
    # Assuming the script is run from 'jenkins' user
    local git_dir=/opt/git

    cd "${STACK_HOME}"
    git clone ${MURANO_REPO}

    cd "${STACK_HOME}/murano"
    git fetch ${MURANO_REPO} ${MURANO_BRANCH} && git checkout FETCH_HEAD
    # NOTE: Source path MUST ends with a slash!
    rsync --recursive --exclude README.* "./contrib/devstack/" "${STACK_HOME}/devstack/"
    git checkout master

    cd "${STACK_HOME}/devstack"

    cat << EOF > local.conf
[[local|localrc]]
HOST_IP=${OPENSTACK_HOST}           # IP address of OpenStack lab
ADMIN_PASSWORD=${ADMIN_PASSWORD}    # This value doesn't matter
MYSQL_PASSWORD=swordfish            # Random password for MySQL installation
SERVICE_PASSWORD=${ADMIN_PASSWORD}  # Password of service user
SERVICE_TOKEN=.                     # This value doesn't matter
SERVICE_TENANT_NAME=${ADMIN_TENANT}
MURANO_ADMIN_USER=${ADMIN_USERNAME}
RABBIT_HOST=${floating_ip_address}
RABBIT_PASSWORD=guest
MURANO_RABBIT_VHOST=/
MURANO_REPO=${MURANO_REPO}
MURANO_BRANCH=${MURANO_BRANCH}
MURANO_DASHBOARD_REPO=${MURANO_DASHBOARD_REPO}
MURANO_DASHBOARD_BRANCH=${MURANO_DASHBOARD_BRANCH}
MURANO_PYTHONCLIENT_REPO=${MURANO_PYTHONCLIENT_REPO}
MURANO_PYTHONCLIENT_BRANCH=${MURANO_PYTHONCLIENT_BRANCH}
RECLONE=True
SCREEN_LOGDIR=/opt/stack/log/
LOGFILE=\$SCREEN_LOGDIR/stack.sh.log
ENABLED_SERVICES=
enable_service mysql
enable_service rabbit
enable_service horizon
enable_service murano
enable_service murano-api
enable_service murano-engine
enable_service murano-dashboard
EOF

    sudo ./tools/create-stack-user.sh
    echo 'stack:swordfish' | sudo chpasswd

    sudo chown -R stack:stack "${STACK_HOME}"

    sudo sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    sudo service ssh restart

    sudo su -c "cd ${STACK_HOME}/devstack && ./stack.sh" stack

    # Fix iptables to allow outbound access
    sudo iptables -I INPUT 1 -p tcp --dport 80 -j ACCEPT
}


function start_xvfb_session() {
    if [ "${PROJECT_NAME}" == 'murano' ]; then
        echo "Skipping 'start_xvfb_session' ..."
        return
    fi

    export DISPLAY=:${VFB_DISPLAY_NUM}

    fonts_path="/usr/share/fonts/X11/misc/"
    if [ $distro_based_on == "redhat" ]; then
        fonts_path="/usr/share/X11/fonts/misc/"
    fi

    # Start XVFB session
    sudo Xvfb -fp ${fonts_path} ${DISPLAY} -screen 0 ${VFB_DISPLAY_SIZE}x${VFB_COLOR_DEPTH} &

    # Start VNC server
    sudo apt-get install --yes x11vnc
    x11vnc -bg -forever -nopw -display ${DISPLAY} -ncache 10
    sudo iptables -I INPUT 1 -p tcp --dport 5900 -j ACCEPT

    # Launch window manager
    sudo apt-get install --yes openbox
    exec openbox &
}

function adjust_time_settings(){
    sudo sh -c "echo \"${TZ_STRING}\" > /etc/timezone"
    sudo dpkg-reconfigure -f noninteractive tzdata

    sudo ntpdate -u ru.pool.ntp.org
}
#-------------------------------------------------------------------------------

BUILD_STATUS_ON_EXIT='PREPARATION_FAILED'

# Create flags (files to check VM state)
if [ -f ~/build-started ]; then
    echo 'This VM is from previous tests run, terminating build'
    exit 1
else
    touch ~/build-started
fi

if [ "${KEEP_VM_ALIVE}" == 'true' ]; then
    touch ~/keep-vm-alive
fi


sudo sh -c "echo '127.0.0.1 $(hostname)' >> /etc/hosts"
sudo iptables -F

adjust_time_settings

# Clone devstack first as we will use
# some of its files (functions-common, for example)
git_clone_devstack

get_ip_from_iface eth0

get_floating_ip

cat << EOF
********************************************************************************
*
*   Fixed IP: ${found_ip_address}
*   Floating IP: ${floating_ip_address}
*   Horizon URL: http://${floating_ip_address}
*   SSH connection string: ssh stack@${floating_ip_address} -oPubkeyAuthentication=no
*
********************************************************************************
EOF

BUILD_STATUS_ON_EXIT='DEVSTACK_FAILED'

deploy_devstack

BUILD_STATUS_ON_EXIT='PREPARATION_FAILED'

start_xvfb_session

BUILD_STATUS_ON_EXIT='SUCCESS'

exit 0
