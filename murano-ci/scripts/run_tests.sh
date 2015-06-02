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
CI_ROOT_DIR=$(cd $(dirname "$0") && cd .. && pwd)

# Include of the common functions library file
source "${CI_ROOT_DIR}/scripts/common.inc"
#-----------------

# Functions
#-------------------------------------------------------------------------------
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

    cat << EOF
********************************************************************************
*
*   Floating IP: ${floating_ip_address}
*   VNC connection string: vncviewer ${floating_ip_address}::5900
*
********************************************************************************
EOF

    # Launch window manager
    sudo apt-get install --yes openbox
    exec openbox &
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

function save_image_with_murano_agent() {

    pushd "${STACK_HOME}/devstack"
    source openrc ${ADMIN_USERNAME} ${ADMIN_TENANT}
    popd

    for i in $(glance image-list | get_field 2); do
        if [ "${DISTR_NAME}_latest" == "$i" ]; then
            glance image-delete $i
        fi
    done

    for i in $(glance image-list | get_field 2); do
        if [ "${DISTR_NAME}${BUILD_NUMBER}" == "$i" ]; then
            glance image-update --name ${DISTR_NAME}_latest \
                --property 'murano_image_info'="{\"type\": \"linux\", \"title\": \"${DISTR_NAME}_latest\"}" $i
        fi
    done
}

function run_nosetests() {
    local tests=$*
    local retval=0

    $NOSETESTS_CMD -s -v \
        --with-xunit \
        --xunit-file=${WORKSPACE}/artifacts/report/test_report.xml \
        $tests || retval=$?

    return $retval
}

function run_tests() {
    local retval=0

    # TODO(dteselkin): Remove this workaround as soon as
    #     https://bugs.launchpad.net/murano/+bug/1349934 is fixed.
    sudo rm -f /tmp/parser_table.py

    pushd "${PROJECT_TESTS_DIR}"

    mkdir -p ${WORKSPACE}/artifacts/report

    TESTS_STARTED_AT=($(date +'%Y-%m-%d %H:%M:%S'))
    if [[ -f "${EXECUTE_TESTS_BY_TAG}" ]]; then
        echo "Custom test configuration found. Executing..."
        run_nosetests -a "${EXECUTE_TESTS_BY_TAG}" || retval=$?
    else
        local tests
        case "${PROJECT_NAME}" in
            'murano')
                run_nosetests ${PROJECT_TESTS_DIR}/engine/base.py || retval=$?
            ;;
            'murano-dashboard'|'python-muranoclient')
                run_nosetests sanity_check || retval=$?
            ;;
            'murano-agent')
                run_nosetests ${PROJECT_TESTS_DIR}/engine/base.py:MuranoBase.test_deploy_telnet \
                    ${PROJECT_TESTS_DIR}/engine/base.py:MuranoBase.test_deploy_apache
            ;;
        esac
    fi

    if [[ "${PROJECT_NAME}" == 'murano-agent' ]]; then
        if [[ $retval -ne 0 ]]; then
            remove_image_with_murano_agent
        else
            save_image_with_murano_agent
        fi
    fi

    TESTS_FINISHED_AT=($(date +'%Y-%m-%d %H:%M:%S'))

    if [ $retval -ne 0 ]; then
        cat << EOF
List of murano processes:
********************************************************************************
$(ps aux | grep murano)
********************************************************************************
EOF
    fi

    popd

    ensure_no_heat_stacks_left || retval=$?

    return $retval
}

function ensure_no_heat_stacks_left() {
    local log_file="${STACK_HOME}/log/murano-engine.log"
    local retval=0

    pushd "${STACK_HOME}/devstack"

    set +o xtrace
    echo "Importing openrc ..."
    source openrc ${ADMIN_USERNAME} ${ADMIN_TENANT}
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

#-------------------------------------------------------------------------------
BUILD_STATUS_ON_EXIT='TESTS_FAILED'

start_xvfb_session

run_tests

BUILD_STATUS_ON_EXIT='TESTS_SUCCESS'

exit 0
