#!/bin/bash

declare -A ARGS
ARGS=($@)

source ./functions.sh
source ./muranorc


# Import local configuration
if [ -f '/etc/murano-deployment/obs-config.local' ]; then
    source /etc/murano-deployment/obs-config.local
fi


# Verify some variables
die_if_not_set $LINENO OBS_URL_PREFIX
die_if_not_set $LINENO OBS_REPO_PREFIX
die_if_not_set $LINENO OBS_LOCAL_REPO


# Fiest, add a repo with all dependencies
add_obs_repo

# Then, add per-requiest repositories
for id in $OBS_REQUEST_IDS; do
    add_obs_repo "$id"
done

# Update cache before actual installation
apt-get update


purge_murano_packages


install_murano_packages


configure_murano


#init_murano


restart_murano