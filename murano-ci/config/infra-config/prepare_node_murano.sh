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


sudo mkdir $GIT_PATH
cd $GIT_PATH
#sudo pip install pip==1.4
sudo pip  install --upgrade
sudo pip install nose selenium testtools testresources unittest2 pyrabbit==1.0.1
sudo git clone https://github.com/stackforge/murano
sudo git clone https://github.com/stackforge/murano-dashboard
sudo git clone https://github.com/stackforge/python-muranoclient
if [ -e /etc/os-release ]; then  
   sudo wget http://sourceforge.net/projects/ubuntuzilla/files/mozilla/apt/pool/main/f/firefox-mozilla-build/firefox-mozilla-build_27.0-0ubuntu1_amd64.deb/download -O firefox27.deb
   sudo dpkg -i firefox27.deb
   sudo rm -f firefox27.deb
   sudo apt-get install python-dev python-mysqldb libxml2-dev libxslt1-dev libffi-dev wget git make gcc -y #mysql-client memcached apache2 libapache2-mod-wsgi python-pip python-setuptools unzip ntpdate xvfb -y
   sudo apt-get install ntpdate xvfb zip rabbitmq-server -y
   sudo /usr/lib/rabbitmq/bin/rabbitmq-plugins enable rabbitmq_management
#   cd $GIT_PATH/murano && sudo bash setup.sh install
#   cd $GIT_PATH/murano-dashboard && sudo pip install -U -r requirements.txt
   sudo service mysql stop
#   if [ $? == 1 ]
#   then
#      sudo apt-get install openstack-dashboard -y
#      sudo bash setup.sh install
#   fi
   apt-get install libffi-dev python-openssl python-crypto -y
   sudo bash $GIT_PATH/python-muranoclient/setup.sh uninstall
   sudo bash $GIT_PATH/python-muranoclient/setup.sh install
else
   echo "
   . /etc/bashrc
   . /etc/profile
   " > /home/jenkins/.bashrc
   chown jenkins:jenkins /home/jenkins/.bashrc
   yum remove -y puppetlabs-release-6-10.noarch
#   cd $GIT_PATH/murano-dashboard && bash setup.sh install
#   cd $GIT_PATH/murano && bash setup.sh install
   yum install -y Xvfb zip rabbitmq-server
   /usr/lib/rabbitmq/bin/rabbitmq-plugins enable rabbitmq_management
   rm -f /etc/udev/rules.d/70-persistent-net.rules
   chkconfig mysqld on
   service mysqld stop
   wget http://ftp.mozilla.org/pub/mozilla.org/firefox/releases/27.0/linux-x86_64/en-US/firefox-27.0.tar.bz2
   tar -xjvf firefox-27.0.tar.bz2
   mv firefox /opt/firefox27
   ln -s /opt/firefox27/firefox /usr/bin/firefox
   yum install libffi-devel pyOpenSSL openssl-devel python-crypto m2crypto libffi -y
   sudo bash $GIT_PATH/python-muranoclient/setup-centos.sh uninstall
   sudo bash $GIT_PATH/python-muranoclient/setup-centos.sh install
fi

#cd $GIT_PATH/python-muranoclient && sudo pip install .

#sudo su -c '/usr/bin/yes | pip uninstall python-keystoneclient'
#sudo pip install python-keystoneclient


sync
sleep 10
