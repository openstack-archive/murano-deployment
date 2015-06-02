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

CI_ROOT_DIR=$(cd $(dirname "$0") && cd .. && pwd)

# Include of the common functions library file
source "${CI_ROOT_DIR}/scripts/common.inc"
#-----------------

trap 'trap_handler ${?} ${LINENO} ${0}' ERR
trap 'exit_handler ${?}' EXIT
#---------------------

# Enable debug output
#--------------------
PS4='+ [$(date --rfc-3339=seconds)] '
set -o xtrace
#--------------------

ELEMENTS=${ELEMENTS:-''}
IMAGE_NAME=${IMAGE_NAME:-'agent'}
BASE_DISTRO=${BASE_DISTRO:-'ubuntu'}

case "${PROJECT_NAME}" in
    'murano-agent')
        DIB_MURANO_AGENT_REPO=${ZUUL_URL}/${ZUUL_PROJECT}
        DIB_MURANO_AGENT_BRANCH=${ZUUL_BRANCH}
        DIB_MURANO_AGENT_REF=${ZUUL_REF}
    ;;
    'murano-apps')
        APPS_REPO=${ZUUL_URL}/${ZUUL_PROJECT}
        APPS_BRANCH=${ZUUL_BRANCH}
        APPS_REF=${ZUUL_REF}
    ;;
    *)
        echo "Nothing to build in project '${PROJECT_NAME}'"
    ;;
esac

ROOT_DIR='/opt/stack/'

function build_image() {
    local image_name=$1
    local base_distro=$2
    shift 2
    local elements=$@

    sudo apt-get --yes update && sudo apt-get --yes upgrade
    sudo apt-get --yes install kpartx git qemu-utils python-pip
    sudo pip install dib-utils

    sudo mkdir -p ${ROOT_DIR}
    sudo chmod 777 ${ROOT_DIR}

    git clone https://git.openstack.org/openstack/diskimage-builder.git \
        ${ROOT_DIR}/diskimage-builder

    git clone --branch ${APPS_BRANCH} -- ${APPS_REPO} ${ROOT_DIR}/murano-apps
    if [[ -n "${APPS_REF}" ]]; then
        pushd ${ROOT_DIR}/murano-apps
        git fetch ${APPS_REPO} ${APPS_REF} && git checkout FETCH_HEAD
        popd
    fi

    git clone --branch ${DIB_MURANO_AGENT_BRANCH} -- ${DIB_MURANO_AGENT_REPO} \
        ${ROOT_DIR}/murano-agent
    if [[ -n "${DIB_MURANO_AGENT_REF}" ]]; then
        pushd ${ROOT_DIR}/murano-agent
        git fetch ${DIB_MURANO_AGENT_REPO} ${DIB_MURANO_AGENT_REF} && \
            git checkout FETCH_HEAD
        popd
    fi

    mkdir -p ${ROOT_DIR}/elements
    cp -R ${ROOT_DIR}/murano-agent/contrib/elements/* ${ROOT_DIR}/elements/
    for element_dir in $(find ${ROOT_DIR}/murano-apps -type d -iname elements); do
        cp -R ${element_dir}/* ${ROOT_DIR}/elements/
    done

    local murano_agent_element='murano-agent'

    if [[ "${base_distro}" == "debian" ]]; then
        murano_agent_element='debian-murano-agent'
        export DIB_RELEASE=jessie
        export DIB_CLOUD_INIT_DATASOURCES="Ec2, ConfigDrive, OpenStack"
    fi

    export ELEMENTS_PATH=${ROOT_DIR}/elements
    pushd ${ROOT_DIR}
    ${ROOT_DIR}/diskimage-builder/bin/disk-image-create vm ${base_distro} \
        ${murano_agent_element} ${elements} -o ${base_distro}${BUILD_NUMBER}-${image_name}.qcow2
}

BUILD_STATUS_ON_EXIT='IMAGE_BUILD_FAILED'

build_image ${IMAGE_NAME} ${BASE_DISTRO} ${ELEMENTS}

BUILD_STATUS_ON_EXIT='IMAGE_BUILD_SUCCEEDED'
