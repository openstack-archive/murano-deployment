#!/bin/sh

curr_dir=$(cd $(dirname "$0") && pwd)

murano_components="murano-api murano-conductor python-muranoclient murano-dashboard"
murano_services="murano-api murano-conductor"
murano_config_dirs="/etc/murano-api /etc/murano-conductor /etc/murano-dashboard"
murano_config_files='/etc/murano-api/murano-api.conf /etc/murano-api/murano-api-paste.ini /etc/murano-conductor/conductor.conf /etc/murano-conductor/conductor-paste.ini /etc/openstack-dashboard/local_settings'


git_prefix="https://github.com/stackforge"
git_clone_root='/opt/git'

os_version=''



function die {
	printf "\n==============================\n"
	printf "$@"
	printf "\n==============================\n"
	exit 1
}

function log {
	printf "$@\n"
}



mkdir -p $git_clone_root

if [ -f /etc/redhat-release ] ; then
	os_version=$(cat /etc/redhat-release | cut -d ' ' -f 1)
fi

if [ -f /etc/lsb_release ] ; then
	os_version=$(cat /etc/lsb-release | grep DISTRIB_ID | cut -d '=' -f 2)
fi

if [ -z $os_version ] ; then
	die "Unable to determine OS version. Exiting." 
else
	log "* OS version is '$os_version'"
fi


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
	else
		cd "$git_clone_dir"
		git reset --hard
		git clean -fd
		git remote update
		git checkout master
		git pull origin master
	fi

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
done


if [ "$configuration_required" == 'true' ] ; then
	die "One or several configuraiton files were not found before installation started. Please confugure Murano before start services."
fi


for service_name in $murano_services ; do
	restart "$service_name"
done
