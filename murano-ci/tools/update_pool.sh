#!/bin/bash -e

for i in $(sudo nodepool list | grep cilab | awk -F '|' '{ print $2 }')
do
   sudo nodepool delete $i
   sleep 2
done
