#!/bin/bash

TRACE_DEPTH=${TRACE_OFFSET:-0}
TRACE_STACK=${TRACE_NAME:-''}
LOG_FILE=/tmp/murano-obs-install.log

SCREEN_LOGDIR=${SCREEN_LOGDIR:-/tmp}

# Devstack functions
#-------------------

# Prints backtrace info
# filename:lineno:function
function backtrace {
    local level=$1
    local deep=$((${#BASH_SOURCE[@]} - 1))
    echo "[Call Trace]"
    while [ $level -le $deep ]; do
        echo "${BASH_SOURCE[$deep]}:${BASH_LINENO[$deep-1]}:${FUNCNAME[$deep-1]}"
        deep=$((deep - 1))
    done
}


# Prints line number and "message" then exits
# die $LINENO "message"
function die() {
    local exitcode=$?
    set +o xtrace
    local line=$1; shift
    if [ $exitcode == 0 ]; then
        exitcode=1
    fi
    backtrace 2
    err $line "$*"
    exit $exitcode
}


# Checks an environment variable is not set or has length 0 OR if the
# exit code is non-zero and prints "message" and exits
# NOTE: env-var is the variable name without a '$'
# die_if_not_set $LINENO env-var "message"
function die_if_not_set() {
    local exitcode=$?
    FXTRACE=$(set +o | grep xtrace)
    set +o xtrace
    local line=$1; shift
    local evar=$1; shift
    if ! is_set $evar || [ $exitcode != 0 ]; then
        die $line "$*"
    fi
    $FXTRACE
}


# Prints line number and "message" in error format
# err $LINENO "message"
function err() {
    local exitcode=$?
    errXTRACE=$(set +o | grep xtrace)
    set +o xtrace
    local msg="[ERROR] ${BASH_SOURCE[2]}:$1 $2"
    echo $msg 1>&2;
    if [[ -n ${SCREEN_LOGDIR} ]]; then
        echo $msg >> "${SCREEN_LOGDIR}/error.log"
    fi
    $errXTRACE
    return $exitcode
}


# Test if the named environment variable is set and not zero length
# is_set env-var
function is_set() {
    local var=\$"$1"
    eval "[ -n \"$var\" ]" # For ex.: sh -c "[ -n \"$var\" ]" would be better, but several exercises depends on this
}


#-------------------


function log {
	l='          '
    printf "%s%s\n" "${l:0:$TRACE_DEPTH}" "$@" | tee --append $LOG_FILE
}

function echo_() {
	l='          '
    printf "%s%s\n" "${l:0:$TRACE_DEPTH}" "$@" | tee --append $LOG_FILE
}

function echo_h1() {
	l='**********'
    printf "%s%s\n" "${l:0:$TRACE_DEPTH}" "$@" | tee --append $LOG_FILE
}

function echo_h2() {
	l='=========='
    printf "%s%s\n" "${l:0:$TRACE_DEPTH}" "$@" | tee --append $LOG_FILE
}

function echo_h3() {
	l='----------'
    printf "%s%s\n" "${l:0:$TRACE_DEPTH}" "$@" | tee --append $LOG_FILE
}

function trace_in() {
	l='----------'
	# Trace in
	TRACE_STACK="$TRACE_NAME $1"
	shift
	TRACE_DEPTH=$(( TRACE_DEPTH + 1 ))
	echo_h3 " >>> ${TRACE_STACK##* }($@)"
}

function trace_out() {
	l='----------'
	# Trace out
	echo_h3 " <<< ${TRACE_STACK##* }()"
	TRACE_STACK=${TRACE_STACK% *}
	TRACE_DEPTH=$(( TRACE_DEPTH - 1 ))
}


function pip_install() {
    trace_in pip_install "$@"

    log "** Installing pip packages '$@'"

    if [ -f "$pip_version_requirements" ]; then
        pip install --upgrade -r "$pip_version_requirements" "$@"
    else
        pip install --upgrade "$@"
    fi

    trace_out
}


function upgrade_pip() {
    trace_in upgrade_pip "$@"

    log "** Upgrading pip to '$1'"

    case "$1" in
        '1.4')
            echo 'pip<1.5' > "$pip_version_requirements"
            pip install --upgrade -r "$pip_version_requirements"
            rm /usr/bin/pip
            ln -s /usr/local/bin/pip /usr/bin/pip
        ;;
    esac

    trace_out
}


function configure_murano() {
	trace_in configure_murano "$@"
	trace_out
}


function add_obs_repo() {
	trace_in add_obs_repo "$@"

	local request_id=${1:-''}
	local list_file
	local url

	#OBS_REPO_PREFIX=ubuntu-fuel-4.1-stable
	#OBS_URL_PREFIX=http://osci-obs.vm.mirantis.net:82
	#OBS_LOCAL_REPO=/opt/repo

	if [[ ! -d "${OBS_LOCAL_REPO}" ]]; then
		mkdir -p ${OBS_LOCAL_REPO}
	fi

	if [[ ! -f "/etc/apt/preferences.d/local_repo.pref" ]]; then
		cat << EOF > "/etc/apt/preferences.d/local_repo.pref"
Package: *
Pin: origin ""
Pin-Priority: 550
EOF
fi

	# URL example
	# http://osci-obs.vm.mirantis.net:82/ubuntu-fuel-4.1-stable-10041/ubuntu

	if [[ -z "${request_id}" ]]; then
		list_file=/etc/apt/sources.list.d/${OBS_REPO_PREFIX}.list
		url=${OBS_URL_PREFIX}/${OBS_REPO_PREFIX}/ubuntu

		wget ${url}/Release.key -O - | apt-key add -

		echo "deb ${url}/ ./" > "${list_file}"
	else
		list_file=/etc/apt/sources.list.d/obs-request-${request_id}.list
		url=${OBS_URL_PREFIX}/${OBS_REPO_PREFIX}-${request_id}/ubuntu

		if [[ -d "${OBS_LOCAL_REPO}/${OBS_REPO_PREFIX}-${request_id}" ]]; then
			rm -rf "${OBS_LOCAL_REPO}/${OBS_REPO_PREFIX}-${request_id}"
		fi

		wget -r -np -nH -A *.deb,*.dsc,*.gz,*.key ${url}/ -P ${OBS_LOCAL_REPO}

		url=${OBS_LOCAL_REPO}/${OBS_REPO_PREFIX}-${request_id}/ubuntu
		
		apt-key add ${url}/Release.key

		echo "deb file:${url} ./" > "${list_file}"
	fi

	#apt-get update
	trace_out
}


function remove_obs_repo() {
	trace_in remove_obs_repo "$@"
	trace_out
}


function clean_obs_repo() {
    trace_in clean_obs_repo "$@"

    cd ${OBS_LOCAL_REPO} && rm -rf *
    cd '/etc/apt/sources.list.d' && rm -f obs-request-*.list

    trace_out
}

function install_murano_prereqs() {
	trace_in install_murano_prereqs "$@"
	trace_out
}

