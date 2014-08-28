#!/bin/bash

action=${1:-help}

STACK_HOME=/opt/stack



function install_devstack() {
    rm -f ${STACK_HOME}/devstack/post-unstack.sh
    cp ./post-stack.sh ${STACK_HOME}/devstack/

    pushd ${STACK_HOME}/devstack
    ./stack.sh
    ./post-stack.sh
    popd
}

function uninstall_devstack() {
    rm -f ${STACK_HOME}/devstack/post-stack.sh
    cp ./post-unstack.sh ${STACK_HOME}/devstack/

    pushd ${STACK_HOME}/devstack
    ./unstack.sh
    ./post-unstack.sh
    popd
}

function copy_scripts() {
    rm -f ${STACK_HOME}/rotate-devstack-logs.sh
    cp ../../tools/rotate-devstack-logs.sh ${STACK_HOME}
    chmod +x ${STACK_HOME}/rotate-devstack-logs.sh

    rm -f ${STACK_HOME}/split-logs.sh
    cp ../../tools/split-logs.sh ${STACK_HOME}
    chmod +x ${STACK_HOME}/split-logs.sh

    rm -f ${STACK_HOME}/devstack/local.sh
    cp ./local.sh ${STACK_HOME}/devstack/

    rm -f /${STACK_HOME}/devstack/build-murano-image.sh
    cp ./build-murano-image.sh ${STACK_HOME}/devstack/
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
        copy_scripts
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
