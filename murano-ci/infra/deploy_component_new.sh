#!/bin/bash

rm -rf /tmp/keystone-signing-muranoapi
rm -rf /tmp/keystone-signing-muranorepository
cd /opt/git/ && rm -rf $2
git clone https://git.openstack.org/stackforge/$2
cd /opt/git/$2
bash setup.sh uninstall > 2.log
git fetch $4/stackforge/$2 $1
git checkout FETCH_HEAD
chown horizon:horizon /var/lib/openstack-dashboard/secret_key
chmod 600 /var/lib/openstack-dashboard/secret_key
bash setup.sh install > old.log
sed -i "s/DEBUG = False/DEBUG = True/" /etc/openstack-dashboard/local_settings.py
sed -i "s/OPENSTACK_HOST = \"127.0.0.1\"/OPENSTACK_HOST = \"$3\"/" /etc/openstack-dashboard/local_settings.py
cd /var/cache/murano-dashboard/ && rm -rf *
service murano-api restart
service murano-engine restart
service apache2 restart

exit
