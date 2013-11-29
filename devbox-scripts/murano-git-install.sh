#!/bin/bash

#set -o xtrace

mode=${1:-'help'}

curr_dir=$(cd $(dirname "$0") && pwd)

murano_components='murano-api murano-conductor murano-dashboard murano-repository'

murano_services='murano-api murano-conductor murano-repository'

murano_config_files='/etc/murano/murano-api.conf
 /etc/murano/murano-api-paste.ini
 /etc/murano/conductor.conf
 /etc/murano/conductor-paste.ini
 /etc/murano/murano-repository.conf
 /etc/murano/init-scripts/init.ps1
 /etc/murano/agent-config/Default.template
 /usr/share/openstack-dashboard/openstack_dashboard/settings.py'


git_prefix="https://github.com/stackforge"
git_clone_root='/opt/git'

os_version=''

# Helper funtions
#-------------------------------------------------
function die {
    printf "\n==============================\n"
    printf "$@"
    printf "\n==============================\n"
    exit 1
}

function log {
    printf "%s\n" "$@" | tee --append /tmp/murano-git-install.log
}

function iniset {
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

function replace {
    local what_replace=$1
    local replace_with=$2
    local file=$3

    sed -i "s/$what_replace/$replace_with/g" "$file"
}

function generate_sample_certificate {
    local location=$1
    local cert_name=$2

    local old_pwd=$(pwd)
    cd $location

    openssl genrsa -des3 -passout pass:x -out "$cert_name.pass.key" 2048
    openssl rsa -passin pass:x -in "$cert_name.pass.key" -out "$cert_name.key"
    rm "$cert_name.pass.key"

    openssl req -new \
     -subj "/C=RU" \
     -subj "/ST=Center" \
     -subj "/L=Moscow" \
     -subj "/O=Mirantis" \
     -subj "/OU=Murano" \
     -subj "/CN=murano" \
     -subj "/emailAddress=murano-all@mirantis.com" \
     -key "$cert_name.key" -out "$cert_name.csr"

    openssl x509 -req -days 365 \
      -in "$cert_name.csr" \
      -signkey "$cert_name.key" \
      -out "$cert_name.crt"

    cd $old_pwd
}

function get_distro_name()
{
    local dist_name
    if [[ -r '/etc/release' ]]; then
        dist_name=$(head -1 /etc/release | sed 's/ *\([[^0-9]]*\) [0-9].*/\1/')
    elif [[ -r '/etc/arch-release' ]]; then
        dist_name="ArchLinux"
    elif [[ -r '/etc/gentoo-release' ]]; then
        dist_name='Gentoo'
    elif [[ -r '/etc/fedora-release' ]]; then
        dist_name='Fedora'
    elif [[ -r '/etc/centos-release' ]]; then
        dist_name='CentOS'
    elif [[ -r '/etc/redhat-release' ]]; then
        dist_name='Redhat'
    elif [[ -r '/etc/SuSE-release' ]]; then
        dist_name='SuSE'
    elif [[ -r '/etc/lsb-release' ]]; then
        source /etc/lsb-release
        [[ "$DISTRIB_ID" ]] && dist_name="$DISTRIB_ID"
    fi
    echo "$dist_name"
}

#-------------------------------------------------


# Workflow functions
#-------------------------------------------------
function install_prerequisites {
    case $os_version in
        'CentOS')
            log "** Installing additional software sources ..."
            # GRIZZLY
            #yum install -y 'http://rdo.fedorapeople.org/openstack/openstack-grizzly/rdo-release-grizzly.rpm'
            # HAVANA
            yum install -y 'http://rdo.fedorapeople.org/openstack-havana/rdo-release-havana.rpm'
            yum install -y 'http://mirror.us.leaseweb.net/epel/6/x86_64/epel-release-6-8.noarch.rpm'

            log "** Updating system ..."
            yum update -y

            log "** Upgrading pip ..."
            pip install --upgrade pip
            #rm /usr/bin/pip
            #ln -s /usr/local/bin/pip /usr/bin/pip

            log "** Installing OpenStack dashboard ..."
            yum install make gcc memcached httpd python-memcached mod_wsgi openstack-dashboard python-netaddr.noarch --assumeyes

            log "** Disabling firewall ..."
            service iptables stop
            chkconfig iptables off

            log "** Disabling SELinux ..."
            setenforce permissive
            iniset '' 'SELINUX' 'permissive' '/etc/selinux/config'
        ;;
        'Ubuntu')
            log "** Installing additional software sources ..."
            # GRIZZLY
            #echo 'deb http://ubuntu-cloud.archive.canonical.com/ubuntu precise-updates/grizzly main' > /etc/apt/sources.list.d/grizzly.list
            #apt-get install -y ubuntu-cloud-keyring
            # HAVANA
            apt-get install -y python-software-properties
            add-apt-repository -y cloud-archive:havana

            log "** Updating system ..."
            apt-get update -y
            apt-get upgrade -y

            log "** Installing additional packages ..."
            apt-get install -y node-less
            apt-get install -y python-pip

            log "** Upgrading pip ..."
            pip install --upgrade pip
