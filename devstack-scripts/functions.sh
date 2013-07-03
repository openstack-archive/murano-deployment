#!/bin/bash


type -t die
if [ $? -ne 0 ] ; then
    function die() {
        _log "===== Script interrupted ====="
        echo "$@"
        echo ''
        exit 1
    }
fi



function bool() {
    local var=${1:-}
    local default=${2:-}

    var="${var,,}"                          # do lowercase
    var="${var#"${var%%[![:space:]]*}"}"    # remove leading whitespace characters
    var="${var%"${var##*[![:space:]]}"}"    # remove trailing whitespace characters

    if [[ -z $var ]] ; then
        if [[ -z $default ]] ; then
            echo 'False'
            return
        else
            echo $default
            return
        fi
    fi

    if [[ "$var" =~ ^[[:digit:]]+$ ]] ; then
        if [[ $var == 0 ]] ; then
            echo 'False'
            return
        else
            echo 'True'
            return
        fi
    fi

    if [[ "$var"  =~ ^[[:alpha:]]+$ ]] ; then
        if [[ "$var" == 'true' ]] ; then
            echo 'True'
            return
        else
            echo 'False'
            return
        fi
    fi
    
    echo 'False'
    return
}



function restart_service {
    while [[ -n ${1:-} ]] ; do
        local err=0
        sudo service $1 status || err=1
        if [[ $err -eq 0 ]] ; then
            _log "Restarting service '$1' ..."
            sudo service $1 restart
        else
            _log "WARNING: Unable to get status of the service '$1'"
        fi
        shift
    done
}



function move_mysql_data_to_ramdrive {
    echo "Moving MySQL database to tmpfs ..."

    # Moving MySQL database to tmpfs
    #-------------------------------
    if [[ $( bool "$MYSQL_DB_TMPFS" 'True' ) == "True" ]] ; then
        #die_if_not_set MYSQL_DB_TMPFS_SIZE
        mount_dir=/var/lib/mysql
        sudo -s << EOF
echo "Stopping MySQL Server"
service mysql stop
    
umount $mount_dir
mount -t tmpfs -o size=$MYSQL_DB_TMPFS_SIZE tmpfs $mount_dir
chmod 700 $mount_dir
chown mysql:mysql $mount_dir

mysql_install_db

/usr/bin/mysqld_safe --skip-grant-tables &
sleep 5
EOF

        sudo mysql << EOF
FLUSH PRIVILEGES;
SET PASSWORD FOR 'root'@'localhost' = PASSWORD('swordfish');
SET PASSWORD FOR 'root'@'127.0.0.1' = PASSWORD('swordfish');
EOF

        sudo -s << EOF
killall mysqld
sleep 5

echo "Starting MySQL Server"
service mysql start
EOF
    else
        _log "MYSQL_DB_TMPFS = '$MYSQL_DB_TMPFS'"
    fi
    #-------------------------------
}


function move_nova_cache_to_ramdrive {
    # Moving nova images cache to tmpfs
    #----------------------------------
    if [[ $(bool "$NOVA_CACHE_TMPFS" 'True') == "True" ]] ; then
        #die_if_not_set NOVA_CACHE_TMPFS_SIZE
        mount_dir=/opt/stack/data/nova/instances
        sudo -s << EOF
umount $mount_dir
mount -t tmpfs -o size=$NOVA_CACHE_TMPFS_SIZE tmpfs $mount_dir
chmod 775 $mount_dir
chown stack:stack $mount_dir
EOF
    else
        _log "NOVA_CACHE_TMPFS = '$NOVA_CACHE_TMPFS'"
    fi
    #----------------------------------
}


function check_if_folder_exists {
    if [[ ! -d "$1" ]] ; then
        _log "Folder '$1' not exists!"
        return 1
    fi
    return 0
}


function validate_install_mode {
    case $INSTALL_MODE in
        'standalone')
            check_if_folder_exists "$SCRIPTS_DIR/etc/standalone" || exit
        ;;
        'multihost')
            check_if_folder_exists "$SCRIPTS_DIR/etc/controller" || exit
            check_if_folder_exists "$SCRIPTS_DIR/etc/compute" || exit
        ;;
        'controller')
            check_if_folder_exists "$SCRIPTS_DIR/etc/controller" || exit
        ;;
        'compute')
            check_if_folder_exists "$SCRIPTS_DIR/etc/compute" || exit
        ;;
        *)
            _log "Wrong install mode '$INSTALL_MODE'"
            exit
        ;;
    esac
}


function update_devstack_local_files {
    local install_mode=${1:-}
    local config_name=${2:-'devstack'}
    
    [[ -z "$install_mode" ]] \
        && die "Install mode for update_devstack_localrc not provided!"

    # Replacing devstack's localrc config
    #------------------------------------
    local file="/etc/devstack-scripts/$install_mode/$config_name.devstack.localrc"
    if [[ -f $file ]] ; then
        rm -f "$DEVSTACK_DIR/localrc"
        cp $file "$DEVSTACK_DIR/localrc"
    else
        die "File '$file' not found!"
    fi
    #------------------------------------

    # Replacing devstack's local.sh config
    #------------------------------------
    local file="/etc/devstack-scripts/$install_mode/$config_name.devstack.local.sh"
    if [[ -f $file ]] ; then
        rm -f "$DEVSTACK_DIR/local.sh"
        cp $file "$DEVSTACK_DIR/local.sh"
        chmod +x "$DEVSTACK_DIR/local.sh"
    else
        die "File '$file' not found!"
    fi
    #------------------------------------
}


function _log {
    echo "[$(hostname)] $@"
}


