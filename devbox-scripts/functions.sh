#!/bin/bash

TRACE_DEPTH=${TRACE_OFFSET:-0}
TRACE_STACK=${TRACE_NAME:-''}
LOG_FILE=/tmp/murano-obs-install.log

SCREEN_LOGDIR=${SCREEN_LOGDIR:-/tmp}

MURANO_PACKAGES_DEB='murano-common python-muranoclient murano-api murano-conductor murano-repository murano-dashboard'

# Devstack functions
#-------------------

# Prints backtrace info
# filename:lineno:function
function backtrace {
    local level=$1
    local deep=$((${#BASH_SOURCE[@]} - 1))
    echo "[Call Trace]"
    while [ $level -le $deep ]; do
        echo "${BASH_SOURCE[$deep]}:${BASH_LINENO[$deep-1]}:${FUNCNAME[$deep-1]}"
        deep=$((deep - 1))
    done
}


# Prints line number and "message" then exits
# die $LINENO "message"
function die() {
    local exitcode=$?
    set +o xtrace
    local line=$1; shift
    if [ $exitcode == 0 ]; then
        exitcode=1
    fi
    backtrace 2
    err $line "$*"
    exit $exitcode
}


# Checks an environment variable is not set or has length 0 OR if the
# exit code is non-zero and prints "message" and exits
# NOTE: env-var is the variable name without a '$'
# die_if_not_set $LINENO env-var "message"
function die_if_not_set() {
    local exitcode=$?
    FXTRACE=$(set +o | grep xtrace)
    set +o xtrace
    local line=$1; shift
    local evar=$1; shift
    if ! is_set $evar || [ $exitcode != 0 ]; then
        die $line "$*"
    fi
    $FXTRACE
}


# Prints line number and "message" in error format
# err $LINENO "message"
function err() {
    local exitcode=$?
    errXTRACE=$(set +o | grep xtrace)
    set +o xtrace
    local msg="[ERROR] ${BASH_SOURCE[2]}:$1 $2"
    echo $msg 1>&2;
    if [[ -n ${SCREEN_LOGDIR} ]]; then
        echo $msg >> "${SCREEN_LOGDIR}/error.log"
    fi
    $errXTRACE
    return $exitcode
}


# Test if the named environment variable is set and not zero length
# is_set env-var
function is_set() {
    local var=\$"$1"
    eval "[ -n \"$var\" ]" # For ex.: sh -c "[ -n \"$var\" ]" would be better, but several exercises depends on this
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


# Normalize config values to True or False
# Accepts as False: 0 no No NO false False FALSE
# Accepts as True: 1 yes Yes YES true True TRUE
# VAR=$(trueorfalse default-value test-value)
function trueorfalse() {
    local default=$1
    local testval=$2

    [[ -z "$testval" ]] && { echo "$default"; return; }
    [[ "0 no No NO false False FALSE" =~ "$testval" ]] && { echo "False"; return; }
    [[ "1 yes Yes YES true True TRUE" =~ "$testval" ]] && { echo "True"; return; }
    echo "$default"
}

#-------------------


function log {
    l='          '
    printf "%s%s\n" "${l:0:$TRACE_DEPTH}" "$@" | tee --append $LOG_FILE
}

function echo_() {
    l='          '
    printf "%s%s\n" "${l:0:$TRACE_DEPTH}" "$@" | tee --append $LOG_FILE
}

function echo_h1() {
    l='**********'
    printf "%s%s\n" "${l:0:$TRACE_DEPTH}" "$@" | tee --append $LOG_FILE
}

function echo_h2() {
    l='=========='
    printf "%s%s\n" "${l:0:$TRACE_DEPTH}" "$@" | tee --append $LOG_FILE
}

function echo_h3() {
    l='----------'
    printf "%s%s\n" "${l:0:$TRACE_DEPTH}" "$@" | tee --append $LOG_FILE
}

function trace_in() {
    l='----------'
    # Trace in
    TRACE_STACK="$TRACE_NAME $1"
    shift
    TRACE_DEPTH=$(( TRACE_DEPTH + 1 ))
    echo_h3 " >>> ${TRACE_STACK##* }($@)"
}

function trace_out() {
    l='----------'
    # Trace out
    echo_h3 " <<< ${TRACE_STACK##* }()"
    TRACE_STACK=${TRACE_STACK% *}
    TRACE_DEPTH=$(( TRACE_DEPTH - 1 ))
}


function pip_install() {
    trace_in pip_install "$@"

    log "** Installing pip packages '$@'"

    if [ -f "$pip_version_requirements" ]; then
        pip install --upgrade -r "$pip_version_requirements" "$@"
    else
        pip install --upgrade "$@"
    fi

    trace_out
}


function upgrade_pip() {
    trace_in upgrade_pip "$@"

    log "** Upgrading pip to '$1'"

    case "$1" in
        '1.4')
            echo 'pip<1.5' > "$pip_version_requirements"
            pip install --upgrade -r "$pip_version_requirements"
            rm /usr/bin/pip
            ln -s /usr/local/bin/pip /usr/bin/pip
        ;;
    esac

    trace_out
}


function replace {
    sed -i "s/$1/$2/g" "$3"
}


function add_obs_repo() {
    trace_in add_obs_repo "$@"

    local request_id=${1:-''}
    local list_file
    local url

    #OBS_REPO_PREFIX=ubuntu-fuel-4.1-stable
    #OBS_URL_PREFIX=http://osci-obs.vm.mirantis.net:82
    #OBS_LOCAL_REPO=/opt/repo

    if [[ ! -d "${OBS_LOCAL_REPO}" ]]; then
        mkdir -p ${OBS_LOCAL_REPO}
    fi

    if [[ ! -f "/etc/apt/preferences.d/local_repo.pref" ]]; then
        cat << EOF > "/etc/apt/preferences.d/local_repo.pref"
Package: *
Pin: origin ""
Pin-Priority: 550
EOF
fi

    # URL example
    # http://osci-obs.vm.mirantis.net:82/ubuntu-fuel-4.1-stable-10041/ubuntu

    if [[ -z "${request_id}" ]]; then
        list_file=/etc/apt/sources.list.d/${OBS_REPO_PREFIX}.list
        url=${OBS_URL_PREFIX}/${OBS_REPO_PREFIX}/ubuntu

        wget ${url}/Release.key -O - | apt-key add -

        echo "deb ${url}/ ./" > "${list_file}"
    else
        list_file=/etc/apt/sources.list.d/obs-request-${request_id}.list
        url=${OBS_URL_PREFIX}/${OBS_REPO_PREFIX}-${request_id}/ubuntu

        local d=${OBS_LOCAL_REPO}/${OBS_REPO_PREFIX}-${request_id}
        if [[ -d "$d" ]]; then
            #rm -rf "$d"
            echo_ "Folder '$d' alreasy exists, skipping"
        else
            wget -r -np -nH -A *.deb,*.dsc,*.gz,*.key ${url}/ -P ${OBS_LOCAL_REPO}

            url=${OBS_LOCAL_REPO}/${OBS_REPO_PREFIX}-${request_id}/ubuntu
            
            apt-key add ${url}/Release.key

            echo "deb file:${url} ./" > "${list_file}"
        fi
    fi

    #apt-get update
    trace_out
}


function remove_obs_repo() {
    trace_in remove_obs_repo "$@"
    trace_out
}


function clean_obs_repo() {
    trace_in clean_obs_repo "$@"

    local id i d

    for i in $(ls /etc/apt/sources.list.d); do
        if [[ $i =~ obs-request-([[:digit:]]+)\.list ]]; then
            id=${BASH_REMATCH[1]}
            if [[ " $OBS_REQUEST_IDS " =~ " ${id} " ]]; then
                echo_h2 "${id} in ${OBS_REQUEST_IDS}"
            else
                d=${OBS_LOCAL_REPO}/${OBS_REPO_PREFIX}-${id}
                if [[ -d "$d" ]]; then
                    rm -rf "$d"
                fi
                rm -f /etc/apt/sources.list.d/obs-request-${id}
            fi
        fi
    done

    trace_out
}


function install_murano_prereqs() {
    trace_in install_murano_prereqs "$@"

    apt-get install -y openstack-dashboard
    dpkg --purge openstack-dashboard-ubuntu-theme
    service apache2 restart

    trace_out
}


function database_connection_url() {
    local db="$1"
    echo "sqlite://${MURANO_CACHE_DIR}/${db}.sqlite"
}


function configure_dashboard_local_settings() {
    cat << EOF >> "$HORIZON_LOCAL_CONFIG"

#MURANO_CONFIG_SECTION_BEGIN
#-------------------------------------------------------------------------------

OPENSTACK_HOST = '$MURANO_AUTH_HOST'
EOF

    if [[ $(trueorfalse Flase $MURANO_SSL_ENABLED) = 'True' ]]; then
        cat << EOF >> "$HORIZON_LOCAL_CONFIG"
OPENSTACK_SSL_NO_VERIFY = True
OPENSTACK_KEYSTONE_URL = "https://%s:5000/v2.0" % OPENSTACK_HOST
OPENSTACK_KEYSTONE_ADMIN_URL = "https://%s:35357/v2.0" % OPENSTACK_HOST
QUANTUM_URL = "https://%s" % OPENSTACK_HOST
EOF
    else
        cat << EOF >> "$HORIZON_LOCAL_CONFIG"
OPENSTACK_KEYSTONE_URL = "http://%s:5000/v2.0" % OPENSTACK_HOST
OPENSTACK_KEYSTONE_ADMIN_URL = "http://%s:35357/v2.0" % OPENSTACK_HOST
QUANTUM_URL = "http://%s" % OPENSTACK_HOST
ALLOWED_HOSTS = '*'
EOF
    fi

        cat << EOF >> "$HORIZON_LOCAL_CONFIG"

#-------------------------------------------------------------------------------
#MURANO_CONFIG_SECTION_END

EOF

}


# configure_murano() - Set config files, create data dirs, etc
function configure_murano {

    # Murano Api Configuration
    #-------------------------
    echo_ "Configuring file '$MURANO_API_CONF'"

    iniset "$MURANO_API_CONF" 'DEFAULT' 'Debug' "$(trueorfalse False $MURANO_DEBUG)"
    iniset "$MURANO_API_CONF" 'DEFAULT' 'Verbose' "$(trueorfalse False $MURANO_VERBOSE)"

    iniset "$MURANO_API_CONF" 'DEFAULT' 'log_file' "$MURANO_LOG_DIR/murano-api.log"

    iniset "$MURANO_API_CONF" 'database' 'connection' "$(database_connection_url murano)"

    iniset "$MURANO_API_CONF" 'rabbitmq' 'host' "$MURANO_RABBIT_HOST"
    iniset "$MURANO_API_CONF" 'rabbitmq' 'port' "$MURANO_RABBIT_PORT"
    iniset "$MURANO_API_CONF" 'rabbitmq' 'login' "$MURANO_RABBIT_LOGIN"
    iniset "$MURANO_API_CONF" 'rabbitmq' 'password' "$MURANO_RABBIT_PASSWORD"
    iniset "$MURANO_API_CONF" 'rabbitmq' 'virtual_host' "$MURANO_RABBIT_VHOST"
    iniset "$MURANO_API_CONF" 'rabbitmq' 'ssl' "False"

    iniset "$MURANO_API_CONF" 'keystone_authtoken' 'auth_host' "$MURANO_AUTH_HOST"
    iniset "$MURANO_API_CONF" 'keystone_authtoken' 'admin_user' "$ADMIN_USERNAME"
    iniset "$MURANO_API_CONF" 'keystone_authtoken' 'admin_password' "$ADMIN_PASSWORD"
    iniset "$MURANO_API_CONF" 'keystone_authtoken' 'signing_dir' "$MURANO_API_SIGNING_DIR"

    if [[ $(trueorfalse False $MURANO_SSL_ENABLED) = 'True' ]]; then
        generate_sample_certificate "$MURANO_CONF_DIR" 'server'

        iniset "$MURANO_API_CONF" 'ssl' 'cert_file' "$MURANO_CONF_DIR/server.crt"
        iniset "$MURANO_API_CONF" 'ssl' 'key_file' "$MURANO_CONF_DIR/server.key"

        iniset "$MURANO_API_CONF" 'rabbitmq' 'ssl' "True"

        iniset "$MURANO_API_CONF" 'keystone_authtoken' 'auth_protocol' 'https'
    fi
    #-------------------------


    # Murano Conductor Configuration
    #-------------------------------
    echo_h2 "Configuring file '$MURANO_CONDUCTOR_CONF'"

    iniset "$MURANO_CONDUCTOR_CONF" 'DEFAULT' 'Debug' "$(trueorfalse False $MURANO_DEBUG)"
    iniset "$MURANO_CONDUCTOR_CONF" 'DEFAULT' 'Verbose' "$(trueorfalse False $MURANO_VERBOSE)"

    iniset "$MURANO_CONDUCTOR_CONF" 'DEFAULT' 'log_file' "$MURANO_LOG_DIR/murano-conductor.log"
    iniset "$MURANO_CONDUCTOR_CONF" 'DEFAULT' 'data_dir' "$MURANO_CONDUCTOR_CACHE"
    iniset "$MURANO_CONDUCTOR_CONF" 'DEFAULT' 'init_scripts_dir' "$MURANO_CONF_DIR/init-scripts"
    iniset "$MURANO_CONDUCTOR_CONF" 'DEFAULT' 'agent_config_dir' "$MURANO_CONF_DIR/agent-config"

    iniset "$MURANO_CONDUCTOR_CONF" 'keystone' 'auth_url' "$MURANO_AUTH_URL"

    iniset "$MURANO_CONDUCTOR_CONF" 'rabbitmq' 'host' "$MURANO_RABBIT_HOST"
    iniset "$MURANO_CONDUCTOR_CONF" 'rabbitmq' 'port' "$MURANO_RABBIT_PORT"
    iniset "$MURANO_CONDUCTOR_CONF" 'rabbitmq' 'login' "$MURANO_RABBIT_LOGIN"
    iniset "$MURANO_CONDUCTOR_CONF" 'rabbitmq' 'password' "$MURANO_RABBIT_PASSWORD"
    iniset "$MURANO_CONDUCTOR_CONF" 'rabbitmq' 'virtual_host' "$MURANO_RABBIT_VHOST"

    iniset "$MURANO_CONDUCTOR_CONF" 'rabbitmq' 'ssl' "False"

    if [[ $(trueorfalse False $MURANO_SSL_ENABLED) = 'True' ]]; then
        local ssl_insecure='True'
        # If any variable is not empty then ssl_insecure = False
        if [[ -n "${MURANO_SSL_CA_FILE}${MURANO_SSL_CERT_FILE}${MURANO_SSL_KEY_FILE}" ]]; then
            ssl_insecure='False'
        fi

        iniset "$MURANO_CONDUCTOR_CONF" 'keystone' 'ca_file' "$MURANO_SSL_CA_FILE"
        iniset "$MURANO_CONDUCTOR_CONF" 'keystone' 'cert_file' "$MURANO_SSL_CERT_FILE"
        iniset "$MURANO_CONDUCTOR_CONF" 'keystone' 'key_file' "$MURANO_SSL_KEY_FILE"
        iniset "$MURANO_CONDUCTOR_CONF" 'keystone' 'insecure' "$ssl_insecure"

        iniset "$MURANO_CONDUCTOR_CONF" 'heat' 'ca_file' "$MURANO_SSL_CA_FILE"
        iniset "$MURANO_CONDUCTOR_CONF" 'heat' 'cert_file' "$MURANO_SSL_CERT_FILE"
        iniset "$MURANO_CONDUCTOR_CONF" 'heat' 'key_file' "$MURANO_SSL_KEY_FILE"
        iniset "$MURANO_CONDUCTOR_CONF" 'heat' 'insecure' "$ssl_insecure"

        iniset "$MURANO_CONDUCTOR_CONF" 'rabbitmq' 'ssl' "True"
    fi
    #-------------------------------


    # Murano Repository Configuration
    #--------------------------------
    echo_h2 "Configuring file '$MURANO_REPOSITORY_CONF'"

    iniset "$MURANO_REPOSITORY_CONF" 'DEFAULT' 'Debug' "$(trueorfalse False $MURANO_DEBUG)"
    iniset "$MURANO_REPOSITORY_CONF" 'DEFAULT' 'Verbose' "$(trueorfalse False $MURANO_VERBOSE)"

    iniset "$MURANO_REPOSITORY_CONF" 'DEFAULT' 'log_file' "$MURANO_LOG_DIR/murano-repository.log"
    iniset "$MURANO_REPOSITORY_CONF" 'DEFAULT' 'data_dir' "$MURANO_REPOSITORY_CACHE"
    iniset "$MURANO_REPOSITORY_CONF" 'DEFAULT' 'cache_dir' "$MURANO_REPOSITORY_CACHE"

    iniset "$MURANO_REPOSITORY_CONF" 'keystone' 'auth_host' "$MURANO_AUTH_HOST"
    iniset "$MURANO_REPOSITORY_CONF" 'keystone' 'admin_user' "$ADMIN_USERNAME"
    iniset "$MURANO_REPOSITORY_CONF" 'keystone' 'admin_password' "$ADMIN_PASSWORD"
    iniset "$MURANO_REPOSITORY_CONF" 'keystone' 'signing_dir' "$MURANO_REPOSITORY_SIGNING_DIR"
    #--------------------------------


    # PowerShell init script
    #-----------------------
    echo_h2 "Configuring PowerShell init scripts"

    if [[ -n "$MURANO_FILE_SHARE_HOST" ]]; then
        replace '%MURANO_SERVER_ADDRESS%' "$MURANO_FILE_SHARE_HOST" "$MURANO_CONF_DIR/init-scripts/init.ps1"
    fi
    #-----------------------


    # Templates Configuration
    #------------------------
    echo_h2 "Configuring templates"

    if [[ -n "$MURANO_RABBIT_HOST_ALT" ]]; then
        replace '%RABBITMQ_HOST%' "$MURANO_RABBIT_HOST_ALT" "$MURANO_CONF_DIR/agent-config/Default.template"
        replace '%RABBITMQ_HOST%' "$MURANO_RABBIT_HOST_ALT" "$MURANO_CONF_DIR/agent-config/Demo.template"
        replace '%RABBITMQ_HOST%' "$MURANO_RABBIT_HOST_ALT" "$MURANO_CONF_DIR/agent-config/Linux.template"
    fi

    if [[ $(trueorfalse False $MURANO_SSL_ENABLED) = 'True' ]]; then
        replace '%RABBITMQ_SSL%' 'true' "$MURANO_CONF_DIR/agent-config/Default.template"
        replace '%RABBITMQ_SSL%' 'true' "$MURANO_CONF_DIR/agent-config/Demo.template"
        replace '%RABBITMQ_SSL%' 'true' "$MURANO_CONF_DIR/agent-config/Linux.template"
    fi
    #------------------------


    # Create dirs / fix permissions
    #------------------------------
    chmod -R 755 "$MURANO_CACHE_DIR"

    mkdir -p "$MURANO_DASHBOARD_CACHE"
    chown -R $HORIZON_USER:$HORIZON_GROUP "$MURANO_DASHBOARD_CACHE"
    #------------------------------


    # Configuring Openstaсk Dashboard
    #--------------------------------
    configure_dashboard_local_settings

    /usr/bin/modify-horizon-config.sh uninstall
    MURANO_DASHBOARD_DB_DIR=$MURANO_DASHBOARD_DB_DIR MURANO_AUTH_HOST=$MURANO_AUTH_HOST /usr/bin/modify-horizon-config.sh install

    sudo -u $HORIZON_USER python "$HORIZON_DIR/manage.py" collectstatic --noinput
    sudo -u $HORIZON_USER python "$HORIZON_DIR/manage.py" syncdb --noinput
    #--------------------------------

    # Restart Apache
    #---------------
    service apache2 restart
    #---------------
}


function install_murano_packages() {
    trace_in install_murano_packages "$@"

    apt-get --yes --force-yes install $MURANO_PACKAGES_DEB

    trace_out
}


function purge_murano_packages() {
    trace_in purge_murano_packages "$@"

    local pkg
    for pkg in $MURANO_PACKAGES_DEB; do
        apt-get --yes purge $pkg
    done

    trace_out
}


function restart_murano() {
    service openstack-murano-api restart
    service openstack-murano-conductor restart
    service openstack-murano-repository restart
}

