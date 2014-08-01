#!/bin/bash -x

# Copyright (C) 2011-2013 OpenStack Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.
#
# See the License for the specific language governing permissions and
# limitations under the License.

HOSTNAME=$1
SUDO='true'
THIN='true'
PYTHON3='false'
PYPY='false'
ALL_MYSQL_PRIVS='true'
GIT_PATH=/opt/git

./prepare_node.sh "$HOSTNAME" "$SUDO" "$THIN" "$PYTHON3" "$PYPY" "$ALL_MYSQL_PRIVS"

./restrict_memory.sh


sudo mkdir -p $GIT_PATH
cd $GIT_PATH

sudo pip install selenium testtools testresources unittest2

if [ -e /etc/os-release ]; then
    # Prepare Ubuntu node

    wget http://sourceforge.net/projects/ubuntuzilla/files/mozilla/apt/pool/main/f/firefox-mozilla-build/firefox-mozilla-build_27.0-0ubuntu1_amd64.deb/download -O firefox27.deb
    sudo dpkg -i firefox27.deb
    rm -f firefox27.deb

    sudo apt-get update

    sudo apt-get install -y \
        python-nose \
        libpq-dev \
        python-dev \
        libxml2-dev \
        libxslt1-dev \
        libffi-dev \
        make \
        gcc \
        ntpdate \
        zip \
        python-openssl \
        python-crypto

    sudo apt-get install --yes \
        xvfb \
        x11vnc \
        openbox

else
    # Prepare CentOS node

    cat << EOF > /home/jenkins/.bashrc
. /etc/bashrc
. /etc/profile
EOF

    chown jenkins:jenkins /home/jenkins/.bashrc

    yum remove -y puppetlabs-release-6-10.noarch

    yum install -y \
        Xvfb \
        zip

    rm -f /etc/udev/rules.d/70-persistent-net.rules

    wget http://ftp.mozilla.org/pub/mozilla.org/firefox/releases/27.0/linux-x86_64/en-US/firefox-27.0.tar.bz2
    tar -xjvf firefox-27.0.tar.bz2
    sudo mv firefox /opt/firefox27
    sudo ln -s /opt/firefox27/firefox /usr/bin/firefox

    yum install -y \
        libffi-devel \
        pyOpenSSL \
        openssl-devel \
        python-crypto \
        m2crypto \
        libffi
fi

sync
sleep 10

