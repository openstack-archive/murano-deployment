#!/bin/bash

box_name='precise64'
box_url='https://www.dropbox.com/sh/f8w9xsowbr7rglj/uHiFONsUKO/precise64.box'

if [ -f "$box_name.box" ] ; then
    echo "*** Box file found in current directory. Skipping download."
else
    echo "*** Downloading box '$box_name' from '$box_url' ..."
    wget $box_url -O $box_name.box
fi

echo "*** Adding the box to vagrant ..."
vagrant box add $box_name $box_name.box

echo "*** Running vagrant ..."
vagrant up
# VAGRANT_LOG=debug is a workaround for the bug
#    https://github.com/mitchellh/vagrant/issues/516

echo "*** Now you can open the link 'http://127.0.0.1:8080' in your browser."
