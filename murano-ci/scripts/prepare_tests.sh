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

# Functions
#-------------------------------------------------------------------------------
function prepare_murano_apps() {
    local start_dir=$1
    local clone_dir="${start_dir}/murano-apps"

    cd "${start_dir}"

    if [[ "${PROJECT_NAME}" == 'murano' || "${PROJECT_NAME}" == 'murano-agent' ]]; then
        git clone --branch ${APPS_BRANCH} -- ${APPS_REPO} ${clone_dir}

        local manifest
        cd "${clone_dir}"
        for manifest in $(find . -type f -name manifest.yaml); do
            local package=$(dirname "$manifest")
            make_package "${package}" "${start_dir}"
        done
    fi
}

function prepare_old_murano_apps() {
    local start_dir=$1
    local clone_dir="${start_dir}/murano-app-incubator"

    cd "${start_dir}"

    if [[ "${PROJECT_NAME}" == 'murano' || "${PROJECT_NAME}" == 'murano-agent' ]]; then
        git clone --branch master -- http://github.com/murano-project/murano-app-incubator "${clone_dir}"

        local manifest
        cd "${clone_dir}"
        for manifest in $(find . -type f -name manifest.yaml); do
            local package=$(dirname "$manifest")
            make_package "${package}" "${clone_dir}"
        done
    fi
}

function make_package() {
    local path=$1
    local zip_dir=$2

    if [[ -d "${path}" ]]; then
        local package_name=${path##*/}
        if [[ "$package_name" == "package" ]]; then
            local base_path=${path%/*}
            package_name=${base_path##*/}
        fi

        pushd "${path}"

        zip -r "${zip_dir}/${package_name}.zip" ./*

        popd
    fi
}

function make_img_with_murano_agent() {
    local agent_dir='/opt/git/agent'

    sudo apt-get -y update && sudo apt-get --yes upgrade
    sudo apt-get -y install kpartx git qemu-utils python-pip debootstrap
    sudo pip install dib-utils

    sudo mkdir -p "${agent_dir}"
    sudo chmod 777 "${agent_dir}"

    git clone https://git.openstack.org/openstack/diskimage-builder.git \
        "${agent_dir}/diskimage-builder"
    git clone "${ZUUL_URL}/${ZUUL_PROJECT}" "${agent_dir}/murano-agent"

    pushd "${agent_dir}/murano-agent"
    git fetch "${ZUUL_URL}/${ZUUL_PROJECT}" "${ZUUL_REF}" && git checkout FETCH_HEAD
    popd

    mkdir -p "${agent_dir}/elements"
    cp -R ${agent_dir}/murano-agent/contrib/elements/* "${agent_dir}/elements/"

    export DIB_CLOUD_INIT_DATASOURCES="Ec2, ConfigDrive, OpenStack"
    export ELEMENTS_PATH="${agent_dir}/elements"
    pushd "${agent_dir}"
    if [[ "${DISTR_NAME}" == "debian" ]]; then
        export DIB_RELEASE=wheezy
        "${agent_dir}/diskimage-builder/bin/disk-image-create" vm "${DISTR_NAME}" \
            murano-agent-debian -o "${DISTR_NAME}${BUILD_NUMBER}-murano-agent.qcow2"
    else
        "${agent_dir}/diskimage-builder/bin/disk-image-create" vm "${DISTR_NAME}" \
            cloud-init-datasources murano-agent -o "${DISTR_NAME}${BUILD_NUMBER}-murano-agent.qcow2"
    fi
    popd

    pushd "${STACK_HOME}/devstack"
    source openrc "${ADMIN_USERNAME}" "${ADMIN_TENANT}"
    popd

    glance image-create --name "${DISTR_NAME}_${BUILD_NUMBER}" \
        --disk-format qcow2 --container-format bare \
        --file "${agent_dir}/${DISTR_NAME}${BUILD_NUMBER}-murano-agent.qcow2" \
        --property 'murano_image_info'="{\"type\":\"linux\",\"title\":\"${DISTR_NAME}_${BUILD_NUMBER}\"}"

    LINUX_IMAGE="${DISTR_NAME}_${BUILD_NUMBER}"
}

function prepare_tests() {
    sudo chown -R "$USER" "${PROJECT_TESTS_DIR}"

    case "${PROJECT_NAME}" in
        'murano')
            local config_file="${PROJECT_TESTS_DIR}/engine/config.conf"
            local section_name='murano'
        ;;
        'murano-dashboard'|'python-muranoclient')
            local config_file="${PROJECT_TESTS_DIR}/config/config.conf"
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

    set_config "${section_name}" 'keystone_url' "$(shield_slashes http://${OPENSTACK_HOST}:5000/v2.0/)" "${config_file}"
    set_config "${section_name}" 'horizon_url' "$(shield_slashes http://${FOUND_IP_ADDRESS}/dashboard/)" "${config_file}"
    set_config "${section_name}" 'murano_url' "$(shield_slashes http://${FOUND_IP_ADDRESS}:8082/)" "${config_file}"
    set_config "${section_name}" 'user' "${ADMIN_USERNAME}" "${config_file}"
    set_config "${section_name}" 'password' "${ADMIN_PASSWORD}" "${config_file}"
    set_config "${section_name}" 'tenant' "${ADMIN_TENANT}" "${config_file}"
    set_config "${section_name}" 'linux_image' "${LINUX_IMAGE}" "${config_file}"
    set_config "${section_name}" 'auth_url' "$(shield_slashes http://${OPENSTACK_HOST}:5000/v2.0/)" "${config_file}"

    prepare_murano_apps "${PROJECT_TESTS_DIR}"

    # Workaround for backward compatibility
    prepare_old_murano_apps "${PROJECT_TESTS_DIR}"

    if [[ ! -d "${WORKSPACE}/artifacts" ]]; then
            mkdir "${WORKSPACE}/artifacts"
    fi
    cp "${config_file}" "${WORKSPACE}/artifacts/test_config.conf"
}

function start_screen() {
    local name=$1
    local cmd=$2

    screen -S "$name" -d -m "$cmd"
}

function start_coverage() {
    if [ "${WITH_COVERAGE}" == 'true' ]; then
        pushd "${WORKSPACE}"

        touch "${WORKSPACE}/.with_coverage"

        # NOTE: coverage < 4.0a5 doesn't provide correct HTML report generation
        sudo pip install "coverage>=4.0a5"

        sudo killall murano-api
        sudo killall murano-engine

        cat <<EOF >> ${WORKSPACE}/.coveragerc
[run]
data_file=.coverage
source=murano
parallel=true
EOF

        start_screen murano-api "$(which python) $(which coverage) run --rcfile ${WORKSPACE}/.coveragerc $(which murano-api) --config-file /etc/murano/murano.conf"
        start_screen murano-engine "$(which python) $(which coverage) run --rcfile ${WORKSPACE}/.coveragerc $(which murano-engine) --config-file /etc/murano/murano.conf"

        popd
    else
        echo "Skipping 'start_coverage'"
    fi
}

BUILD_STATUS_ON_EXIT='PREPARATION_FAILED'

start_coverage

prepare_tests

cat << EOF
Installed pypi packages:
********************************************************************************
$(pip freeze)
********************************************************************************
EOF

BUILD_STATUS_ON_EXIT='PREPARATION_FINISHED'
