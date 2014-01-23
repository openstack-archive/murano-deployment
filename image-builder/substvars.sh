#!/bin/bash

# subvars.sh - script to substitute multiple variables in various files

file=$1

IMAGE_BUILDER_IP=192.168.122.1

sed -i -e "
s/%_IMAGE_BUILDER_IP_%/$IMAGE_BUILDER_IP/g
" "$1"

