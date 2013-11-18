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
FW_RULE1='-I INPUT 1 -p tcp -m tcp --dport 23 -j ACCEPT -m comment --comment "by murano, Telnet server access on port 23"'
APP=''
get_os
[[ $? -ne 0 ]] && exit 1
case $DistroBasedOn in
    "debian")
        APP="telnetd"
        ;;
    "redhat")
        APP="telnet-server"
        ;;
esac
APPS_TO_INSTALL="$APP"
bash installer.sh -p sys -i $APPS_TO_INSTALL
xinetd_tlnt_cfg="/etc/xinetd.d/telnet"
if [ -f "$xinetd_tlnt_cfg" ]; then
    sed -i '/disable.*=/ s/yes/no/' $xinetd_tlnt_cfg
    if [ $? -ne 0 ]; then
        log "can't modify $xinetd_tlnt_cfg"
        exit 1
    fi
else
    log "$APP startup config not found under $xinetd_tlnt_cfg"
fi
#security tty for telnet
setty=/etc/securetty
lines=$(sed -ne '/^pts\/[0-9]/,/^pts\/[0-9]/ =' $setty)
if [ -z "$lines" ]; then
    cat >> $setty << "EOF"
pts/0
pts/1
pts/2
pts/3
pts/4
pts/5
pts/6
pts/7
pts/8
pts/9
EOF
    if [ $? -ne 0 ]; then
        log "Error occured during $setty changing..."
    exit 1
fi
else
    echo "$setty has pts/0-9 options..."
fi
restart_service xinetd
add_fw_rule $FW_RULE1
