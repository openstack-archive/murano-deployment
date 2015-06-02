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

# Functions
#-------------------------------------------------------------------------------
function collect_artifacts() {
    if [ "${DO_NOT_COLLECT_ARTIFACTS}" == 'true' ]; then
        return
    fi

    local dst="${WORKSPACE}/artifacts"
    local rsync_cmd="rsync --recursive --verbose --no-links"

    sudo mkdir -p ${dst}

    ### Add correct Apache log path
    distro_based_on=${distro_based_on:-ubuntu}
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
    ls -hal ${STACK_HOME}/log
    cd ${STACK_HOME}/log && find ./ -type l | \
        sudo rsync --verbose --files-from=- --copy-links --no-dirs ${STACK_HOME}/log ${dst}/devstack

    # Copy murano logs from /tmp
    sudo ${rsync_cmd} --include='murano*.log' --exclude='*' /tmp/ ${dst}/tmp

    # Copy murano logs from /var/log/murano
    if [[ -d "/var/log/murano" ]]; then
        sudo ${rsync_cmd} --include='*/' --include='*.log' --exclude='*' /var/log/murano/ ${dst}/murano
    fi

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
BUILD_STATUS_ON_EXIT='LOG_COLLECTION_FAILED'

collect_artifacts

cd ${WORKSPACE}

BUILD_STATUS_ON_EXIT='LOG_COLLECTED'

exit $1
