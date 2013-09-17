#!/bin/bash

function die {
    cat << EOF

           Script Failed
***** ***** ***** ***** ***** *****
$@
***** ***** ***** ***** ***** *****
EOF
    exit 1
}



function title {
    cat << EOF


    $@
=================================================
EOF
}


function info {
    cat << EOF

[INFO] $@
EOF
}


function ssh_script {
    local remote_host=$1
    local script_path=$2
    shift 2

    local script_name=$(basename $script_path)

    scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=quiet \
      $script_path $remote_host:/tmp/$script_name.tmp
    ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=quiet \
      $remote_host bash /tmp/$script_name.tmp "$@"
}
