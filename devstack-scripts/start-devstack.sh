#!/bin/bash

SCRIPTS_DIR=$( cd $( dirname "$0" ) && pwd )

source $SCRIPTS_DIR/functions.sh

[[ $(whoami) != 'stack' ]] && die "Please run this script as user 'stack'!"


# Parse arguments
#----------------
sopts='m:c:'
lopts='mode:config:'
args=$(getopt -n "$0" -o "$sopts" -l "$lopts" -- "$@")

[ $? -ne 0 ] && die "Wrong arguments passed!"

eval set -- $args

while true ; do
    case "$1" in
        -m|--mode)
            INSTALL_MODE=$2
            shift
        ;;
        -c|--config)
            CONFIG_NAME=$2
            shift
        ;;
        --)
            break
        ;;
    esac
    shift
done
#----------------

# scriptrc MUST be included after arguments are parsed!
source $SCRIPTS_DIR/scriptrc


validate_install_mode


sudo -s << EOF
echo "$INSTALL_MODE" > /etc/devstack-scripts/install_mode
echo "$CONFIG_NAME" > /etc/devstack-scripts/config_name
EOF



# Check environment
#===============================================================================
check_if_folder_exists '/opt/stack'
check_if_folder_exists "$DEVSTACK_DIR"
#===============================================================================



# Update devstack-scripts if multihost
#===============================================================================
if [[ "$INSTALL_MODE" == 'multihost' ]] ; then
    _log "* Copying devstack-scripts to compute nodes ..."
    for __compute_node in $COMPUTE_NODE_LIST ; do
        _log "** Removing devstack-scripts on '$__compute_node' ..."
        ssh stack@$__compute_node rm -rf ~/devstack-scripts
        _log "** Copying devstack-scripts to '$__compute_node' ..."
        scp -r $SCRIPTS_DIR stack@$__compute_node:~/
    done
fi
#===============================================================================



# Execute pre-stack actions
#===============================================================================
_log "* Executing pre-stack actions ..."


if [[ ",standalone,multihost,controller," =~ ,$INSTALL_MODE, ]] ; then
    restart_service dbus rabbitmq-server
fi

if [[ ",standalone,multihost,controller," =~ ,$INSTALL_MODE, ]] ; then
    move_mysql_data_to_ramdrive
fi


# Create devstack log folder
#---------------------------
sudo -s << EOF
mkdir -p $SCREEN_LOGDIR
chown stack:stack $SCREEN_LOGDIR
EOF
#---------------------------


# Update devstack's localrc file
#-------------------------------
case $INSTALL_MODE in
    'standalone')
        update_devstack_local_files 'standalone' "$CONFIG_NAME"
    ;;
    'multihost')
        update_devstack_local_files 'controller' "$CONFIG_NAME"
    ;;
    'controller')
        update_devstack_local_files 'controller' "$CONFIG_NAME"
    ;;
    'compute')
        update_devstack_local_files 'compute' "$CONFIG_NAME"
    ;;
esac
#-------------------------------

#===============================================================================



# Create stack
#===============================================================================
_log "* Starting devstack ..."
$DEVSTACK_DIR/stack.sh

# We need to re-include openrc after running stack.sh
source $DEVSTACK_DIR/openrc admin admin
#===============================================================================



# Execute post-stack actions
#===============================================================================
_log "* Executing post-stack actions ..."

#<FIXME>
if [[ $NETWORK_MODE == 'nova' ]] ; then
    if [[ ',standalone,compute,' =~ ,$INSTALL_MODE, ]] ; then
        _log "Adding iptables rule to allow Internet access from instances..."
        iptables_rule="POSTROUTING -t nat -s $FIXED_RANGE ! -d $FIXED_RANGE -j MASQUERADE"
        sudo iptables -C $iptables_rule
        if [[ $? == 0 ]] ; then
            _log "Iptables rule already exists."
        else
            sudo iptables -A $iptables_rule
        fi
    fi
fi
#</FIXME>

if [[ ',standalone,compute,' =~ ,$INSTALL_MODE, ]] ; then
    _log "Mouting nova cache as a ramdrive"
    move_nova_cache_to_ramdrive
fi


if [[ $INSTALL_MODE == 'compute' ]] ; then
    return
fi


if [[ $NETWORK_MODE == 'quantum' ]] ; then
    quantum net-create Public \
        --tenant-id admin \
        --shared \
        --provider:network_type flat \
        --provider:physical_network Public

    quantum subnet-create \
        --tenant-id admin \
        --allocation-pool start=$LAB_ALLOCATION_START,end=$LAB_ALLOCATION_END \
        --dns-nameserver $LAB_DNS_SERVER_1 \
        --dns-nameserver $LAB_DNS_SERVER_2 \
        Public \
        $LAB_FLAT_RANGE

    quantum port-create \
        --tenant-id admin \
        --device-id network:dhcp \
        --fixed-ip subnet=Public,ip_address=$LAB_ALLOCATION_START \
        Public
fi
#===============================================================================



# Start installation on compute nodes
#===============================================================================
if [[ "$INSTALL_MODE" == 'multihost' ]] ; then
    _log "* Starting devstack on compute nodes ..."
    for __compute_node in $COMPUTE_NODE_LIST ; do
        _log "** Starting devstack on '$__compute_node' ..."
        ssh stack@$__compute_node $SCRIPTS_DIR/start-devstack.sh compute
    done
fi
#===============================================================================

