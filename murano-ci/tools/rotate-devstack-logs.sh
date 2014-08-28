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
    popd

    mv "${link_target}" "${LOG_DIR}/${link_name}.1"
    touch "${link_target}"
}


for item in $(find ${LOG_DIR} -type l -name 'screen*'); do
    rotate ${item}
done
