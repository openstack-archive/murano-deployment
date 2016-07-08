#!/bin/bash

LOG_DIR=/opt/stack/log
LOGS_TO_KEEP=10


function rotate() {
    local link_file=${1}
    local link_name=$(basename ${link_file})
    local link_target=$(readlink ${link_file})

    pushd ${LOG_DIR}
    for j in $(seq ${LOGS_TO_KEEP} -1 2); do
        local i=$((j - 1))
        if [ -f "${link_name}.${i}" ]; then
            mv "${link_name}.${i}" "${link_name}.${j}"
        fi
    done

    mv "${link_target}" "${LOG_DIR}/${link_name}.1"
    touch "${link_target}"
    popd
}

#rotate Openstack services log files but not stack.sh.log
find ${LOG_DIR} -type l -name '*.log' ! -name 'stack.sh.log' | while read file; do
    rotate "$file"
done
