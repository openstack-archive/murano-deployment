#!/bin/bash

TOP_DIR=~
DEST=~/murano
SCREEN_LOGDIR=$DEST/logs
CURRENT_LOG_TIME=$(TZ=Europe/Moscow date +"%Y-%m-%d-%H%M%S")

MURANO_REPO=https://github.com/stackforge/murano
MURANO_DASHBOARD_REPO=https://github.com/stackforge/murano-dashboard
MURANO_APPS_REPO=https://github.com/murano-project/murano-app-incubator

MURANO_CONF=./etc/murano/murano.conf

# Any non-empty string means 'true'
WITH_VENV=${WITH_VENV:-''}

function screen_service {
    local service=$1
    local workdir="$2"
    local command="$3"

    echo ''
    echo "Starting ${service} in '${workdir}' ..."

    SCREEN_NAME=${SCREEN_NAME:-murano}
    SERVICE_DIR=${SERVICE_DIR:-${DEST}/status}

    mkdir -p $SERVICE_DIR/$SCREEN_NAME

    # Append the service to the screen rc file
    screen_rc "$service" "$command"

    screen -S $SCREEN_NAME -X screen -t $service

    if [[ -n ${SCREEN_LOGDIR} ]]; then
        screen -S $SCREEN_NAME -p $service -X logfile ${SCREEN_LOGDIR}/screen-${service}.${CURRENT_LOG_TIME}.log
        screen -S $SCREEN_NAME -p $service -X log on
        ln -sf ${SCREEN_LOGDIR}/screen-${service}.${CURRENT_LOG_TIME}.log ${SCREEN_LOGDIR}/screen-${service}.log
    fi

    # sleep to allow bash to be ready to be send the command - we are
    # creating a new window in screen and then sends characters, so if
    # bash isn't running by the time we send the command, nothing happens
    sleep 3

    NL=`echo -ne '\015'`
    # This fun command does the following:
    # - the passed server command is backgrounded
    # - the pid of the background process is saved in the usual place
    # - the server process is brought back to the foreground
    # - if the server process exits prematurely the fg command errors
    #   and a message is written to stdout and the service failure file
    # The pid saved can be used in stop_process() as a process group
    # id to kill off all child processes
    screen -S $SCREEN_NAME -p $service -X stuff "cd \"$workdir\" $NL"
    if [[ "${WITH_VENV}" ]]; then
        screen -S $SCREEN_NAME -p $service -X stuff "source .tox/venv/bin/activate $NL"
    fi
    screen -S $SCREEN_NAME -p $service -X stuff "$command & echo \$! >$SERVICE_DIR/$SCREEN_NAME/${service}.pid; fg || echo \"$service failed to start\" | tee \"$SERVICE_DIR/$SCREEN_NAME/${service}.failure\" $NL"

    echo '... done'
}


function screen_stop_service {
    local service=$1

    SCREEN_NAME=${SCREEN_NAME:-murano}
    SERVICE_DIR=${SERVICE_DIR:-${DEST}/status}

    echo ''
    echo "Stopping ${service} ..."

    # Clean up the screen window
    screen -S $SCREEN_NAME -p $service -X kill

    echo '... done'
}


function screen_rc {
    SCREEN_NAME=${SCREEN_NAME:-murano}
    SCREENRC=$TOP_DIR/$SCREEN_NAME-screenrc

    if [[ ! -e $SCREENRC ]]; then
        # Name the screen session
        echo "sessionname $SCREEN_NAME" > $SCREENRC
        # Set a reasonable statusbar
        echo "hardstatus alwayslastline '$SCREEN_HARDSTATUS'" >> $SCREENRC
        # Some distributions override PROMPT_COMMAND for the screen terminal type - turn that off
        echo "setenv PROMPT_COMMAND /bin/true" >> $SCREENRC
        echo "screen -t shell bash" >> $SCREENRC
    fi

    # If this service doesn't already exist in the screenrc file
    if ! grep $1 $SCREENRC 2>&1 > /dev/null; then
        NL=`echo -ne '\015'`
        echo "screen -t $1 bash" >> $SCREENRC
        echo "stuff \"$2$NL\"" >> $SCREENRC

        if [[ -n ${SCREEN_LOGDIR} ]]; then
            echo "logfile ${SCREEN_LOGDIR}/screen-${1}.${CURRENT_LOG_TIME}.log" >>$SCREENRC
            echo "log on" >>$SCREENRC
        fi
    fi
}


function screen_session_start {
    SCREEN_NAME=${SCREEN_NAME:-murano}

    echo ''
    echo 'Starting new screen session ...'

    screen_count=$(screen -ls | awk "/[0-9]\.${SCREEN_NAME}/{print \$0}" | wc -l)

    if [[ ${screen_count} -eq 0 ]]; then
        echo 'No screen sessions found, creating a new one'
        screen -dmS ${SCREEN_NAME}
    elif [[ ${screen_count} -eq 1 ]]; then
        echo 'Screen session found'
    else
        echo "${screen_count} sessions found, should be 1."
        exit 1
    fi

    echo '... done'
}


function screen_session_quit {
    SCREEN_NAME=${SCREEN_NAME:-murano}
    SCREENRC=$TOP_DIR/$SCREEN_NAME-screenrc

    echo ''
    echo 'Terminating screen sessions ...'

    for session in $(screen -ls | awk "/[0-9]\.${SCREEN_NAME}/{print \$1}"); do
        screen -X -S ${session} quit
    done

    rm -f $SCREENRC

    echo '... done'
}


