#!/bin/bash

echo ''
echo 'Getting nwfilter rules'
virsh nwfilter-dumpxml nova-base > /root/nova-base.xml.bak

echo ''
echo 'Updating rule definitions'
cat /root/nova-base.xml.bak | grep -v spoofing > /tmp/nova-base.xml

echo ''
echo 'Updating rules'
virsh nwfilter-define /tmp/nova-base.xml

rm /tmp/nova-base.xml
