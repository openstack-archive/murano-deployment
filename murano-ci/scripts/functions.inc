#!/bin/bash
#
# Common functions file
#
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
    echo "$0: ${BUILD_STATUS_ON_EXIT}" >> $WORKSPACE/artifacts/build_status
    echo "$0: ${BUILD_STATUS_ON_EXIT}" >> $WORKSPACE/artifacts/overall-status.txt
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

function lowercase() {
    local input=$1
    local retval=$(echo $input | sed -e 's/\(.*\)/\L\1/')
    echo $retval
}

function iniset() {
    local section=$1
    local option=$2
    local value=$3
    local file=$4
    local line

    if [ -z "$section" ] ; then
        # No section name specified
        sed -i -e "s/^\($option[ \t]*=[ \t]*\).*$/\1$value/" "$file"
    else
        # Check if section already exists
        if ! grep -q "^\[$section\]" "$file" ; then
            # Add section at the end
            echo -e "\n[$section]" >>"$file"
        fi

        # Check if parameter in the section exists
        line=$(sed -ne "/^\[$section\]/,/^\[.*\]/ { /^$option[ \t]*=/ p; }" "$file")
        if [ -z "$line" ] ; then
            # Add parameter if it is not exists
            sed -i -e "/^\[$section\]/ a\\
$option = $value
" "$file"
        else
            # Replace existing parameter
            sed -i -e "/^\[$section\]/,/^\[.*\]/ s|^\($option[ \t]*=[ \t]*\).*$|\1$value|" "$file"
        fi
    fi
}

function get_os() {
    local retval=0
    local OS=$(uname)

    if [[ -z "${OS}" ]]; then
        if [ "${OS}" = "Linux" ] ; then
            if [ -f /etc/redhat-release ] ; then
                DISTRO_BASED_ON='RedHat'
            elif [ -f /etc/SuSE-release ] ; then
                DISTRO_BASED_ON='SuSe'
            elif [ -f /etc/debian_version ] ; then
                DISTRO_BASED_ON='Debian'
            fi
            DISTRO_BASED_ON=$(lowercase $DISTRO_BASED_ON)
            readonly DISTRO_BASED_ON
        else
            echo "Unsupported operating system:\"$OS\", sorry!"
            retval=1
        fi
    else
        retval=0
    fi
    return $retval
}

function shield_slashes() {
    local input=$1
    local retval=$(echo $input | sed 's/\//\\\//g')
    echo $retval
}

function get_ip_from_iface() {
    local iface_name=$1

    if [[ -z "${FOUND_IP_ADDRESS}" ]]; then
        FOUND_IP_ADDRESS=$(ifconfig $iface_name | awk -F ' *|:' '/inet addr/{print $4}')

        if [ $? -ne 0 ] || [ -z "$FOUND_IP_ADDRESS" ]; then
            echo "Can't obtain ip address from interface $iface_name!"
            return 1
        else
            readonly FOUND_IP_ADDRESS
        fi
    fi
}

function get_floating_ip() {
    if [[ -z "${FLOATING_IP_ADDRESS}" ]]; then
        sudo pip install "python-novaclient>=2.22.0,<2.24.0"

        export OS_USERNAME=${ADMIN_USERNAME}
        export OS_PASSWORD=${ADMIN_PASSWORD}
        export OS_TENANT_NAME=${ADMIN_TENANT}
        export OS_AUTH_URL="http://${OPENSTACK_HOST}:5000/v2.0"

        FLOATING_IP_ADDRESS=$(nova floating-ip-list | grep " ${FOUND_IP_ADDRESS} " | cut -d ' ' -f 4)

        if [ -z ""${FLOATING_IP_ADDRESS} ]; then
            exit 1
        fi

        readonly FLOATING_IP_ADDRESS
    fi
}