#            rm /usr/bin/pip
#            ln -s /usr/local/bin/pip /usr/bin/pip

            log "** Upgrading pbr ..."
            pip install --upgrade pbr

            log "** Installing OpenStack dashboard ..."
            apt-get install -y memcached apache2 libapache2-mod-wsgi openstack-dashboard

            log "** Removing Ubuntu Dashboard Theme ..."
            dpkg --purge openstack-dashboard-ubuntu-theme

            log "** Restarting Apache server ..."
            service apache2 restart
        ;;
    esac
}


function fetch_murano_apps {
    RETURN=''

    for app_name in $murano_components ; do
        log ''
        log ''
        log "*** Working with '$app_name'"

        git_repo="$git_prefix/$app_name.git"
        git_clone_dir="$git_clone_root/$app_name"

        case $app_name in
            'murano-api')
                REMOTE_BRANCH=${BRANCH_MURANO_API:-$BRANCH_NAME}
            ;;
            'murano-conductor')
                REMOTE_BRANCH=${BRANCH_MURANO_CONDUCTOR:-$BRANCH_NAME}
            ;;
            'python-muranoclient')
                REMOTE_BRANCH=${BRANCH_MURANO_CLIENT:-$BRANCH_NAME}
            ;;
            'murano-dashboard')
                REMOTE_BRANCH=${BRANCH_MURANO_DASHBOARD:-$BRANCH_NAME}
            ;;
            'murano-repository')
                REMOTE_BRANCH=${BRANCH_MURANO_REPOSITORY:-$BRANCH_NAME}
            ;;
            *)
                REMOTE_BRANCH=$BRANCH_NAME
            ;;
        esac

        local do_checkout=''
        if [ -d "$git_clone_dir" ] ; then
            cd "$git_clone_dir"
            git reset --hard
            git clean -fd
            git remote update || die "'git remote update' failed for '$git_repo'"

            rev_on_local=$(git rev-list --max-count=1 HEAD)
            if [[ "$REMOTE_BRANCH" =~ ^refs ]] ; then
                git fetch "$git_repo" "$REMOTE_BRANCH"
                rev_on_origin=$(git rev-list --max-count=1 FETCH_HEAD)
            else
                rev_on_origin=$(git rev-list --max-count=1 origin/$REMOTE_BRANCH)
            fi

            log "* Revision on local  = $rev_on_local"
            log "* Revision on origin = $rev_on_origin"

            if [[ "$rev_on_local" != "$rev_on_origin" ]] ; then
                do_checkout=$app_name
            fi
        else
            git clone $git_repo $git_clone_dir || die "Unable to clone repository '$git_repo'"
            cd "$git_clone_dir"
            do_checkout=$app_name
        fi

        if [ -z $do_checkout ] ; then
            log "* '$app_name' is up-to-date."
            log "----- ----- ----- ----- -----"
            log "(git status):"
            git status
            log "***** ***** ***** ***** *****"
            log "(git log -1):"
            git --no-pager log -1
            log "===== ===== ===== ===== ====="
        else
            if [[ "$REMOTE_BRANCH" =~ ^refs ]] ; then
                git fetch "$git_repo" "$REMOTE_BRANCH" && git checkout FETCH_HEAD
            else
                if [ -n "$(git branch | grep $REMOTE_BRANCH)" ] ; then
                    log "* branch '$REMOTE_BRANCH' found locally, updating ..."
                    git checkout $REMOTE_BRANCH
                else
                    log "* branch '$REMOTE_BRANCH' not found locally, fetching ..."
                    git checkout -b $REMOTE_BRANCH origin/$REMOTE_BRANCH
                fi
                git pull
            fi

            log "* Switched to '$REMOTE_BRANCH':"
            log "----- ----- ----- ----- -----"
            log "(git log -1):"
            git --no-pager log -1
            log "===== ===== ===== ===== ====="

            RETURN="$RETURN $app_name"
        fi
    done
}


