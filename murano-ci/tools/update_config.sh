#!/bin/bash -e

sudo su - zuul -c "cat $WORKSPACE/murano-ci/config/zuul/zuul.conf > /etc/zuul/zuul.conf"
sudo su - zuul -c "cat $WORKSPACE/murano-ci/config/zuul/gearman-logging.conf > /etc/zuul/gearman-logging.conf"
sudo su - zuul -c "cat $WORKSPACE/murano-ci/config/zuul/layout.yaml > /etc/zuul/layout.yaml"
sudo su - zuul -c "cat $WORKSPACE/murano-ci/config/zuul/logging.conf > /etc/zuul/logging.conf"
sudo su - zuul -c "cat $WORKSPACE/murano-ci/config/zuul/openstack_functions.py > /etc/zuul/openstack_functions.py"
sudo service zuul reload

cp $WORKSPACE/murano-ci/tools/update_pool.sh /opt/bin/
