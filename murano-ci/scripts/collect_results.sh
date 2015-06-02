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
function collect_screenshots() {
    if [ "$PROJECT_NAME" == 'murano-dashboard' ]; then
        # Copy screenshots for failed tests
        mkdir -p "${dst}/screenshots"
        cp -Rv ${PROJECT_TESTS_DIR}/screenshots/* "${dst}/screenshots/"
    fi
}

function generate_html_report() {
    local xml_report="${WORKSPACE}/artifacts/report/test_report.xml"
    local html_report="${WORKSPACE}/artifacts/report/test_report.html"

    if [[ -f "${WORKSPACE}/artifacts/report/test_report.xml" ]]; then
        sudo pip install jinja2 lxml

        $(which python) "${WORKSPACE}/murano-ci/scripts/generate_html_report.py" "${xml_report}" "${html_report}"
        cp "${WORKSPACE}/artifacts/report/test_report.html" "${WORKSPACE}/index.html"
    fi
}

function collect_coverage() {
    if [ -f "${WORKSPACE}/.with_coverage" ]; then
        pushd "${WORKSPACE}"

        kill "$(ps hf -C python | grep murano-api | awk '{ print $1; exit }')"
        kill "$(ps hf -C python | grep murano-engine | awk '{ print $1; exit }')"

        sleep 10

        coverage combine

        mkdir -p "${WORKSPACE}/artifacts/coverage/"

        coverage html -d "${WORKSPACE}/artifacts/coverage/"

        rm -rf "${WORKSPACE}/.with_coverage"

        popd
    else
        echo "Skipping 'collect_coverage'"
    fi
}

BUILD_STATUS_ON_EXIT='RESULT_COLLECTION_FAILED'

collect_coverage

collect_screenshots

generate_html_report

BUILD_STATUS_ON_EXIT='RESULTS_COLLECTED'
