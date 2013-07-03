#!/bin/bash

scripts_dir=$( cd $( dirname "$0" ) && pwd )

source $scripts_dir/functions.sh

[[ $(whoami) != 'root' ]] && die "Please run this script as user 'root'!"


# Set default values
#-------------------
clean_install=false
drop_config=false
#-------------------


# Parse arguments
#----------------
sopts=''
lopts='clean,drop-config'
args=$(getopt -n "$0" -o "$sopts" -l "$lopts" -- "$@")

[ $? -ne 0 ] && die "Wrong arguments passed!"

eval set -- $args

while true ; do
	case "$1" in
		--clean)
			clean_install=true
		;;
		--drop-config)
			drop_config=true
		;;
		--)
			break
		;;
	esac
	shift
done
#----------------


source $scripts_dir/scriptrc


groupadd stack || true
useradd -g stack -s /bin/bash -m stack || true


echo 'stack ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/stack
chmod 0440 /etc/sudoers.d/stack


if [ $(bool "$clean_install" 'False') == 'True' ] ; then
	rm -rf ~stack/devstack
fi

if [ $(bool "$drop_config" 'False') == 'True' ] ; then
	rm -rf /etc/devstack-scripts
fi


mkdir -p $DEVSTACK_INSTALL_DIR
chown stack:stack $DEVSTACK_INSTALL_DIR


sudo -u stack -s << EOF
cd ~stack
git clone git://github.com/openstack-dev/devstack.git
cd devstack
git checkout $DEVSTACK_BRANCH
echo 'GetOSVersion' > localrc
echo "SCREEN_LOGDIR=$DEVSTACK_INSTALL_DIR/log" >> localrc
EOF


if [ ! -d '/etc/devstack-scripts' ] ; then
	mkdir -p /etc/devstack-scripts
	cp -r $scripts_dir/etc/* /etc/devstack-scripts
fi


cp -n "$scripts_dir/etc/default.devstack-scripts.localrc" "/etc/devstack-scripts/$(hostname).devstack-scripts.localrc"
cp -n "$scripts_dir/etc/standalone/default.devstack.localrc" "/etc/devstack-scripts/standalone/$(hostname).devstack.localrc"

cp "$scripts_dir/etc/standalone/default.devstack.local.sh" "/etc/devstack-scripts/standalone/$(hostname).devstack.local.sh"


chown -R stack /etc/devstack-scripts
