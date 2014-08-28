#!/bin/bash

action=${1:-help}

STACK_HOME=/opt/stack



function install_devstack() {
    pushd ${STACK_HOME}/devstack
    ./stack.sh
    ./post-stack.sh
    popd
}

function uninstall_devstack() {
    pushd ${STACK_HOME}/devstack
    ./unstack.sh
    ./post-unstack.sh
    popd
}

function prepare_lab() {
    cp ../../tools/rotate-devstack-logs.sh ${STACK_HOME}
    cp ../../tools/split-logs.sh ${STACK_HOME}

    cp ./local.sh ${STACK_HOME}/devstack/
    cp ./post-stack.sh ${STACK_HOME}/devstack/
    cp ./post-unstack.sh ${STACK_HOME}/devstack/
}

function show_help() {
    cat << EOF
Available commands:

    * stack - install devstack
    * unstack - uninstall devstack
EOF
}



case ${action} in
    'stack')
        prepare_lab
        install_devstack
    ;;
    'unstack')
        uninstall_devstack
    ;;
    'help')
        show_help
    ;;
    *)
        echo "Unknown command '${action}'"
        show_help
    ;;
esac
