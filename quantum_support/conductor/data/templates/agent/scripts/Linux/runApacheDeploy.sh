#!/bin/bash
#
function include(){
    curr_dir=$(cd $(dirname "$0") && pwd)
    inc_file_path=$curr_dir/$1
    if [ -f "$inc_file_path" ]; then
        . $inc_file_path
    else
        echo -e "$inc_file_path not found!"
        exit 1
    fi
}
include "common.sh"
# FirewallRules
FW_RULE1='-I INPUT 1 -p tcp -m tcp --dport 443 -j ACCEPT -m comment --comment "by murano, Apache server access on HTTPS port 443"'
FW_RULE2='-I INPUT 1 -p tcp -m tcp --dport 80 -j ACCEPT -m comment --comment "by murano, Apache server access on HTTP port 80"'
APP=''
get_os
[[ $? -ne 0 ]] && exit 1
case $DistroBasedOn in
    "debian")
        APP="apache2"
        ;;
    "redhat")
        APP="httpd"
        ;;
esac
_php=""
if [[ "$1" == "True" ]]; then
    _php="php"
fi
APPS_TO_INSTALL="$APP $_php $FW_BOOT_PKG"
bash installer.sh -p sys -i $APPS_TO_INSTALL
enable_init $APP
service $APP start > /dev/null 2>&1
add_fw_rule $FW_RULE1
add_fw_rule $FW_RULE2
