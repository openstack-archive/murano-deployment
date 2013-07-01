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



# Executing pre-unstack actions
#===============================================================================
_log "* Executing pre-unstack actions ..."

#===============================================================================


# Executing unstack.sh 
#===============================================================================
_log "* Executing stop devstack ..."
$DEVSTACK_DIR/unstack.sh
#===============================================================================


# Executing post-unstack actions
#===============================================================================
_log "* Executing post-unstack actions ..."

# Remove certificates
#--------------------
echo "* Removing old certificate files"
for file in $(sudo find $DEVSTACK_DIR/accrc/ -type f -regex ".+.pem.*") ; do
    echo "Removing file '$file'"
    sudo rm -f "$file"
done
#--------------------


# Remove logs
#------------
echo "* Removing 'devstack' logs ..."
sudo rm -f /opt/stack/log/*


echo "* Removing 'apache2' logs ..."
for file in $(sudo find /var/log/apache2 -type f) ; do
    echo "Removing file '$file'"
    sudo rm -f "$file"
done
#------------


echo "* Stopping all VMs ..."
sudo killall kvm
sleep 2


#echo "* Unmounting ramdrive ..."
#sudo umount /opt/stack/data/nova/instances
#===============================================================================



# Executing stop-murano actions
#===============================================================================
#source $SCRIPTS_DIR/stop-murano.sh no-localrc
#===============================================================================



# Stop installation on compute nodes
#===============================================================================
if [[ "$INSTALL_MODE" == 'multihost' ]] ; then
    _log "* Stopping devstack on compute nodes ..."
    for $__compute_node in $COMPUTE_NODE_LIST ; do
        _log "** Stopping devstack on '$__compute_node' ..."
        ssh stack@$__compute_node $SCRIPTS_DIR/stop-devstack.sh
    done
fi
#===============================================================================

