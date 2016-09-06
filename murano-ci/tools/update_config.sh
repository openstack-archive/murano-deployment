#!/bin/bash -e

# backup old layout
cp -r /etc/zuul/layout/* /etc/zuul/layout.bak

# update layout and functions
cat murano-ci/zuul/layout.yaml > /etc/zuul/layout/layout.yaml
cat murano-ci/zuul/openstack_functions.py > /etc/zuul/layout/openstack_functions.py
