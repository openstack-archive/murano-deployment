#!/bin/bash

sed -i "s/#amqp_durable_queues=false/amqp_durable_queues=false/" /etc/murano/murano.conf
sed -i "s/#amqp_auto_delete=false/amqp_auto_delete=false/" /etc/murano/murano.conf
sed -i "s/#rabbit_host=localhost/rabbit_host=$1/" /etc/murano/murano.conf
sed -i "s/#rabbit_port=5672/rabbit_port=$2/"  /etc/murano/murano.conf
sed -i 's/#\\(rabbit_hosts=.*\\)/\\1/' /etc/murano/murano.conf
sed -i "s/#rabbit_use_ssl=false/rabbit_use_ssl=$3/" /etc/murano/murano.conf
sed -i "s/#rabbit_userid=guest/rabbit_userid=$4/" /etc/murano/murano.conf
sed -i "s/#rabbit_password=guest/rabbit_password=swordfish/" /etc/murano/murano.conf
sed -i "s/#rabbit_virtual_host=\\//rabbit_virtual_host=$4/" /etc/murano/murano.conf
sed -i "s/#rabbit_retry_interval=1/rabbit_retry_interval=1/" /etc/murano/murano.conf
sed -i "s/#rabbit_retry_backoff=2/rabbit_retry_backoff=2/" /etc/murano/murano.conf
sed -i "s/#rabbit_max_retries=0/rabbit_max_retries=0/" /etc/murano/murano.conf
sed -i "s/#rabbit_ha_queues=false/rabbit_ha_queues=false/" /etc/murano/murano.conf
sed -i "s/auth_host = 127.0.0.1/auth_host = $1/" /etc/murano/murano.conf
sed -i "s/connection = sqlite:\\/\\/\\/\\/etc\\/murano\\/murano-api.sqlite/connection = mysql:\\/\\/murano:swordfish@localhost:3306\\/murano/" /etc/murano/murano.conf
sed -i "s/auth_url = http:\\/\\/localhost:5000\\/v2.0/auth_url = http:\\/\\/$1:5000\\/v2.0/" /etc/murano/murano.conf

sudo -u murano murano-manage --config-file /etc/murano/murano.conf db-sync
service murano-api restart
service murano-engine restart
