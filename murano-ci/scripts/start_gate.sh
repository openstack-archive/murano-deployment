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

EXIT_CODE=0

bash ./scripts/deploy_devstack.sh || EXIT_CODE=$?

if [[ $EXIT_CODE -eq 0 ]]; then
    bash ./scripts/prepare_tests.sh || EXIT_CODE=$?
fi

if [[ $EXIT_CODE -eq 0 ]]; then
    bash ./scripts/run_tests.sh || EXIT_CODE=$?
fi

if [[ $EXIT_CODE -eq 0 ]]; then
    bash ./scripts/collect_results.sh || EXIT_CODE=$?
fi

bash ./scripts/collect_logs.sh $EXIT_CODE

exit $EXIT_CODE
