#!/bin/bash
#
# Common functions file
#
function lowercase()
{
    local input=$1
    local retval=$(echo $input | sed -e 's/\(.*\)/\L\1/')
    echo $retval
}
#
function iniset()
{
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
#
function get_os()
{
    local retval=0
    local kernel=$(uname -r)
    local arch=$(uname -m)
    local os=$(uname)
    if [ "${os}" = "Linux" ] ; then
        if [ -f /etc/redhat-release ] ; then
            distro_based_on='RedHat'
            dist=$(cat /etc/redhat-release |sed s/\ release.*//)
            pseudoname=$(cat /etc/redhat-release | sed s/.*\(// | sed s/\)//)
            dist_version=$(cat /etc/redhat-release | sed s/.*release\ // | sed s/\ .*//)
        elif [ -f /etc/SuSE-release ] ; then
            distro_based_on='SuSe'
            pseudoname=$(cat /etc/SuSE-release | tr "\n" ' '| sed s/VERSION.*//)
            dist_version=$(cat /etc/SuSE-release | tr "\n" ' ' | sed s/.*=\ //)
        elif [ -f /etc/debian_version ] ; then
            distro_based_on='Debian'
            dist=$(cat /etc/lsb-release | grep '^DISTRIB_ID' | awk -F=  '{ print $2 }')
            pseudoname=$(cat /etc/lsb-release | grep '^DISTRIB_CODENAME' | awk -F=  '{ print $2 }')
            dist_version=$(cat /etc/lsb-release | grep '^DISTRIB_RELEASE' | awk -F=  '{ print $2 }')
        fi
        if [ -f /etc/UnitedLinux-release ] ; then
            dist="${dist}[$(cat /etc/UnitedLinux-release | tr "\n" ' ' | sed s/VERSION.*//)]"
        fi
        os=$(lowercase $os)
        distro_based_on=$(lowercase $distro_based_on)
        readonly os
        readonly dist
        readonly distro_based_on
        readonly pseudoname
        readonly dist_version
        readonly kernel
        readonly arch
    else
        os=unknown
        readonly os
        echo "Unsupported operating system:\"$os\", sorry!"
        retval=1
    fi
    return $retval
}
#
function shield_slashes()
{
    local input=$1
    local retval=$(echo $input | sed 's/\//\\\//g')
    echo $retval
}