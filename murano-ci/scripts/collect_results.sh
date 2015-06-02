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
function generate_html_report() {
    local xml_report=${WORKSPACE}/artifacts/report/test_report.xml
    local html_report=${WORKSPACE}/artifacts/report/test_report.html

    if [[ -f "${WORKSPACE}/artifacts/report/test_report.xml" ]]; then
        sudo pip install jinja2 lxml

        $(which python) ${CI_ROOT_DIR}/scripts/generate_html_report.py ${xml_report} ${html_report}
        cp ${WORKSPACE}/artifacts/report/test_report.html ${WORKSPACE}/index.html
    fi
}

function collect_coverage() {
    if [ "${WITH_COVERAGE}" == 'true' ]; then
        pushd ${WORKSPACE}

        kill $(ps hf -C python | grep murano-api | awk '{ print $1; exit }')
        kill $(ps hf -C python | grep murano-engine | awk '{ print $1; exit }')

        sleep 10

        coverage combine

        mkdir -p ${WORKSPACE}/artifacts/coverage/

        local openstack_common=$(python -c "import os; from murano import openstack; print os.path.dirname(os.path.abspath(openstack.__file__))")/*

        coverage html -d ${WORKSPACE}/artifacts/coverage/ --omit=$openstack_common

        popd
    else
        echo "Skipping 'collect_coverage'"
    fi
}

BUILD_STATUS_ON_EXIT='RESULT_COLLECTION_FAILED'

generate_html_report

collect_coverage

BUILD_STATUS_ON_EXIT='RESULTS_COLLECTED'