function install_murano_apps {
    local apps_list="$@"

    log "** Installing Murano components '$apps_list'..."
    for app_name in $apps_list ; do
        log "** Installing '$app_name' ..."

        git_clone_dir="$git_clone_root/$app_name"
        chmod +x $git_clone_dir/setup*.sh

        case $os_version in
            'CentOS')
                "$git_clone_dir"/setup-centos.sh install
            ;;
            'Ubuntu')
                "$git_clone_dir"/setup.sh install
            ;;
        esac

    done
}


function uninstall_murano_apps {
    local apps_list="$@"

    log "** Uninstalling Murano components '$apps_list'..."
    for app_name in $apps_list ; do
        log "** Uninstalling '$app_name' ..."

        git_clone_dir="$git_clone_root/$app_name"
        chmod +x $git_clone_dir/setup*.sh

        case $os_version in
            'CentOS')
                "$git_clone_dir"/setup-centos.sh uninstall
            ;;
            'Ubuntu')
                "$git_clone_dir"/setup.sh uninstall
            ;;
        esac

        case $app_name in
            'murano-api')
                rm -rf /etc/$app_name
            ;;
            'murano-conductor')
                rm -rf /etc/$app_name
            ;;
            'murano-repository')
                rm -rf /etc/$app_name
            ;;
        esac
    done
}


