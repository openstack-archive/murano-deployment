#!/bin/bash
cd $WORKSPACE

export DISPLAY=:22
screen -dmS display sudo Xvfb -fp /usr/share/fonts/X11/misc/ :22 -screen 0 1024x768x16
sudo iptables -F
sudo ntpdate pool.ntp.org
sudo su -c 'echo "ServerName localhost" >> /etc/apache2/apache2.conf'
ADDR=`ifconfig eth0| awk -F ' *|:' '/inet addr/{print $4}'`

git clone https://git.openstack.org/stackforge/murano-tests

python murano-ci/infra/RabbitMQ.py -username murano$BUILD_NUMBER -vhostname murano$BUILD_NUMBER

sudo bash -x murano-ci/infra/deploy_component_new.sh $ZUUL_REF murano-dashboard 172.18.11.4 $ZUUL_URL
sudo bash -x murano-ci/infra/configure_api.sh 172.18.11.4 5672 False murano$BUILD_NUMBER

cd murano-tests/muranodashboard-tests
sed "s%keystone_url = http://127.0.0.1:5000/v2.0/%keystone_url = http://172.18.11.4:5000/v2.0/%g" -i config/config_file.conf
sed "s%horizon_url = http://127.0.0.1/horizon%horizon_url = http://$ADDR/horizon%g" -i config/config_file.conf
sed "s%murano_url = http://127.0.0.1:8082%murano_url = http://$ADDR:8082%g" -i config/config_file.conf

nosetests sanity_check --nologcapture
if [ $? == 1 ]
then
   python $WORKSPACE/murano-ci/infra/RabbitMQ.py -username murano$BUILD_NUMBER -vhostname murano$BUILD_NUMBER -action delete
   exit 1
fi
python $WORKSPACE/murano-ci/infra/RabbitMQ.py -username murano$BUILD_NUMBER -vhostname murano$BUILD_NUMBER -action delete
