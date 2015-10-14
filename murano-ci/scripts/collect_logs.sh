#!/bin/bash

DISTRO_BASED_ON=${DISTRO_BASED_ON:-ubuntu}

set +o errexit

dst="${WORKSPACE}/artifacts"

# Copy devstack logs:
# * sleep for 1 minute to give devstack's log collector a chance to write all logs into files
sleep 20

mkdir -p "${dst}/devstack/"

pushd "${STACK_HOME}/log"
for log_file in $(IFS=$'\n'; find ./ -type l); do
    cp "$log_file" "${dst}/devstack/"
done
popd

# Copy murano logs from /var/log/murano
if [[ -d "/var/log/murano" ]]; then
    mkdir -p "${dst}/murano"
    sudo cp -Rv /var/log/murano/* "${dst}/murano/"
fi

# Copy murano config files
mkdir -p "${dst}/etc/murano"
sudo cp -Rv /etc/murano/* "${dst}/etc/murano/"

mkdir -p "${dst}/etc/horizon"
sudo cp -Rv /opt/stack/horizon/openstack_dashboard/settings.py "${dst}/etc/horizon/"
sudo cp -Rv /opt/stack/horizon/openstack_dashboard/local/local_settings.py "${dst}/etc/horizon/"

# Copy Apache logs
if [ "$DISTRO_BASED_ON" == "redhat" ]; then
    if [[ -d "/var/log/httpd" ]]; then
        mkdir -p "${dst}/apache"
        sudo cp -Rv /var/log/httpd/* "${dst}/apache/"
    fi
else
    if [[ -d "/var/log/apache2" ]]; then
        mkdir -p "${dst}/apache"
        sudo cp -Rv /var/log/apache2/* "${dst}/apache/"
    fi
fi

# return error catching back
set -o errexit

sudo chown -R jenkins:jenkins "${dst}"
