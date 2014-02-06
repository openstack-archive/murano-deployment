#!/bin/bash

func=${1:-''}
shift


# Import local configuration
if [ -f '/etc/murano-deployment/obs-config.local' ]; then
    source /etc/murano-deployment/obs-config.local
fi
 
source ./functions.sh
source ./muranorc
source ./murano.defaults


if [[ -n "$func" ]]; then
	$func "$@"
fi

