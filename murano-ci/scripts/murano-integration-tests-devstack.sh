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
    echo $BUILD_STATUS_ON_EXIT > $WORKSPACE/artifacts/overall-status.txt
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


# Include of the common functions library file
source "${CI_ROOT_DIR}/scripts/common.inc"

# This file is generated by Nodepool while building snapshots
# It contains credentials to access RabbitMQ and an OpenStack lab
source ~/credentials


# Basic parameters
#-----------------
STACK_HOME='/opt/stack'

ZUUL_URL=${ZUUL_URL:-'https://git.openstack.org'}
ZUUL_REF=${ZUUL_REF:-'master'}
ZUUL_PROJECT=${ZUUL_PROJECT:-'stackforge/murano'}

APP_INCUBATOR_REPO=${APP_INCUBATOR_REPO:-https://github.com/murano-project/murano-app-incubator}
APP_INCUBATOR_BRANCH=${APP_INCUBATOR_BRANCH:-'master'}

PROJECT_NAME=${ZUUL_PROJECT##*/}

APT_PROXY_HOST=${APT_PROXY_HOST:-''}

OPENSTACK_HOST=${OPENSTACK_HOST:-$KEYSTONE_URL}

DO_NOT_COLLECT_ARTIFACTS=${DO_NOT_COLLECT_ARTIFACTS:-false}

WORKSPACE=$(cd $WORKSPACE && pwd)

TZ_STRING='Europe/Moscow'

DISTR_NAME=${DISTR_NAME:-'ubuntu'}

case "${PROJECT_NAME}" in
    'murano')
        PROJECT_DIR="${STACK_HOME}/murano"
        PROJECT_TESTS_DIR="${PROJECT_DIR}/murano/tests/functional"
    ;;
    'murano-dashboard')
        PROJECT_DIR="${STACK_HOME}/murano-dashboard"
        PROJECT_TESTS_DIR="${PROJECT_DIR}/muranodashboard/tests/functional"
    ;;
    'python-muranoclient')
        PROJECT_DIR="${STACK_HOME}/python-muranoclient"
        #PROJECT_TESTS_DIR="${PROJECT_DIR}/muranoclient/tests/functional"
        PROJECT_TESTS_DIR="${STACK_HOME}/murano-dashboard/muranodashboard/tests/functional"
    ;;
    'murano-agent')
        PROJECT_TESTS_DIR="${STACK_HOME}/murano/murano/tests/functional"
        # tests for engine launch on iso with murano-agent
    ;;
    *)
        echo "Project name '$ZUUL_PROJECT' isn't supported yet."
        exit 1
    ;;
esac
#-----------------


# Commands used in script
#------------------------
NOSETESTS_CMD=$(which nosetests)
#------------------------


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

    found_ip_address=$(ifconfig $iface_name | awk -F ' *|:' '/inet addr/{print $4}')

    if [ $? -ne 0 ] || [ -z "$found_ip_address" ]; then
        echo "Can't obtain ip address from interface $iface_name!"
        return 1
    else
        readonly found_ip_address
    fi
}


function get_floating_ip() {
    sudo pip install --upgrade python-novaclient

    export OS_USERNAME=${ADMIN_USERNAME}
    export OS_PASSWORD=${ADMIN_PASSWORD}
    export OS_TENANT_NAME=${ADMIN_TENANT}
    export OS_AUTH_URL="http://${OPENSTACK_HOST}:5000/v2.0"

    floating_ip_address=$(nova floating-ip-list | grep " ${found_ip_address} " | cut -d ' ' -f 2)

    if [ -z ""${floating_ip_address} ]; then
        exit 1
    fi

    readonly floating_ip_address
}


