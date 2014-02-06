#!/bin/bash

declare -A ARGS
ARGS=($@)

# Import local configuration
if [ -f '/etc/murano-deployment/obs-config.local' ]; then
    source /etc/murano-deployment/obs-config.local
fi

source ./functions.sh
source ./muranorc
source ./murano.defaults


# Verify some variables
die_if_not_set $LINENO OBS_URL_PREFIX
die_if_not_set $LINENO OBS_REPO_PREFIX
die_if_not_set $LINENO OBS_LOCAL_REPO


# First, add a repo with all dependencies
add_obs_repo

# Then, remove all packages that are not in OBS_REQUEST_IDS
clean_obs_repo

# Then, add per-requiest repositories
for id in $OBS_REQUEST_IDS; do
    add_obs_repo "$id"
done

# Update cache before actual installation
apt-get update


install_murano_prereqs


purge_murano_packages


install_murano_packages


configure_murano


restart_murano