function create_venv {
    local path="$1"

    echo ''
    echo "Creating virtual env in '${path}' ..."

    pushd ${path}
    tox -r -e venv -- python setup.py install
    popd

    echo '... done'
}


function prepare_devbox {
    sudo apt-get update
    sudo apt-get upgrade

    # Install prerequisites for using tox
    sudo apt-get --yes install \
        python-dev \
        python-pip \
        libmysqlclient-dev \
        libpq-dev \
        libxml2-dev \
        libxslt1-dev \
        libffi-dev

    # Install other prereqisites
    sudo apt-get --yes install \
        git \
        rabbitmq-server

    # Enable rabbitmq_management plugin
    sudo /usr/lib/rabbitmq/bin/rabbitmq-plugins enable rabbitmq_management
    sudo service rabbitmq-server restart

    sudo pip install tox

    mkdir -p ${DEST}/logs
    mkdir -p ${DEST}/status

    pushd ${DEST}
    git clone ${MURANO_REPO}
    git clone ${MURANO_DASHBOARD_REPO}
    git clone ${MURANO_APPS_REPO}
    popd

    create_venv ${DEST}/murano
    create_venv ${DEST}/murano-dashboard

    collect_static
}


function collect_static {
    pushd ${DEST}/murano-dashboard
    tox -e venv -- python manage.py collectstatic --noinput
    popd
}


function import_app {
    local path=${1:-.}

    echo ''
    if [[ -f "${path}/manifest.yaml" ]]; then
        app_path=$(cd "${path}" && pwd)
    elif [[ -f "${DEST}/murano-app-incubator/${path}/manifest.yaml" ]]; then
        app_path="${DEST}/murano-app-incubator/${path}"
    else
        app_path=''
    fi

    if [[ -n "${app_path}" ]]; then
        echo ''
        echo "Importing Murano Application from '${app_path}' ..."

        pushd ${DEST}/murano
        if [[ "${WITH_VENV}" ]]; then
            source .tox/venv/bin/activate
            murano-manage --config-file ${MURANO_CONF} import-package "${app_path}" --update
            deactivate
        else
            tox -e venv -- murano-manage --config-file ${MURANO_CONF} import-package "${app_path}" --update
        fi
        popd

        echo '... done'
    else
        echo "No Murano Application found using pathspec '${path}'."
    fi
}


function show_help {
    cat << EOF | less

manage-devbox - manage Murano Development Box.

SYNOPSIS

    manage-devbox <command>

COMMANDS

    start
        Start Murano services inside screen session. If a session already
        exists it will be used. If not a new one will be created.

    stop
        Stop Murano services and quit screen session.

    dbsync
        Remove Murano SQLite database and create it from scratch.

    dbinit
        Import Murano Core package.

    install
        Install Murano services and prerequisites into virtual env.

    import <path[ path2[ path3[...]]]>
        Import Murano Applications from <path>.

    importall
        Import all packages from murano-app-incubator directory.
EOF
}


case $1 in
    'start')
        screen_session_start
        if [[ "${WITH_VENV}" ]]; then
            screen_service 'murano-api' "${DEST}/murano" "murano-api --config-file ${MURANO_CONF}"
            screen_service 'murano-engine' "${DEST}/murano" "murano-engine --config-file ${MURANO_CONF}"
            screen_service 'murano-dashboard' "${DEST}/murano-dashboard" 'python manage.py runserver 0.0.0.0:8000'
        else
            screen_service 'murano-api' "${DEST}/murano" "tox -e venv -- murano-api --config-file ${MURANO_CONF}"
            screen_service 'murano-engine' "${DEST}/murano" "tox -e venv -- murano-engine --config-file ${MURANO_CONF}"
            screen_service 'murano-dashboard' "${DEST}/murano-dashboard" 'tox -e venv -- python manage.py runserver 0.0.0.0:8000'
        fi
    ;;
    'stop')
        screen_stop_service 'murano-dashboard'
        screen_stop_service 'murano-engine'
        screen_stop_service 'murano-api'
        screen_session_quit
    ;;
    'dbsync')
        rm ${DEST}/murano/murano.sqlite
        pushd ${DEST}/murano
        if [[ "${WITH_VENV}" ]]; then
            source .tox/venv/bin/activate
            murano-db-manage --config-file ${MURANO_CONF}
            deactivate
        else
            tox -e venv -- murano-db-manage --config-file ${MURANO_CONF} upgrade
        fi
        popd
    ;;
    'dbinit')
        pushd ${DEST}/murano
        if [[ "${WITH_VENV}" ]]; then
            source .tox/venv/bin/activate
            murano-manage --config-file ${MURANO_CONF}
            deactivate
        else
            tox -e venv -- murano-manage --config-file ${MURANO_CONF} import-package ./meta/io.murano
        fi
        popd
    ;;
    'install')
        prepare_devbox
    ;;
    'import')
        shift
        while [ -n "$1" ]; do
            import_app "$1"
            shift
        done
    ;;
    'importall')
        for app in $(find ${DEST}/murano-app-incubator -type d -maxdepth 1); do
            import_app "${app}"
        done
    ;;
    *)
        show_help
    ;;
esac