function prepare_murano_apps() {
    local start_dir=$1
    local clone_dir="${start_dir}/murano-app-incubator"

    cd ${start_dir}

    if [[ "${PROJECT_NAME}" == 'murano' || "${PROJECT_NAME}" == 'murano-agent' ]]; then
        git clone --branch ${APP_INCUBATOR_BRANCH} -- ${APP_INCUBATOR_REPO} ${clone_dir}

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


function make_img_with_murano_agent() {
    local agent_dir='/opt/git/agent'

    sudo apt-get --yes update && sudo apt-get --yes upgrade
    sudo apt-get --yes install kpartx git qemu-utils python-pip
    sudo pip install dib-utils

    sudo mkdir -p ${agent_dir}
    sudo chmod 777 ${agent_dir}

    git clone https://git.openstack.org/openstack/diskimage-builder.git \
        ${agent_dir}/diskimage-builder
    git clone ${ZUUL_URL}/${ZUUL_PROJECT} ${agent_dir}/murano-agent

    pushd ${agent_dir}/murano-agent
    git fetch ${ZUUL_URL}/${ZUUL_PROJECT} ${ZUUL_REF} && git checkout FETCH_HEAD
    popd

    export ELEMENTS_PATH=${agent_dir}/murano-agent/contrib/elements
    pushd ${agent_dir}
    ${agent_dir}/diskimage-builder/bin/disk-image-create vm ${DISTR_NAME} \
        murano-agent -o ${DISTR_NAME}${BUILD_NUMBER}-murano-agent.qcow2
    popd

    pushd "${STACK_HOME}/devstack"
    source openrc ${ADMIN_USERNAME} ${ADMIN_TENANT}
    popd

    glance image-create --name ${DISTR_NAME}${BUILD_NUMBER} \
        --disk-format qcow2 --container-format bare \
        --file ${agent_dir}/${DISTR_NAME}${BUILD_NUMBER}-murano-agent.qcow2 --is-public True \
        --property 'murano_image_info'="{\"type\":\"linux\",\"title\":\"${DISTR_NAME}${BUILD_NUMBER}\"}"

    LINUX_IMAGE=${DISTR_NAME}${BUILD_NUMBER}

    source "${CI_ROOT_DIR}/scripts/common.inc"
}


function remove_image_with_murano_agent() {

    pushd "${STACK_HOME}/devstack"
    source openrc ${ADMIN_USERNAME} ${ADMIN_TENANT}
    popd

    for i in $(glance image-list | get_field 2); do
        if [ "${DISTR_NAME}${BUILD_NUMBER}" == "$i" ]; then
           glance image-delete $i
        fi
    done
}


function prepare_tests() {
    sudo chown -R $USER "${PROJECT_TESTS_DIR}"

    case "${PROJECT_NAME}" in
        'murano')
            local config_file="${PROJECT_TESTS_DIR}/engine/config.conf"
            local section_name='murano'
        ;;
        'murano-dashboard')
            local config_file="${PROJECT_TESTS_DIR}/config/config.conf"
            local section_name='murano'
        ;;
        'python-muranoclient')
            local config_file="${PROJECT_TESTS_DIR}/engine/config.conf"
            local section_name='murano'
        ;;
        'murano-agent')
            local config_file="${PROJECT_TESTS_DIR}/engine/config.conf"
            local section_name='murano'
            make_img_with_murano_agent
        ;;
    esac

    if [ ! -f "${config_file}" ]; then
        touch "${config_file}"
    fi

    iniset "${section_name}" 'keystone_url' "$(shield_slashes http://${OPENSTACK_HOST}:5000/v2.0/)" "${config_file}"
    iniset "${section_name}" 'horizon_url' "$(shield_slashes http://${found_ip_address}/)" "${config_file}"
    iniset "${section_name}" 'murano_url' "$(shield_slashes http://${found_ip_address}:8082/)" "${config_file}"
    iniset "${section_name}" 'user' "${ADMIN_USERNAME}" "${config_file}"
    iniset "${section_name}" 'password' "${ADMIN_PASSWORD}" "${config_file}"
    iniset "${section_name}" 'tenant' "${ADMIN_TENANT}" "${config_file}"
    iniset "${section_name}" 'linux_image' "${LINUX_IMAGE}" "${config_file}"
    iniset "${section_name}" 'auth_url' "$(shield_slashes http://${OPENSTACK_HOST}:5000/v2.0/)" "${config_file}"

    prepare_murano_apps "${PROJECT_TESTS_DIR}"
}


