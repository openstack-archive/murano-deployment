#!/bin/bash

dst="${WORKSPACE}/artifacts"

mkdir -p "${dst}"

### Add correct Apache log path
DISTRO_BASED_ON=${DISTRO_BASED_ON:-ubuntu}
if [ "$DISTRO_BASED_ON" == "redhat" ]; then
    apache_log_dir="/var/log/httpd"
else
    apache_log_dir="/var/log/apache2"
fi

set +o errexit

# Copy devstack logs:
# * sleep for 1 minute to give devstack's log collector a chance to write all logs into files
sleep 20

mkdir -p "${dst}/devstack/"

pushd "${STACK_HOME}/log"
for log_file in $(IFS=$'\n'; find ./ -type l); do
    cp "$log_file ${dst}/devstack/"
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

# Copy Apache logs
if [[ -d "${apache_log_dir}" ]]; then
    mkdir -p "${dst}/apache"
    sudo cp -Rv ${apache_log_dir}/* "${dst}/apache/"
fi

if [ "$PROJECT_NAME" == 'murano-dashboard' ]; then
    # Copy screenshots for failed tests
    mkdir -p "${dst}/screenshots"
    cp -Rv ${PROJECT_TESTS_DIR}/screenshots/* "${dst}/screenshots/"
fi

# return error catching back
set -o errexit

sudo chown -R jenkins:jenkins "${dst}"
