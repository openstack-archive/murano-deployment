#!/bin/bash
cd $WORKSPACE


sudo ntpdate pool.ntp.org
sudo su -c 'echo "ServerName localhost" >> /etc/apache2/apache2.conf'

python murano-ci/infra/RabbitMQ.py -username murano$BUILD_NUMBER -vhostname murano$BUILD_NUMBER

sudo bash -x murano-ci/infra/deploy_component_new.sh $ZUUL_REF murano-api noop $ZUUL_URL
sudo bash -x murano-ci/infra/configure_api.sh 172.18.124.203 5672 False murano$BUILD_NUMBER

git clone https://github.com/Mirantis/tempest
cd tempest
git checkout platform/stable/havana
sudo pip install .

cp etc/tempest.conf.sample etc/tempest.conf
sed -i "s/uri = http:\/\/127.0.0.1:5000\/v2.0\//uri = http:\/\/172.18.124.203:5000\/v2.0\//" etc/tempest.conf
sed -i "s/admin_username = admin/admin_username = AutotestUser/" etc/tempest.conf
sed -i "s/admin_password = secret/admin_password = swordfish/" etc/tempest.conf
sed -i "s/admin_tenant_name = admin/admin_tenant_name = AutotestProject/" etc/tempest.conf
sed -i "s/murano_url = http:\/\/127.0.0.1:8082/murano_url = http:\/\/127.0.0.1:8082\/v1/" etc/tempest.conf
sed -i "s/murano = false/murano = true/" etc/tempest.conf

nosetests -s -v --with-xunit --xunit-file=test_report$BUILD_NUMBER.xml tempest/api/murano/test_murano_envs.py tempest/api/murano/test_murano_services.py tempest/api/murano/test_murano_sessions.py
if [ $? == 1 ]
then
   python $WORKSPACE/murano-ci/infra/RabbitMQ.py -username murano$BUILD_NUMBER -vhostname murano$BUILD_NUMBER -action delete
   exit 1
fi

python $WORKSPACE/murano-ci/infra/RabbitMQ.py -username murano$BUILD_NUMBER -vhostname murano$BUILD_NUMBER -action delete
mv test_report$BUILD_NUMBER.xml ..