function run_tests() {
    local retval=0

    # TODO(dteselkin): Remove this workaround as soon as
    #     https://bugs.launchpad.net/murano/+bug/1349934 is fixed.
    sudo rm -f /tmp/parser_table.py

    pushd "${PROJECT_TESTS_DIR}"

    TESTS_STARTED_AT=($(date +'%Y-%m-%d %H:%M:%S'))
    case "${PROJECT_NAME}" in
        'murano')
            $NOSETESTS_CMD -s -v \
                --with-xunit \
                --xunit-file=${WORKSPACE}/test_report${BUILD_NUMBER}.xml \
                ${PROJECT_TESTS_DIR}/engine/base.py || retval=$?
        ;;
        'murano-dashboard')
            $NOSETESTS_CMD -s -v sanity_check || retval=$?
        ;;
        'python-muranoclient')
            # Use tests from murano-dashboard until tests for
            #   python-muranoclient are ready.
            $NOSETESTS_CMD -s -v sanity_check || retval=$?
        ;;
        'murano-agent')
            $NOSETESTS_CMD -s -v \
                --with-xunit \
                --xunit-file=${WORKSPACE}/test_report${BUILD_NUMBER}.xml \
                ${PROJECT_TESTS_DIR}/engine/base.py:MuranoBase.test_deploy_telnet \
                ${PROJECT_TESTS_DIR}/engine/base.py:MuranoBase.test_deploy_apache || retval=$?
            remove_image_with_murano_agent
        ;;
    esac
    TESTS_FINISHED_AT=($(date +'%Y-%m-%d %H:%M:%S'))

    if [ $retval -ne 0 ]; then
        cat << EOF
List of murano processes:
********************************************************************************
$(ps aux | grep murano)
********************************************************************************
EOF
    fi

    collect_artifacts
    collect_openstack_logs

    popd

    ensure_no_heat_stacks_left || retval=$?

    return $retval
}


function collect_artifacts() {
    if [ "${DO_NOT_COLLECT_ARTIFACTS}" == 'true' ]; then
        return
    fi

    local dst="${WORKSPACE}/artifacts"
    local rsync_cmd="rsync --recursive --verbose --no-links"

    sudo mkdir -p ${dst}

    ### Add correct Apache log path
    if [ $distro_based_on == "redhat" ]; then
        apache_log_dir="/var/log/httpd"
    else
        apache_log_dir="/var/log/apache2"
    fi

    # rsync might fail if there is no file or folder,
    # so I disable error catching
    set +o errexit

    # Copy devstack logs:
    # * sleep for 1 minute to give devstack's log collector a chance to write all logs into files
    sleep 60
    sudo ${rsync_cmd} --include='*.log' --exclude='*' ${STACK_HOME}/log/ ${dst}/devstack

    # Copy murano logs from /tmp
    sudo ${rsync_cmd} --include='murano*.log' --exclude='*' /tmp/ ${dst}/tmp

    # Copy murano logs from /var/log/murano
    sudo ${rsync_cmd} --include='*/' --include='*.log' --exclude='*' /var/log/murano/ ${dst}/murano

    # Copy murano config files
    sudo mkdir -p ${dst}/etc/murano
    sudo ${rsync_cmd} /etc/murano/ ${dst}/etc/murano

    # Copy Apache logs
    sudo ${rsync_cmd} --include='*.log' --exclude='*' ${apache_log_dir}/ ${dst}/apache

    if [ $PROJECT_NAME == 'murano-dashboard' ]; then
        # Copy screenshots for failed tests
        sudo ${rsync_cmd} ${PROJECT_TESTS_DIR}/screenshots/ ${dst}/screenshots
    fi

    # return error catching back
    set -o errexit

    sudo chown -R jenkins:jenkins ${dst}
}


function collect_openstack_logs() {
    if [ "${DO_NOT_COLLECT_ARTIFACTS}" == 'true' ]; then
        return
    fi

    set +o errexit
    mkdir -p ${WORKSPACE}/artifacts/openstack
    ssh ${OPENSTACK_HOST} BUILD_TAG=${BUILD_TAG} \~/split-logs.sh ${TESTS_STARTED_AT[0]} ${TESTS_STARTED_AT[1]} ${TESTS_FINISHED_AT[0]} ${TESTS_FINISHED_AT[1]} heat neutron
    scp -r ${OPENSTACK_HOST}:~/log-parts/${BUILD_TAG}/* ${WORKSPACE}/artifacts/openstack
    ssh ${OPENSTACK_HOST} rm -rf \~/log-parts/${BUILD_TAG}
    set -o errexit
}


function ensure_no_heat_stacks_left() {
    local log_file="${STACK_HOME}/log/screen-murano-engine.log"
    local retval=0

    pushd "${STACK_HOME}/devstack"

    set +o xtrace
    echo "Importing openrc ..."
    source openrc ${ADMIN_USERNAME} ${ADMIN_TENANT}
    env > ~/envvars
    set -o xtrace

    for id in $(sed -n 's/.*\"OS\:\:stack_id\"\: \"\(.\{36\}\)\".*/\1/p' "${log_file}" | sort | uniq); do
        stack_info=$(heat stack-list | grep "${id}")
        if [ -n "${stack_info}" ]; then
            retval=1
            echo "Stack '${id}' found!"
            echo "${stack_info}"
            echo "Deleting stack '${id}'"
            heat stack-delete "${id}" > /dev/null
        fi
    done

    popd

    return $retval
}


