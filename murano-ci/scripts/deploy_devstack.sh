#!/bin/bash
# Copyright (c) 2015 Mirantis, Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.
#

# Functions
#-------------------------------------------------------------------------------
function git_clone_devstack() {
    local DEVSTACK_BRANCH=${DEVSTACK_BRANCH:=master}
    sudo mkdir -p "${STACK_HOME}"
    sudo chown -R jenkins:jenkins "${STACK_HOME}"
    git clone https://github.com/openstack-dev/devstack "${STACK_HOME}/devstack"

    pushd "${STACK_HOME}/devstack"
    {
    git checkout "${ZUUL_BRANCH}"
    } || {
    # Override devstack branch, if ZUUL_BRANCH doesn't exists on devstack repo
    git checkout "${DEVSTACK_BRANCH}"
    }
    popd
}

function deploy_devstack() {
    local DEVSTACK_BRANCH=${DEVSTACK_BRANCH:=master}
    local git_dir=/opt/git

    sudo mkdir -p "${git_dir}/openstack"
    sudo chown -R jenkins:jenkins "${git_dir}/openstack"
    git clone https://github.com/openstack/murano "${git_dir}/openstack/murano"

    if [ "${ZUUL_PROJECT}" == 'openstack/murano' ]; then
        pushd "${git_dir}/openstack/murano"
        git fetch ${ZUUL_URL}/${ZUUL_PROJECT} ${ZUUL_REF} && git checkout FETCH_HEAD
        popd
    else
        pushd "${git_dir}/openstack/murano"
        {
        git checkout "${ZUUL_BRANCH}"
        } || {
        # Override devstack branch, if ZUUL_BRANCH doesn't exists on devstack repo
        git checkout "${DEVSTACK_BRANCH}"
        }
        popd
    fi


    # NOTE(freerunner): This commit https://review.openstack.org/#/c/233106/2
    # exists only in master branch now. So, we should use libs for liberty
    # branch.
    if [[ ${ZUUL_BRANCH} =~ kilo || ${ZUUL_BRANCH} =~ liberty ]]; then
        cp -Rv ${git_dir}/openstack/murano/contrib/devstack/extras.d/* "${STACK_HOME}/devstack/extras.d/"
        cp -Rv ${git_dir}/openstack/murano/contrib/devstack/lib/* "${STACK_HOME}/devstack/lib/"
        cp -Rv ${git_dir}/openstack/murano/contrib/devstack/files/apts/* "${STACK_HOME}/devstack/files/apts/"
    fi

    cd "${STACK_HOME}/devstack"

    case "${ZUUL_PROJECT}" in
        'openstack/murano')
            MURANO_REPO="${ZUUL_URL}/${ZUUL_PROJECT}"
            MURANO_BRANCH="${ZUUL_REF}"
        ;;
        'openstack/murano-dashboard')
            MURANO_DASHBOARD_REPO="${ZUUL_URL}/${ZUUL_PROJECT}"
            MURANO_DASHBOARD_BRANCH="${ZUUL_REF}"
            APPS_REPOSITORY_URL="http://${FLOATING_IP_ADDRESS}:8099"
        ;;
        'openstack/python-muranoclient')
            MURANO_PYTHONCLIENT_REPO="${ZUUL_URL}/${ZUUL_PROJECT}"
            MURANO_PYTHONCLIENT_BRANCH="${ZUUL_REF}"
        ;;
    esac

    # NOTE(freerunner): We need to ensure repositories have requested branches
    # and fallback to master branch for any repo which haven't.
    if ! git ls-remote "${MURANO_REPO}" | grep "${MURANO_BRANCH}"; then
        echo "Branch ${MURANO_BRANCH} does not exist in ${MURANO_REPO}. Using ${DEVSTACK_BRANCH}"
        MURANO_BRANCH="${DEVSTACK_BRANCH}";
    fi
    if ! git ls-remote "${MURANO_DASHBOARD_REPO}" | grep "${MURANO_DASHBOARD_BRANCH}"; then
        echo "Branch ${MURANO_DASHBOARD_BRANCH} does not exist in ${MURANO_DASHBOARD_REPO}. Using ${DEVSTACK_BRANCH}"
        MURANO_DASHBOARD_BRANCH="${DEVSTACK_BRANCH}";
    fi
    if ! git ls-remote "${MURANO_PYTHONCLIENT_REPO}" | grep "${MURANO_PYTHONCLIENT_BRANCH}"; then
        echo "Branch ${MURANO_PYTHONCLIENT_BRANCH} does not exist in ${MURANO_PYTHONCLIENT_REPO}. Using ${DEVSTACK_BRANCH}"
        MURANO_PYTHONCLIENT_BRANCH="${DEVSTACK_BRANCH}";
    fi

    echo "MURANO_REPO=${MURANO_REPO}"
    echo "MURANO_BRANCH=${MURANO_BRANCH}"
    echo "MURANO_REPOSITORY_URL=${APPS_REPOSITORY_URL}"
    echo "MURANO_DASHBOARD_REPO=${MURANO_DASHBOARD_REPO}"
    echo "MURANO_DASHBOARD_BRANCH=${MURANO_DASHBOARD_BRANCH}"
    echo "MURANO_PYTHONCLIENT_REPO=${MURANO_PYTHONCLIENT_REPO}"
    echo "MURANO_PYTHONCLIENT_BRANCH=${MURANO_PYTHONCLIENT_BRANCH}"

    DEVSTACK_LOCAL_CONFIG=""

    # remove leading '-' from '-glare'
    if [[ ${PACKAGES_SERVICE:1} = "glare" ]]; then
        # NOTE(kzaitsev): we have to install glance to make devstack install glare code
        # g-api ensures glance is installed, g-reg ensures cache dirs would be created
        DEVSTACK_LOCAL_CONFIG+=$'\n'"enable_service g-api"
        DEVSTACK_LOCAL_CONFIG+=$'\n'"enable_service g-reg"
        DEVSTACK_LOCAL_CONFIG+=$'\n'"enable_service g-glare"
        DEVSTACK_LOCAL_CONFIG+=$'\n'"DOWNLOAD_DEFAULT_IMAGES=False"
        # NOTE(mkarpin): we have to point to local endpoint for glare
        DEVSTACK_LOCAL_CONFIG+=$'\n'"GLANCE_GLARE_HOSTPORT=${FOUND_IP_ADDRESS}:9494"
        DEVSTACK_LOCAL_CONFIG+=$'\n'"MURANO_USE_GLARE=True"
    fi

    if [[ ${ZUUL_BRANCH} =~ kilo || ${ZUUL_BRANCH} =~ liberty ]]; then
        DEVSTACK_LOCAL_CONFIG+=$'\n'"enable_service murano"
        DEVSTACK_LOCAL_CONFIG+=$'\n'"enable_service murano-api"
        DEVSTACK_LOCAL_CONFIG+=$'\n'"enable_service murano-engine"
        DEVSTACK_LOCAL_CONFIG+=$'\n'"enable_service murano-dashboard"
    else
        DEVSTACK_LOCAL_CONFIG+=$'\n'"enable_plugin murano git://git.openstack.org/openstack/murano"
    fi

    export DEVSTACK_LOCAL_CONFIG

# Set KEYSTONE_DEPLOY to "uwsgi" as far as it will be set to "mod_wsgi" by default.
# For more information take a look at:
# * https://review.openstack.org/#/c/193894/
# * https://review.openstack.org/#/c/312238/

    cat << EOF > local.conf
[[local|localrc]]
HOST_IP=${OPENSTACK_HOST}           # IP address of OpenStack lab
ADMIN_PASSWORD=${ADMIN_PASSWORD}    # This value doesn't matter
MYSQL_PASSWORD=swordfish            # Random password for MySQL installation
SERVICE_PASSWORD=${ADMIN_PASSWORD}  # Password of service user
SERVICE_TOKEN=.                     # This value doesn't matter
SERVICE_PROJECT_NAME=${ADMIN_TENANT}
SERVICE_TENANT_NAME=${ADMIN_TENANT}
KEYSTONE_DEPLOY=uwsgi
MURANO_ADMIN_USER=${ADMIN_USERNAME}
RABBIT_HOST=${FLOATING_IP_ADDRESS}
MURANO_REPO=${MURANO_REPO}
MURANO_BRANCH=${MURANO_BRANCH}
MURANO_DASHBOARD_REPO=${MURANO_DASHBOARD_REPO}
MURANO_DASHBOARD_BRANCH=${MURANO_DASHBOARD_BRANCH}
MURANO_PYTHONCLIENT_REPO=${MURANO_PYTHONCLIENT_REPO}
MURANO_PYTHONCLIENT_BRANCH=${MURANO_PYTHONCLIENT_BRANCH}
MURANO_REPOSITORY_URL=${APPS_REPOSITORY_URL}
RABBIT_PASSWORD=guest
MURANO_RABBIT_VHOST=/
LIBS_FROM_GIT=${LIBS_FROM_GIT}
RECLONE=True
SCREEN_LOGDIR=/opt/stack/log/
LOGFILE=\$SCREEN_LOGDIR/stack.sh.log
LOG_COLOR=${DEVSTACK_LOG_COLOR}
ENABLED_SERVICES=
enable_service mysql
enable_service rabbit
enable_service horizon
${DEVSTACK_LOCAL_CONFIG}
# Disable neutron services because its unused on CI workers.
disable_service neutron
disable_service q-svc q-agt q-dhcp q-l3 q-meta q-metering
# Disable heat services because its unused on CI workers.
disable_service heat h-api h-api-cfn h-api-cw h-eng
EOF

    sudo ./tools/create-stack-user.sh
    if [[ -n "${OVERRIDE_STACK_PASSWORD}" ]]; then
        echo "stack:${OVERRIDE_STACK_PASSWORD}" | sudo chpasswd
    else
        echo 'stack:swordfish' | sudo chpasswd
    fi

    sudo chown -R stack:stack "${STACK_HOME}"

    sudo sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    sudo service ssh restart

    sudo su -c "cd ${STACK_HOME}/devstack && ./stack.sh" stack
}

function adjust_time_settings(){
    sudo sh -c "echo \"${TZ_STRING}\" > /etc/timezone"
    sudo dpkg-reconfigure -f noninteractive tzdata

    sudo ntpdate -u ru.pool.ntp.org
}
#-------------------------------------------------------------------------------

BUILD_STATUS_ON_EXIT='VM_REUSED'

# Create flags (files to check VM state)
if [ -f ~/build-started ]; then
    echo 'This VM is from previous tests run, terminating build'
    exit 1
else
    touch ~/build-started
fi

BUILD_STATUS_ON_EXIT='PREPARATION_FAILED'

cp "${WORKSPACE}/murano-ci/scripts/templates/empty.template" "${WORKSPACE}/index.html"

if [ "${KEEP_VM_ALIVE}" == 'true' ]; then
    touch ~/keep-vm-alive
fi

sudo sh -c "echo '127.0.0.1 $(hostname)' >> /etc/hosts"
sudo iptables -F

adjust_time_settings

git_clone_devstack

BUILD_STATUS_ON_EXIT='DEVSTACK_FAILED'

deploy_devstack

BUILD_STATUS_ON_EXIT='DEVSTACK_INSTALLED'

cat << EOF
********************************************************************************
*
*   Fixed IP: ${FOUND_IP_ADDRESS}
*   Floating IP: ${FLOATING_IP_ADDRESS}
*   Horizon URL: http://${FLOATING_IP_ADDRESS}
*   SSH connection string: ssh stack@${FLOATING_IP_ADDRESS} -oPubkeyAuthentication=no
*
********************************************************************************
EOF
