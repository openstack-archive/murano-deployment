#!/bin/bash

CONFIG_FILE=${CONFIG_FILE:-'./config.ini'}

status_file=$(tempfile)


# Common helper functions
#-------------------------------------------------------------------------------

function die() {
    cat << EOF

*** SCRIPT FAILED ***
$@
EOF
    exit 1
}


function die_if_no_file() {
    if [ ! -f "$1" ]; then
        die "File '$1' not exist!"
    fi
}


function msg() {
    cat << EOF

* $@
EOF
}


function err() {
    cat << EOF >&1

* $@
EOF
}

#-------------------------------------------------------------------------------


# Devstack functions
#-------------------------------------------------------------------------------
# Determine OS Vendor, Release and Update
# Tested with OS/X, Ubuntu, RedHat, CentOS, Fedora
# Returns results in global variables:
# os_VENDOR - vendor name
# os_RELEASE - release
# os_UPDATE - update
# os_PACKAGE - package type
# os_CODENAME - vendor's codename for release
# GetOSVersion
GetOSVersion() {
    # Figure out which vendor we are
    if [[ -x "`which sw_vers 2>/dev/null`" ]]; then
        # OS/X
        os_VENDOR=`sw_vers -productName`
        os_RELEASE=`sw_vers -productVersion`
        os_UPDATE=${os_RELEASE##*.}
        os_RELEASE=${os_RELEASE%.*}
        os_PACKAGE=""
        if [[ "$os_RELEASE" =~ "10.7" ]]; then
            os_CODENAME="lion"
        elif [[ "$os_RELEASE" =~ "10.6" ]]; then
            os_CODENAME="snow leopard"
        elif [[ "$os_RELEASE" =~ "10.5" ]]; then
            os_CODENAME="leopard"
        elif [[ "$os_RELEASE" =~ "10.4" ]]; then
            os_CODENAME="tiger"
        elif [[ "$os_RELEASE" =~ "10.3" ]]; then
            os_CODENAME="panther"
        else
            os_CODENAME=""
        fi
    elif [[ -x $(which lsb_release 2>/dev/null) ]]; then
        os_VENDOR=$(lsb_release -i -s)
        os_RELEASE=$(lsb_release -r -s)
        os_UPDATE=""
        os_PACKAGE="rpm"
        if [[ "Debian,Ubuntu,LinuxMint" =~ $os_VENDOR ]]; then
            os_PACKAGE="deb"
        elif [[ "SUSE LINUX" =~ $os_VENDOR ]]; then
            lsb_release -d -s | grep -q openSUSE
            if [[ $? -eq 0 ]]; then
                os_VENDOR="openSUSE"
            fi
        elif [[ $os_VENDOR == "openSUSE project" ]]; then
            os_VENDOR="openSUSE"
        elif [[ $os_VENDOR =~ Red.*Hat ]]; then
            os_VENDOR="Red Hat"
        fi
        os_CODENAME=$(lsb_release -c -s)
    elif [[ -r /etc/redhat-release ]]; then
        # Red Hat Enterprise Linux Server release 5.5 (Tikanga)
        # Red Hat Enterprise Linux Server release 7.0 Beta (Maipo)
        # CentOS release 5.5 (Final)
        # CentOS Linux release 6.0 (Final)
        # Fedora release 16 (Verne)
        # XenServer release 6.2.0-70446c (xenenterprise)
        os_CODENAME=""
        for r in "Red Hat" CentOS Fedora XenServer; do
            os_VENDOR=$r
            if [[ -n "`grep \"$r\" /etc/redhat-release`" ]]; then
                ver=`sed -e 's/^.* \([0-9].*\) (\(.*\)).*$/\1\|\2/' /etc/redhat-release`
                os_CODENAME=${ver#*|}
                os_RELEASE=${ver%|*}
                os_UPDATE=${os_RELEASE##*.}
                os_RELEASE=${os_RELEASE%.*}
                break
            fi
            os_VENDOR=""
        done
        os_PACKAGE="rpm"
    elif [[ -r /etc/SuSE-release ]]; then
        for r in openSUSE "SUSE Linux"; do
            if [[ "$r" = "SUSE Linux" ]]; then
                os_VENDOR="SUSE LINUX"
            else
                os_VENDOR=$r
            fi

            if [[ -n "`grep \"$r\" /etc/SuSE-release`" ]]; then
                os_CODENAME=`grep "CODENAME = " /etc/SuSE-release | sed 's:.* = ::g'`
                os_RELEASE=`grep "VERSION = " /etc/SuSE-release | sed 's:.* = ::g'`
                os_UPDATE=`grep "PATCHLEVEL = " /etc/SuSE-release | sed 's:.* = ::g'`
                break
            fi
            os_VENDOR=""
        done
        os_PACKAGE="rpm"
    # If lsb_release is not installed, we should be able to detect Debian OS
    elif [[ -f /etc/debian_version ]] && [[ $(cat /proc/version) =~ "Debian" ]]; then
        os_VENDOR="Debian"
        os_PACKAGE="deb"
        os_CODENAME=$(awk '/VERSION=/' /etc/os-release | sed 's/VERSION=//' | sed -r 's/\"|\(|\)//g' | awk '{print $2}')
        os_RELEASE=$(awk '/VERSION_ID=/' /etc/os-release | sed 's/VERSION_ID=//' | sed 's/\"//g')
    fi
    export os_VENDOR os_RELEASE os_UPDATE os_PACKAGE os_CODENAME
}


# Get an option from an INI file
# iniget config-file section option
function iniget() {
    local file=$1
    local section=$2
    local option=$3
    local line
    line=$(sed -ne "/^\[$section\]/,/^\[.*\]/ { /^$option[ \t]*=/ p; }" "$file")
    echo ${line#*=}
}


# Determinate is the given option present in the INI file
# ini_has_option config-file section option
function ini_has_option() {
    local file=$1
    local section=$2
    local option=$3
    local line
    line=$(sed -ne "/^\[$section\]/,/^\[.*\]/ { /^$option[ \t]*=/ p; }" "$file")
    [ -n "$line" ]
}


# Set an option in an INI file
# iniset config-file section option value
function iniset() {
    local file=$1
    local section=$2
    local option=$3
    local value=$4

    [[ -z $section || -z $option ]] && return

    if ! grep -q "^\[$section\]" "$file" 2>/dev/null; then
        # Add section at the end
        echo -e "\n[$section]" >>"$file"
    fi
    if ! ini_has_option "$file" "$section" "$option"; then
        # Add it
        sed -i -e "/^\[$section\]/ a\\
$option = $value
" "$file"
    else
        local sep=$(echo -ne "\x01")
        # Replace it
        sed -i -e '/^\['${section}'\]/,/^\[.*\]/ s'${sep}'^\('${option}'[ \t]*=[ \t]*\).*$'${sep}'\1'"${value}"${sep} "$file"
    fi
}
#-------------------------------------------------------------------------------


# Config parser functions
#-------------------------------------------------------------------------------

function trim() {
    echo "$@"
}


function status() {
    echo -e "$@" >> $status_file
}


function get_item() {
    validate_item
    if [ ${item[invalid]} = 'true' ] ; then
        return
    fi


}


function print_item() {
    validate_item
    if [ ${item[invalid]} = 'true' ] ; then
        return
    fi

    cat << EOF

Section   = $section
Name      = ${item[name]}
Path      = ${item[path]}
URL       = ${item[url]}
Skip      = ${item[skip]}
Mandatory = ${item[mandatory]}
EOF
}


function validate_item() {
    if [[ "$section" = 'DEFAULT' ]]; then
        return
    fi

#    if [[ -z "${item[name]}" ]] ; then
#        err "Section '$section', line $line_number: Name is empty!"
#        item[invalid]='true'
#    fi

    if [[ -z "${item[path]}" ]] ; then
        err "Section '$section', line $line_number: Path is empty!"
        item[invalid]='true'
    fi

    if [[ -z "${item[url]}" ]] ; then
        err "Section '$section', line $line_number: URL is empty!"
        item[invalid]='true'
    fi

    if [ ${item[invalid]} = 'true' ] ; then
        msg "Bad input in section '$section'"
    fi
}


function download_item() {
    local file_name

    validate_item
    if [ ${item[invalid]} = 'true' ] ; then
        return
    fi

    if [ "${item[skip]}" = 'true' ] ; then
        msg "Skipping section '$section'"
        return
    fi

    mkdir -p ${item[path]}

    if [[ -z "${item[name]}" ]] ; then
        file_name=$(basename ${item[url]})
    else
        file_name=${item[name]}
    fi

    if [[ -f "${item[path]}/$file_name" ]] ; then
        if [[ "${item[force_update]}" = 'true' ]] ; then
            rm -f "${item[path]}/$file_name"
        else
            msg "Item '${item[path]}/$file_name' exists, skipping"
            status "SKIPPED\t${item[path]}/$file_name"
            return
        fi
    fi

    msg "Downloading from '${item[url]}'"
    if [[ -z "${item[name]}" ]] ; then
        wget --content-disposition --directory-prefix="${item[path]}" --timestamping ${item[url]}
        wget_result=$?
    else
        wget --content-disposition --output-document="${item[path]}/$file_name" ${item[url]}
        wget_result=$?
    fi

    if [[ $wget_result -eq 0 ]] ; then
        status "OK\t${item[url]}"
    else
        status "FAILED\t${item[url]}"
    fi
}


function test_item() {
    local file_name

    validate_item
    if [ ${item[invalid]} = 'true' ] ; then
        return
    fi

    if [[ -z "${item[name]}" ]] ; then
        file_name=$(basename ${item[url]})
    else
        file_name=${item[name]}
    fi

    if [[ ! -f "${item[path]}/$file_name" ]] ; then
        if [[ "${item[mandatory]}" = 'true' ]] ; then
            status "NOT_FOUND\t${item[path]}/$file_name"
        else
            status "WARNING\t${item[path]}/$file_name"
        fi
    fi
}


function process_section() {
    if [[ "$section" = 'DEFAULT' ]]; then
        return
    fi

    case $action in
        'download_items')
            download_item
        ;;
        'test_items')
            test_item
        ;;
        'print')
            print_item
        ;;
    esac
}


function process_config() {

    local config_file="$1"
    shift

    args=("$@")
    action="${args[0]}"

    declare -A item

    rm -f $status_file

    if [[ ! -f "$config_file" ]]; then
        die "Config file '$config_file' not found!"
    fi

    line_number=0
    section=''
    while IFS='=' read -r key value
    do
        line_number=$(($line_number + 1))

        if [ -z "$key" ]; then
            continue
        fi

        if [[ "$key" =~ ^# ]]; then
            continue
        fi

        if [[ "$key" =~ \[.*\] ]] ; then
            key=${key#*[}
            key=${key%]*}

            if [ -n "$section" ] ; then
                process_section
            fi

            section=$key
            item[name]=''
            item[path]=''
            item[url]=''
            item[mandatory]='false'
            item[skip]='false'
            item[invalid]='false'
            item[force]='false'
            item[image_type]=''

            continue
        fi

        key=$(trim $key)
        value=$(trim $value)

        if [[ "$section" = 'DEFAULT' ]]; then
            eval "${key}=${value}"
        fi

        #echo "'$action' '$section' '$key' '$value'"
        case $action in
            'get')
                if [[ "$section" = "${args[1]}" && "$key" = "${args[2]}" ]]; then
                    eval "echo ${value}"
                fi
                continue
            ;;
            'export')
                if [[ "$section" = 'DEFAULT' ]]; then
                    eval "export $key"
                fi
                continue
            ;;
        esac

        if [[ "$section" = 'DEFAULT' ]]; then
            continue
        fi

        if [[ "${item[$key]+true}" = 'true' ]]; then
            # if array key exists
            case $key in
                'path'|'image_type')
                    eval "item[$key]=${value}"
                ;;
                *)
                    item[$key]=$value
                ;;
            esac
        else
            echo "Unexpected item '$key' in section '$section'"
            exit 1
        fi

    done < $config_file
    process_section


    if [[ "$action" = 'download' ]] ; then
        if grep -q 'FAILED' $status_file ; then
            cat << EOF

ERROR:
- One or more errors occured while downloading the files
********************************************************

$(grep 'FAILED' $status_file)

********************************************************
EOF
            exit 1
        fi

        exit 0
    fi


    if [[ $action = 'test' ]] ; then
        if grep -q 'WARNING' $status_file ; then
            cat << EOF

WARNING:
- One or more non-mandatory files not found
*******************************************

$(grep 'WARNING' $status_file)

*******************************************
EOF
        fi

        if grep -q 'NOT_FOUND' $status_file ; then
            cat << EOF

ERROR:
- One or more mandatory files not found
***************************************

$(grep 'NOT_FOUND' $status_file)

***************************************
EOF
            exit 1
        fi

        exit 0
    fi
}

#-------------------------------------------------------------------------------
