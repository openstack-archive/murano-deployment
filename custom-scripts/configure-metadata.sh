#!/bin/bash

sed -i 's/^enabled_ssl_apis/#enabled_ssl_apis/' /etc/nova/nova.conf
service nova-api restart
