#!/bin/bash

source ./functions.sh

# If there are parameter from command line then call parser function
if [[ -n "$1" ]]; then
    process_config "$CONFIG_FILE" "$@"
fi
