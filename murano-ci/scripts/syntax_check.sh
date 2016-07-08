#!/bin/bash

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

# Check Jenkins Job syntax
jenkins-jobs -l debug test -r -o $WORKSPACE $CI_ROOT_DIR/jobs

# Validate shell scripts
find "${CI_ROOT_DIR}" -name "*.sh" | while read file; do
  shellcheck $file -e SC2086,SC2016,SC2034,SC2046,SC2140
done
