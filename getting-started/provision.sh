#!/bin/bash -x

function log {
   echo "$@" | tee --append ~/provision.log
}

apt-get install -y git

if [ ! -f '/vagrant/lab-binding.rc' ] ; then
	echo "File '/vagrant/lab-binding.rc' not found!"
	exit 1
fi

mkdir /etc/murano-deployment

if [ ! -f '/etc/murano-deployment/lab-binding.rc' ] ; then
    cp /vagrant/lab-binding.rc /etc/murano-deployment
fi

mkdir /opt/git

cd /opt/git

log "Cloning the 'murano-deployment' repository ..."
git clone https://github.com/stackforge/murano-deployment.git >> ~/provision.log

cd murano-deployment
#git checkout -b release-0.2 origin/release-0.2

log "Installing pip ..."
apt-get install python-setuptools >> ~/provision.log
easy_install pip                  >> ~/provision.log

cd devbox-scripts
log "Installing murano prerequisites ..."
./murano-git-install.sh prerequisites >> ~/provision.log

log "Installing murano components ..."
./murano-git-install.sh install       >> ~/provision.log

