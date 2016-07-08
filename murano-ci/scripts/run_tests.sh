#!/bin/bash
# Copyright (c) 2015 Mirantis, Inc.
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
function start_xvfb_session() {
    if [[ "${PROJECT_NAME}" == 'murano' ]] || [[ "${PROJECT_NAME}" == 'murano-agent' ]]; then
        echo "Skipping 'start_xvfb_session' ..."
        return
    fi

    export DISPLAY=:${VFB_DISPLAY_NUM}

    fonts_path="/usr/share/fonts/X11/misc/"
    if [ "$DISTRO_BASED_ON" == "redhat" ]; then
        fonts_path="/usr/share/X11/fonts/misc/"
    fi

    # Start XVFB session
    sudo Xvfb -fp "${fonts_path}" "${DISPLAY}" -screen 0 "${VFB_DISPLAY_SIZE}x${VFB_COLOR_DEPTH}" &

    # Start VNC server
    sudo apt-get install --yes x11vnc
    x11vnc -bg -forever -nopw -display "${DISPLAY}" -ncache 10
    sudo iptables -I INPUT 1 -p tcp --dport 5900 -j ACCEPT

    cat << EOF
********************************************************************************
*
*   Floating IP: ${FLOATING_IP_ADDRESS}
*   VNC connection string: vncviewer ${FLOATING_IP_ADDRESS}::5900
*
********************************************************************************
EOF

    # Launch window manager
    sudo apt-get install --yes openbox
    exec openbox &
}

function run_nosetests() {
    local tests=$*
    local retval=0

    $NOSETESTS_CMD -s -v \
        --with-xunit \
        --xunit-file="${WORKSPACE}/artifacts/report/test_report.xml" \
        $tests || retval=$?

    return $retval
}

function run_tests() {
    local retval=0

    # TODO(dteselkin): Remove this workaround as soon as
    #     https://bugs.launchpad.net/murano/+bug/1349934 is fixed.
    sudo rm -f /tmp/parser_table.py

    pushd "${PROJECT_TESTS_DIR}"

    mkdir -p "${WORKSPACE}/artifacts/report"

    TESTS_STARTED_AT=($(date +'%Y-%m-%d %H:%M:%S'))
    case "${PROJECT_NAME}" in
        'murano')
            if [[ -n "${EXECUTE_TESTS_BY_TAG}" ]]; then
                echo "Custom test configuration found. Executing..."
                run_nosetests -a "${EXECUTE_TESTS_BY_TAG}" "${PROJECT_TESTS_DIR}/engine/" || retval=$?
            else
                run_nosetests "${PROJECT_TESTS_DIR}/engine/base.py" || retval=$?
            fi
        ;;
        'murano-dashboard'|'python-muranoclient')
            if [[ -n "${EXECUTE_TESTS_BY_TAG}" ]]; then
                echo "Custom test configuration found. Executing..."
                run_nosetests -a "${EXECUTE_TESTS_BY_TAG}" || retval=$?
            else
                run_nosetests sanity_check || retval=$?
            fi
        ;;
        'murano-agent')
            if [[ -n "${EXECUTE_TESTS_BY_TAG}" ]]; then
                echo "Custom test configuration found. Executing..."
                run_nosetests -a "${EXECUTE_TESTS_BY_TAG}" "${PROJECT_TESTS_DIR}/engine/" || retval=$?
            else
                run_nosetests "${PROJECT_TESTS_DIR}/engine/base.py:MuranoBase.test_deploy_telnet" \
                    "${PROJECT_TESTS_DIR}/engine/base.py:MuranoBase.test_deploy_apache"
            fi
        ;;
    esac

    if [[ "${PROJECT_NAME}" == 'murano-agent' ]]; then
        if [[ "${SAVE_IMAGE}" == "yes" ]] && [[ $retval -eq 0 ]]; then
            save_image_with_murano_agent
        else
            remove_image_with_murano_agent
        fi
    fi

    TESTS_FINISHED_AT=($(date +'%Y-%m-%d %H:%M:%S'))

    if [ $retval -ne 0 ]; then
        cat << EOF
List of murano processes:
********************************************************************************
$(pgrep -l -f -a murano)
********************************************************************************
EOF
    fi

    popd

    ensure_no_heat_stacks_left || retval=$?

    return $retval
}

#-------------------------------------------------------------------------------
BUILD_STATUS_ON_EXIT='TESTS_FAILED'

start_xvfb_session

run_tests

BUILD_STATUS_ON_EXIT='TESTS_SUCCESS'

exit 0
