#!/bin/bash

#set -o xtrace

mode=${1:-'install'}

curr_dir=$(cd $(dirname "$0") && pwd)

murano_components="murano-api murano-conductor python-muranoclient murano-dashboard"
murano_services="murano-api murano-conductor"
murano_config_files='/etc/murano-api/murano-api.conf /etc/murano-api/murano-api-paste.ini /etc/murano-conductor/conductor.conf /etc/murano-conductor/conductor-paste.ini /etc/openstack-dashboard/local_settings'


git_prefix="https://github.com/stackforge"
git_clone_root='/opt/git'

os_version=''

# "/etc/murano-deployment/lab-binding.rc" sample
##################################################
#LAB_HOST=''
#
#AUTH_URL="http://$LAB_HOST:5000/v2.0"
#
#ADMIN_USER=''
#ADMIN_PASSWORD=''
#
#RABBITMQ_LOGIN=''
#RABBITMQ_PASSWORD=''
#RABBITMQ_VHOST='/'
##################################################


# Helper funtions
#-------------------------------------------------
function die {
	printf "\n==============================\n"
	printf "$@"
	printf "\n==============================\n"
	exit 1
}

function log {
	printf "$@\n"
}

function iniset {
	local section=$1
	local option=$2
	local value=$3
	local file=$4

	if [ -z $section ] ; then
		sed -i -e "s/^\($option[ \t]*=[ \t]*\).*$/\1$value/" "$file"
	else
		sed -i -e "/^\[$section\]/,/^\[.*\]/ s|^\($option[ \t]*=[ \t]*\).*$|\1$value|" "$file"
	fi
}
#-------------------------------------------------


# Workflow functions
#-------------------------------------------------
function install_murano {
	configuration_required='false'
	for config_file in $murano_config_files ; do
		if [ ! -f "$config_file" ] ; then
			log "! Required config file '$config_file' not exists. Murano should be configured before start."
			configuration_required='true'
		fi
	done

	for app_name in $murano_components ; do
		log "* Working with '$app_name'"

		git_repo="$git_prefix/$app_name.git"
		git_clone_dir="$git_clone_root/$app_name"

		if [ ! -d "$git_clone_dir" ] ; then
			git clone $git_repo $git_clone_dir || die "Unable to clone repository '$git_repo'"
			up_to_date='false'
		else
			cd "$git_clone_dir"
			git reset --hard
			git clean -fd
			git remote update
			git checkout master

			rev_on_local=$(git rev-list --max-count=1 master)
			rev_on_origin=$(git rev-list --max-count=1 origin/master)

			if [ "$rev_on_local" == "$rev_on_origin" ] ; then
				up_to_date='true'
			else
				git pull origin master
				up_to_date='false'
			fi
		fi

		if [ "$up_to_date" == 'false' ] ; then
			chmod +x "$git_clone_dir"/setup*.sh
			
			log "* Uninstalling '$app_name' ..."
			case $os_version in
				'CentOS')
					"$git_clone_dir"/setup-centos.sh uninstall
				;;
				'Ubuntu')
					"$git_clone_dir"/setup.sh uninstall
				;;
			esac
			
			sleep 2
			
			log "* Installing '$app_name' ..."
			case $os_version in
				'CentOS')
					"$git_clone_dir"/setup-centos.sh install
				;;
				'Ubuntu')
					"$git_clone_dir"/setup.sh install
				;;
			esac
		fi
	done


	if [ "$configuration_required" == 'true' ] ; then
		log "One or several configuraiton files were not found before installation was launched."
		configure_murano
	fi

	restart_murano
}


function configure_murano {
	log "** Configuring Murano ..."

	if [ ! -f '/etc/murano-deployment/lab-binding.rc' ] ; then
		log "Create '/etc/murano-dashboard/lab-binding.rc' or configure services individually."
		die "Murano components require configuration."
	fi

	source /etc/murano-deployment/lab-binding.rc

	for config_file in $murano_config_files ; do
		log "** Configuring file '$config_file'"

		if [ ! -f "$config_file" ] ; then
			cp "$config_file.sample" "$config_file"
		fi

		case "$config_file" in
			'/etc/murano-api/murano-api.conf')
				iniset 'rabbitmq' 'host' "$LAB_HOST" "$config_file"
				iniset 'rabbitmq' 'login' "$RABBITMQ_LOGIN" "$config_file"
				iniset 'rabbitmq' 'password' "$RABBITMQ_PASSWORD" "$config_file"
				iniset 'rabbitmq' 'virtual_host' "$RABBITMQ_VHOST" "$config_file"
			;;
			'/etc/murano-api/murano-api-paste.ini')
				iniset 'filter:authtoken' 'auth_host' "$LAB_HOST" "$config_file"
				iniset 'filter:authtoken' 'admin_user' "$ADMIN_USER" "$config_file"
				iniset 'filter:authtoken' 'admin_password' "$ADMIN_PASSWORD" "$config_file"
			;;
			'/etc/murano-conductor/conductor.conf')
				iniset 'heat' 'auth_url' "$AUTH_URL" "$config_file"
				iniset 'rabbitmq' 'host' "$LAB_HOST" "$config_file"
				iniset 'rabbitmq' 'login' "$RABBITMQ_LOGIN" "$config_file"
				iniset 'rabbitmq' 'password' "$RABBITMQ_PASSWORD" "$config_file"
				iniset 'rabbitmq' 'virtual_host' "$RABBITMQ_VHOST" "$config_file"
			;;
			'/etc/openstack-dashboard/local_settings')
				iniset '' 'OPENSTACK_HOST' "$LAB_HOST" "$config_file"
			;;
		esac
	done
}


function restart_murano {
	for service_name in $murano_services ; do
		stop "$service_name"
		start "$service_name"
	done
}
#-------------------------------------------------


mkdir -p $git_clone_root

if [ -f /etc/redhat-release ] ; then
	os_version=$(cat /etc/redhat-release | cut -d ' ' -f 1)
fi

if [ -f /etc/lsb-release ] ; then
	os_version=$(cat /etc/lsb-release | grep DISTRIB_ID | cut -d '=' -f 2)
fi

if [ -z $os_version ] ; then
	die "Unable to determine OS version. Exiting." 
else
	log "* OS version is '$os_version'"
fi


log "* Running mode '$mode'"
case $mode in
	'install')
		install_murano
	;;
	'configure')
		configure_murano
	;;
	'restart')
		restart_murano
	;;
esac
