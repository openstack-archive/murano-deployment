#!/bin/bash

file="$1"

source ./functions.sh

# Exporting variables from DEFAULT section
process_config "$CONFIG_FILE" 'export'

sed -i -e "
s/%_IMAGE_BUILDER_IP_%/$IMAGE_BUILDER_IP/g
" "$1"