function configure_murano {
    log "** Configuring Murano ..."

    for config_file in $murano_config_files ; do
        log "** Configuring file '$config_file'"

        if [ ! -f "$config_file" ] ; then
            cp "$config_file.sample" "$config_file"
        fi

        case "$config_file" in
            '/etc/murano/murano-api.conf')
                iniset 'DEFAULT' 'log_file' '/var/log/murano/murano-api.log' "$config_file"
                iniset 'rabbitmq' 'host' "$RABBITMQ_HOST" "$config_file"
                iniset 'rabbitmq' 'port' "$RABBITMQ_PORT" "$config_file"
                iniset 'rabbitmq' 'login' "$RABBITMQ_LOGIN" "$config_file"
                iniset 'rabbitmq' 'password' "$RABBITMQ_PASSWORD" "$config_file"
                iniset 'rabbitmq' 'virtual_host' "$RABBITMQ_VHOST" "$config_file"
                iniset 'rabbitmq' 'ssl' "False" "$config_file"
                iniset 'keystone_authtoken' 'auth_host' "$LAB_HOST" "$config_file"
                iniset 'keystone_authtoken' 'admin_user' "$ADMIN_USER" "$config_file"
                iniset 'keystone_authtoken' 'admin_password' "$ADMIN_PASSWORD" "$config_file"
            ;;
            '/etc/murano/murano-repository.conf')
                iniset 'DEFAULT' 'log_file' '/var/log/murano/murano-repository.log' "$config_file"
                iniset 'keystone' 'auth_host' "$LAB_HOST" "$config_file"
                iniset 'keystone' 'admin_user' "$ADMIN_USER" "$config_file"
                iniset 'keystone' 'admin_password' "$ADMIN_PASSWORD" "$config_file"
            ;;
            '/etc/murano/conductor.conf')
                iniset 'DEFAULT' 'log_file' '/var/log/murano/murano-conductor.log' "$config_file"
		iniset 'DEFAULT' 'init_scripts_dir' '/etc/murano/init-scripts' "$config_file"
		iniset 'DEFAULT' 'agent_config_dir' '/etc/murano/agent-config' "$config_file"
                iniset 'keystone' 'auth_url' "$AUTH_URL" "$config_file"
                iniset 'rabbitmq' 'host' "$RABBITMQ_HOST" "$config_file"
                iniset 'rabbitmq' 'port' "$RABBITMQ_PORT" "$config_file"
                iniset 'rabbitmq' 'login' "$RABBITMQ_LOGIN" "$config_file"
                iniset 'rabbitmq' 'password' "$RABBITMQ_PASSWORD" "$config_file"
                iniset 'rabbitmq' 'virtual_host' "$RABBITMQ_VHOST" "$config_file"
                iniset 'rabbitmq' 'ssl' "False" "$config_file"
            ;;
            '/etc/openstack-dashboard/local_settings')
                iniset '' 'OPENSTACK_HOST' "'$LAB_HOST'" "$config_file"
                iniset '' 'ALLOWED_HOSTS' "'*'" "$config_file"
            ;;
            '/etc/openstack-dashboard/local_settings.py')
                iniset '' 'OPENSTACK_HOST' "'$LAB_HOST'" "$config_file"
                iniset '' 'ALLOWED_HOSTS' "'*'" "$config_file"
            ;;
            '/etc/murano/init-scripts/init.ps1')
                [ -n "$FILE_SHARE_HOST" ] && \
                  replace '%MURANO_SERVER_ADDRESS%' "$FILE_SHARE_HOST" "$config_file"
            ;;
            '/etc/murano/agent-config/Default.template')
                [ -n "$RABBITMQ_HOST_ALT" ] && \
                  replace '%RABBITMQ_HOST%' "$RABBITMQ_HOST_ALT" "$config_file"
            ;;
        esac

        if [ "$SSL_ENABLED" = 'true' ] ; then
            case "$config_file" in
                '/etc/murano/murano-api.conf')
                    generate_sample_certificate '/etc/murano' 'server'
                    iniset 'ssl' 'cert_file' '/etc/murano/server.crt' "$config_file"
                    iniset 'ssl' 'key_file' '/etc/murano/server.key' "$config_file"
                    iniset 'rabbitmq' 'ssl' "True" "$config_file"
                    iniset 'keystone_authtoken' 'auth_protocol' 'https' "$config_file"
                ;;
                '/etc/murano/conductor.conf')
                    local ssl_insecure='True'
                    # If any variable is not empty then ssl_insecure = False
                    if [ -n "${SSL_CA_FILE}${SSL_CERT_FILE}${SSL_KEY_FILE}" ] ; then
                        ssl_insecure='False'
                    fi

                    iniset 'keystone' 'ca_file' "$SSL_CA_FILE" "$config_file"
                    iniset 'keystone' 'cert_file' "$SSL_CERT_FILE" "$config_file"
                    iniset 'keystone' 'key_file' "$SSL_KEY_FILE" "$config_file"
                    iniset 'keystone' 'insecure' "$ssl_insecure" "$config_file"

                    iniset 'heat' 'ca_file' "$SSL_CA_FILE" "$config_file"
                    iniset 'heat' 'cert_file' "$SSL_CERT_FILE" "$config_file"
                    iniset 'heat' 'key_file' "$SSL_KEY_FILE" "$config_file"
                    iniset 'heat' 'insecure' "$ssl_insecure" "$config_file"

                    iniset 'rabbitmq' 'ssl' "True" "$config_file"
                ;;
                '/etc/murano/agent-config/Default.template')
                    replace '%RABBITMQ_SSL%' 'true' "$config_file"
                ;;
                '/usr/share/openstack-dashboard/openstack_dashboard/settings.py')
                    echo '' >> "$config_file"
                    echo "MURANO_API_INSECURE = True" >> "$config_file"
                    echo "MURANO_API_URL = 'https://localhost:8082'" >> "$config_file"
                ;;
                '/etc/openstack-dashboard/local_settings'|'/etc/openstack-dashboard/local_settings.py')
                    cat << 'EOF' >> "$config_file"

#murano-git-install-block-start
OPENSTACK_SSL_NO_VERIFY = True
OPENSTACK_KEYSTONE_URL = "https://%s:5000/v2.0" % OPENSTACK_HOST
OPENSTACK_KEYSTONE_ADMIN_URL = "https://%s:35357/v2.0" % OPENSTACK_HOST
QUANTUM_URL = "https://%s" % OPENSTACK_HOST
#murano-git-install-block-end
EOF
                ;;
            esac
        fi
    done
}


function restart_murano {
    for service_name in $murano_services ; do
        log "** Restarting '$service_name'"
        stop "$service_name"
        start "$service_name"
    done

    log "** Restarting 'Apache'"
    case $os_version in
        'CentOS')
            service httpd restart
        ;;
        'Ubuntu')
            service apache2 restart
        ;;
    esac
}
#-------------------------------------------------


if [[ $mode =~ '?'|'help'|'-h'|'--help' ]] ; then
    cat << EOF

