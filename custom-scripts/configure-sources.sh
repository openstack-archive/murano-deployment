#!/bin/bash

set -o errexit

source ./functions.sh


title "Adding Mirantis Repositories"

#-------------------------------------------------------------------------------

wget http://download.mirantis.com/precise-fuel-grizzly/Mirantis.key -O /tmp/Mirantis.key
apt-key add /tmp/Mirantis.key
rm /tmp/Mirantis.key

cat << EOF > /etc/apt/sources.list.d/mirantis-releases.list
# mirantis-releases
deb http://download.mirantis.com/precise-fuel-grizzly precise main
EOF

#-------------------------------------------------------------------------------

wget http://intel-repo.mirantis.com/ubuntu/gpg.pub -O /tmp/gpg.pub
apt-key add /tmp/gpg.pub
rm /tmp/gpg.pub

cat << EOF > /etc/apt/sources.list.d/intel-cloud-stable.list
# intel-cloud-stable
deb http://intel-repo.mirantis.com/ubuntu/stable precise main
EOF

#-------------------------------------------------------------------------------

echo 'Done'



title "Adding 'archive.gplhost.com' Repository"

#-------------------------------------------------------------------------------

cat << EOF > /etc/apt/sources.list.d/gplhost-archive.list
deb http://archive.gplhost.com/debian grizzly main
deb http://archive.gplhost.com/debian grizzly-backports main
EOF

apt-get --quiet=2 --yes update

apt-get install --quiet=2 --yes --force-yes gplhost-archive-keyring

#-------------------------------------------------------------------------------

echo 'Done'



title "Configuring Package Pinning Preferences"

#-------------------------------------------------------------------------------

cat << EOF > /etc/apt/preferences.d/intel-cloud-stable.pref
# intel-cloud-stable
Package: *
Pin: release o=OpenStack CI
Pin-Priority: 560
EOF

#-------------------------------------------------------------------------------

cat << EOF > /etc/apt/preferences.d/mirantis-releases.pref
# mirantis-releases
Package: *
Pin: release o=Mirantis
Pin-Priority: 530
EOF

#-------------------------------------------------------------------------------

cat << EOF > /etc/apt/preferences.d/ubuntu-packages.pref
Package: *
Pin: release o=Ubuntu
Pin-Priority: 501
EOF

#-------------------------------------------------------------------------------

echo 'Done'



title "Updating Package Information"

apt-get --quiet=2 --yes update

echo 'Done'



title "Upgrading System"

apt-get --quiet=2 --yes upgrade

echo 'Done'
