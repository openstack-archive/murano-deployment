#!/bin/bash

#set -o xtrace

# To remove colors from log use the following command
#    sed 's/\x1B\[[0-9;]\{1,5\}m//g'

from_date=${1} # $(date +'%Y-%m-%d' -d 'yesterday')
from_time=${2} # '00:00:00'
to_date=${3}   # $(date +'%Y-%m-%d')
to_time=${4}   # '00:00:00'

shift 4
stack_components=$@


BUILD_TAG=${BUILD_TAG:-.}
OUTPUT_DIR=${OUTPUT_DIR:-~/log-parts}

declare -A stack_logs


if [ -d '/opt/stack/log' ]; then
    LOG_DIR=/opt/stack/log
    stack_logs[cinder]='screen-c-api.log screen-c-vol.log screen-c-sch.log'
    stack_logs[glance]='screen-g-api.log screen-g-reg.log'
    stack_logs[heat]='screen-h-api.log screen-h-api-cw.log screen-h-api-cfn.log screen-h-eng.log'
    stack_logs[horizon]='screen-horizon.log'
    stack_logs[keystone]='screen-key.log'
    stack_logs[neutron]='screen-q-lbaas.log screen-q-svc.log screen-q-l3.log screen-q-meta.log screen-q-dhcp.log screen-q-agt.log'
    stack_logs[nova]='screen-n-api.log screen-n-sch.log screen-n-obj.log screen-n-cauth.log screen-n-cond.log screen-n-novnc.log screen-n-xvnc.log screen-n-crt.log screen-n-cpu.log'
else
    LOG_DIR=/var/log
    stack_logs[cinder]=''
    stack_logs[glance]=''
    stack_logs[heat]='heat/heat-api.log heat/heat-engine.log'
    stack_logs[horizon]=''
    stack_logs[keystone]='keystone/keystone.log'
    stack_logs[neutron]='neutron/server.log'
    stack_logs[nova]='nova/nova-api.log nova/nova-compute.log'
fi


program="BEGIN {
  from_ts = \"${from_date}T${from_time}\";
  to_ts = \"${to_date}T${to_time}\";
}
{
  ts = \$1 \"T\" \$2;
  if (ts >= from_ts && ts < to_ts) print \$0;
}"


function split_logs() {
    local input_file
    local output_file

    while [ -n "$1" ]; do
        input_file="${LOG_DIR}/${1}"
        output_file="${OUTPUT_DIR}/${BUILD_TAG}/${1}"
        mkdir -p $(dirname ${output_file})
        if [ -f "${input_file}" ]; then
            cat ${input_file}.1 ${input_file} \
                | sed 's/\x1B\[[0-9;]\{1,5\}m//g' \
                | awk -- "${program}" > "${output_file}"
#            gzip < "${output_file}" > "${output_file}.gz" \
#                && rm -f "${output_file}"
        fi
        shift
    done
}


for component in ${stack_components}; do
    split_logs ${stack_logs[${component}]}
done