The following options are awailable:
   * help          - show help. This is a default action.
   * prerequisites - install prerequisites for Murano (OpenStack dashboard and other packages)
   * install       - install and configure Murano components. Please be sure that you have prerequisites installed first.
   * reinstall     - unisntall and then install all Murano components.
   * uninstall     - uninstall Murano components.
   * update        - fetch changes and reinstall components changed.
   * configure     - configure Murano components.
   * restart       - restart Murano components and Apache server

EOF
    exit
fi


mkdir -p $git_clone_root

os_version=$(get_distro_name)

if [ -z $os_version ] ; then
    die "Unable to determine OS version. Exiting."
else
    log "* OS version is '$os_version'"
fi


case $os_version in
    'CentOS')
        murano_config_files="$murano_config_files /etc/openstack-dashboard/local_settings"
    ;;
    'Ubuntu')
        murano_config_files="$murano_config_files /etc/openstack-dashboard/local_settings.py"
    ;;
    *)
    die "Sorry your OS version is not supported yet. Try Centos or Ubuntu."
    ;;
esac


configuration_required=''
for config_file in $murano_config_files ; do
    if [ ! -f "$config_file" ] ; then
        log "! Required config file '$config_file' not exists. Murano should be configured before start."
        configuration_required="$configuration_required $config_file"
    fi
done


devbox_config='/etc/murano-deployment/lab-binding.rc'

if [ ! -f "$devbox_config" ] ; then
    mkdir '/etc/murano-deployment'

    cat << "EOF" > $devbox_config
# Vi / Vim notes
# * Press 'i' to enter INSERT mode
# * Edit the file
# * Press <ESC>, then type ':wq' to (w)rite changes and (q)uit editor.

LAB_HOST=''

ADMIN_USER=''
ADMIN_PASSWORD=''

RABBITMQ_LOGIN=''
RABBITMQ_PASSWORD=''
RABBITMQ_VHOST=''
RABBITMQ_PORT=''
#RABBITMQ_HOST=''
#RABBITMQ_HOST_ALT=''

#FILE_SHARE_HOST=''

BRANCH_NAME='master'

# Only 'true' or 'false' values are allowed!
SSL_ENABLED='false'
SSL_CA_FILE=''
SSL_CERT_FILE=''
SSL_KEY_FILE=''

#BRANCH_MURANO_API=''
#BRANCH_MURANO_DASHBOARD=''
#BRANCH_MURANO_CLIENT=''
#BRANCH_MURANO_CONDUCTOR=''
#BRANCH_MURANO_REPOSITORY=''

#-------------------------------------------------------------------------------

AUTH_PROTO=http
if [ "$SSL_ENABLED" = 'true' ] ; then
    AUTH_PROTO=https
fi

AUTH_URL="$AUTH_PROTO://$LAB_HOST:5000/v2.0"

RABBITMQ_HOST=${RABBITMQ_HOST:-$LAB_HOST}

EOF

    log "***** ***** ***** ***** *****"
    log "Now you should configure lab binding settings in"
    log "   $devbox_config"
    log "***** ***** ***** ***** *****"

    printf '\n\n'
    read -p "Press <Enter> to start editing the file in 'vi' ... "

    if [ -f "$devbox_config" ] ; then
        vi "$devbox_config"
    fi
fi

if [ ! -f "$devbox_config" ] ; then
    die "Configuration file '$devbox_config' not found."
fi

source "$devbox_config"

SSL_ENABLED=${SSL_ENABLED:-'false'}


log "* Running mode '$mode'"
case $mode in
    'fetch')
        fetch_murano_apps
    ;;
    'install')
        fetch_murano_apps

        install_murano_apps $murano_components
        configure_murano

        restart_murano
    ;;
    'reinstall')
        fetch_murano_apps

        uninstall_murano_apps $murano_components
        install_murano_apps $murano_components

        configure_murano

        restart_murano
    ;;
    'uninstall')
        uninstall_murano_apps $murano_components
    ;;
    'configure')
        configure_murano

        restart_murano
    ;;
    'prerequisites')
        install_prerequisites
    ;;
    'update')
        fetch_murano_apps
        log ''
        log "List of updated apps:"
        log "***** ***** ***** ***** *****"
        log $RETURN
        log "***** ***** ***** ***** *****"
    ;;
    'upgrade')
        fetch_murano_apps
        apps_list=$RETURN

        if [ -n "$apps_list" ] ; then
            uninstall_murano_apps $apps_list
            install_murano_apps $apps_list

            restart_murano
        fi
    ;;
    'restart')
        restart_murano
    ;;
esac