function compress_log_files() {
    for f in $(find ${WORKSPACE}/artifacts -name '*.log'); do
        gzip < "${f}" > "${f}.gz" && rm -f "${f}"
    done
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

    sudo mkdir -p "${git_dir}/stackforge"
    sudo chown -R jenkins:jenkins "${git_dir}/stackforge"
    cd "${git_dir}/stackforge"
    git clone https://github.com/stackforge/murano

    if [ "${PROJECT_NAME}" == 'murano' ]; then
        pushd "${git_dir}/stackforge/murano"
        git fetch ${ZUUL_URL}/${ZUUL_PROJECT} ${ZUUL_REF} && git checkout FETCH_HEAD
        popd
    fi

    # NOTE: Source path MUST ends with a slash!
    rsync --recursive --exclude README.* "${git_dir}/stackforge/murano/contrib/devstack/" "${STACK_HOME}/devstack/"

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

    case "${PROJECT_NAME}" in
        'murano')
            echo "MURANO_REPO=${ZUUL_URL}/${ZUUL_PROJECT}" >> local.conf
            echo "MURANO_BRANCH=${ZUUL_REF}" >> local.conf
        ;;
        'murano-dashboard')
            echo "MURANO_DASHBOARD_REPO=${ZUUL_URL}/${ZUUL_PROJECT}" >> local.conf
            echo "MURANO_DASHBOARD_BRANCH=${ZUUL_REF}" >> local.conf
        ;;
        'python-muranoclient')
            echo "MURANO_PYTHONCLIENT_REPO=${ZUUL_URL}/${ZUUL_PROJECT}" >> local.conf
            echo "MURANO_PYTHONCLIENT_BRANCH=${ZUUL_REF}" >> local.conf
        ;;
    esac

    sudo ./tools/create-stack-user.sh
    echo 'stack:swordfish' | sudo chpasswd

    sudo chown -R stack:stack "${STACK_HOME}"

    sudo sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    sudo service ssh restart

    sudo su -c "cd ${STACK_HOME}/devstack && ./stack.sh" stack

    # Fix iptables to allow outbound access
    sudo iptables -I INPUT 1 -p tcp --dport 80 -j ACCEPT
}


function configure_apt_cacher() {
    local mode=$1
    local apt_proxy_host=${2:-$APT_PROXY_HOST}
    local apt_proxy_file=/etc/apt/apt.conf.d/01proxy

    if [ -z "${APT_PROXY_HOST}" ]; then
        return
    fi

    case $mode in
        enable)
            sudo sh -c "echo 'Acquire::http { Proxy \"http://${apt_proxy_host}:3142\"; };' > ${apt_proxy_file}"
            sudo apt-get update
        ;;
        disable)
            sudo rm -f $apt_proxy_file
            sudo apt-get update
        ;;
    esac
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

BUILD_STATUS_ON_EXIT='VM_REUSED'

# Create flags (files to check VM state)
if [ -f ~/build-started ]; then
    echo 'This VM is from previous tests run, terminating build'
    exit 1
else
    touch ~/build-started
fi

BUILD_STATUS_ON_EXIT='PREPARATION_FAILED'

if [ "${KEEP_VM_ALIVE}" == 'true' ]; then
    touch ~/keep-vm-alive
fi


sudo sh -c "echo '127.0.0.1 $(hostname)' >> /etc/hosts"
sudo iptables -F

adjust_time_settings

# Clone devstack first as we will use
# some of its files (functions-common, for example)
git_clone_devstack

get_os

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

#configure_apt_cacher enable

BUILD_STATUS_ON_EXIT='DEVSTACK_FAILED'

deploy_devstack

BUILD_STATUS_ON_EXIT='PREPARATION_FAILED'

start_xvfb_session

BUILD_STATUS_ON_EXIT='TESTS_FAILED'

prepare_tests

cat << EOF
Installed pypi packages:
********************************************************************************
$(pip freeze)
********************************************************************************
EOF

run_tests

BUILD_STATUS_ON_EXIT='SUCCESS'

exit 0
