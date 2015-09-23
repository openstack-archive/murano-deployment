#!/bin/bash
#    Copyright (c) 2015 Mirantis, Inc.
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
START_DIR=$(cd "$(dirname "${0}")" && pwd)
WORK_DIR="${START_DIR}/workspace"
CFG_FILE="${CFG_FILE:-$START_DIR/config.ini}"
LOG_DIR="${START_DIR}/logs"
LOG_FILE="${LOG_DIR}/run_$(date +%Y-%m-%d_%H).log"
LOG_LVL=3
declare -A Config
######## FUNCTIONS ##############
# logler
function log()
{
    local input="$*"
    if [ ! -d "${LOG_DIR}" ]; then
        mkdir -p "${LOG_DIR}"
    fi
    case "${LOG_LVL}" in
        3)
            if [ ! -z "${input}" ]; then
                echo "${input}" | tee -a "${LOG_FILE}"
            fi
            ;;
        2)
            if [ ! -z "${input}" ]; then
                echo "${input}" >> "${LOG_FILE}"
            fi
            ;;
        1)
            if [ ! -z "${input}" ]; then
                echo "${input}"
            fi
            ;;
        *)
            ;;
    esac
}
# iniget config-file section option
function iniget {
    local xtrace=''
    xtrace=$(set +o | grep xtrace)
    set +o xtrace
    local file=$1
    local section=$2
    local option=$3
    local line
    line=$(sed -ne "/^\[$section\]/,/^\[.*\]/ { /^$option[ \t]*=/ p; }" "$file")
    echo "${line#*=}"
    $xtrace
}
# ini_has_option config-file section option
function ini_has_option_sudo() {
    local file=$1
    local section=$2
    local option=$3
    local line
    line=$(sudo sed -ne "/^\[$section\]/,/^\[.*\]/ { /^$option[ \t]*=/ p; }" "$file")
    [ -n "$line" ]
}
# iniset config-file section option value
function iniset_sudo()
{
    local xtrace=$(set +o | grep xtrace)
    set +o xtrace
    local file=$1
    local section=$2
    local option=$3
    local value=$4

    [[ -z $section || -z $option ]] && return

    if ! sudo grep -q "^\[$section\]" "$file" 2>/dev/null; then
        # Add section at the end
        echo -e "\n[$section]" | sudo tee -a "$file"
    fi
    if ! ini_has_option_sudo "$file" "$section" "$option"; then
        # Add it
        sudo sed -i -e "/^\[$section\]/ a\\
$option = $value
" "$file"
    else
        local sep=$(echo -ne "\x01")
        # Replace it
        sudo sed -i -e '/^\['${section}'\]/,/^\[.*\]/ s'${sep}'^\('${option}'[ \t]*=[ \t]*\).*$'${sep}'\1'"${value}"${sep} "$file" 2>/dev/null
    fi
    $xtrace
}
# check reuirements
function check_sys_packages()
{
    local forceinstall="${1:-false}"
    local retval=0
    local packages="qemu-kvm virt-manager virt-goodies virtinst bridge-utils libvirt-bin uuid-runtime samba samba-common cifs-utils"
    if [ ! -f "/etc/debian_version" ] || ! lsb_release -a 2>/dev/null | grep -qE '(Mint|Ubuntu|Debian)'; then
        log "Err: Ubuntu like distros only supported for now !"
        exit 2
    fi
    for package in ${packages}
    do
        dpkg-query --status "${package}" >> /dev/null 2>&1
        if [ "$?" -ne 0 ]; then

            if [ "${forceinstall}" == true ]; then
                sudo apt-get install -y "${package}" || retval=$?
            else
                log "Wrn: ${package} required, please install it !"
                retval=1
            fi
        fi
    done
    sudo usermod -a -G libvirtd "${USER}" 2>/dev/null
    return "${retval}"
}
# read configuration
function init()
{
    local wdir=''
    local vmswdir=''
    #local vioiso=''
    local reqsoft=''
    local winrels=''
    local prun=''
    local smbmode=''
    local smbhost=''
    local smbuser=''
    local smbdomain=''
    local smbpasswd=''
    local smbcredsfile=''
    local smbsharename=''
    wdir=$(iniget "${CFG_FILE}" "default" "workdir")
    vmswdir=$(iniget "${CFG_FILE}" "default" "vmsworkdir")
    prun=$(iniget "${CFG_FILE}" "default" "runparallel")
    reqsoft=$(iniget "${CFG_FILE}" "default" "requirements")
    winrels=$(iniget "${CFG_FILE}" "default" "available_win_versions")
    smbmode=$(iniget "${CFG_FILE}" "samba" "mode")
    smbhost=$(iniget "${CFG_FILE}" "samba" "host")
    smbuser=$(iniget "${CFG_FILE}" "samba" "user")
    smbdomain=$(iniget "${CFG_FILE}" "samba" "domain")
    smbpasswd=$(iniget "${CFG_FILE}" "samba" "password")
    smbsharename=$(iniget "${CFG_FILE}" "samba" "sharename")
    if [ ! -z "${reqsoft}" ]; then Config["requirements"]="${reqsoft}"; fi
    if [ ! -z "${winrels}" ]; then Config["win_releases"]="${winrels}"; fi
    if [ ! -z "${prun}" ]; then Config["runparallel"]="${prun}"; fi
    if [ ! -z "${wdir}" ]; then WORK_DIR="${wdir}/workspace"; fi
    if [ ! -z "${vmswdir}" ]; then
        sudo mkdir -p  "${vmswdir}" && sudo chown -R "${USER}" "${vmswdir}" || exit 2
        Config["vmsworkdir"]="${vmswdir}"
    fi
    if [ ! -d "$WORK_DIR" ]; then
        sudo mkdir -p "${WORK_DIR}" && sudo chown -R "${USER}":"${USER}" "${WORK_DIR}"/ || exit $?
    fi
    mkdir -p "${WORK_DIR}/mnt" || exit $?
    mkdir -p "${WORK_DIR}/downloads" || exit $?
    smbcredsfile="${WORK_DIR}/smb.creds"
    Config["smbcredsfile"]="${smbcredsfile}"
    Config["loopmountoptions"]="-o uid=$(id -u),gid=$(id -g),loop"
    Config["smbmountoptions"]="-o vers=2.0,nounix,iocharset=utf8,uid=$(id -u),gid=$(id -g)"
    if [ "${smbmode}" == "local" ]; then
        Config["smblocalsetuprequired"]=true
    else
        Config["smblocalsetuprequired"]=false
    fi
    if [ "${smbuser}" != "guest" ]; then
        if [ -f "${Config["smbcredsfile"]}" ]; then rm -f "${Config["smbcredsfile"]}" || exit $?; fi
        echo username="${smbuser}" > "${Config["smbcredsfile"]}"
        if [ ! -z "${smbdomain}" ]; then
            echo domain="${smbdomain}" >> "${Config["smbcredsfile"]}"
        else
            echo domain="${smbhost}" >> "${Config["smbcredsfile"]}"
        fi
        echo password="${smbpasswd}" >> "${Config["smbcredsfile"]}"
        Config["smbmountoptions"]+=",credentials=${Config["smbcredsfile"]}"
    else
        Config["smbmountoptions"]+=",guest"
    fi
    Config["smbmountpoint"]="${WORK_DIR}/mnt"
    Config["smbshare"]="//${smbhost}/${smbsharename}"
    Config["downloadsdir"]="${WORK_DIR}/downloads"
}
# check disk space
function check_free_space()
{
    local min_free_g="50"
    local sys_free=''
    log "Checking free space for ${Config["vmsworkdir"]} folder partition..."
    sys_free=$(sudo df "${Config["vmsworkdir"]}" --total -k -h  --output=avail | head -n2 | tail -n1)
    if [ "${sys_free/G/}" -lt "${min_free_g}" ]; then
        log "Err: You have not enough free space ${sys_free} at ${Config["vmsworkdir"]}, required - ${min_free_g}G!"
        exit 2
    fi
}
# check libvirt
function check_libvirtnet()
{
    local networkname='default'
    log "Checking libvirt network..."
    virsh net-list | grep -q "${networkname}"
    if [ "$?" -ne 0 ]; then
        virsh net-define "${START_DIR}/lib/templates/defaultnet.template" || exit 2
        virsh net-autostart "${networkname}" || exit 2
        virsh net-start "${networkname}" || exit 2
    fi
}
# iptables rules for local Samba server
function set_iptables_smb_rules()
{
    log "Configuring iptables rules..."
    sudo iptables -nvL INPUT | grep -q 'NetBIOS Name Service' || sudo iptables -A INPUT -p udp --dport 137 -m comment --comment "add by winimage-builder - NetBIOS Name Service" -j ACCEPT
    sudo iptables -nvL INPUT | grep -q 'NetBIOS Datagram Service' || sudo iptables -A INPUT -p udp --dport 138 -m comment --comment "add by winimage-builder - NetBIOS Datagram Service" -j ACCEPT
    sudo iptables -nvL INPUT | grep -q 'NetBIOS Session Service' || sudo iptables -A INPUT -p tcp --dport 139 -m comment --comment "add by winimage-builder - NetBIOS Session Service" -j ACCEPT
    sudo iptables -nvL INPUT | grep -q 'Microsoft Directory Service' || sudo iptables -A INPUT -p tcp --dport 445 -m comment --comment "add by winimage-builder - Microsoft Directory Service" -j ACCEPT
}
# check & configure local Samba server
function prepare_local_sambaserver()
{
    local share_path=''
    local sharename=''
    local makeserviceconfiguration="${1:-false}"
    local showtip="${2:-false}"
    local smbconf_path="/etc/samba/smb.conf"
    if [ "${Config["smblocalsetuprequired"]}" == true ]; then
        if  [ -f "${smbconf_path}" ] && [ "${makeserviceconfiguration}" == true ]; then
            log "Configuring local Samba server..."
            share_path="${WORK_DIR}/smbshare"
            sudo mkdir -p "${share_path}" || return $?
            sudo chown -R nobody:nogroup "${share_path}"
            sharename=$(iniget "${CFG_FILE}" "samba" "sharename")
            iniset_sudo ${smbconf_path} "${sharename}" 'comment' 'Image Builder Share'
            iniset_sudo ${smbconf_path} "${sharename}" 'path' "${share_path}"
            iniset_sudo ${smbconf_path} "${sharename}" 'browsable' "yes"
            iniset_sudo ${smbconf_path} "${sharename}" 'guest ok' "yes"
            iniset_sudo ${smbconf_path} "${sharename}" 'guest account' "nobody"
            iniset_sudo ${smbconf_path} "${sharename}" 'read only' "no"
            iniset_sudo ${smbconf_path} "${sharename}" 'create mask' "0755"
            log "Restarting Samba services..."
            sudo restart smbd || return $?
            sudo restart nmbd || return $?
            sleep 3
            set_iptables_smb_rules
            return 0
        else
            log "Err: File ${smbconf_path} not found!"
            return 1
        fi
    else
        if [ "${showtip}" == true ]; then
            log "FYI: please, configure youre remote samba resource properly with rw access and make modifications at ${CFG_FILE}, [samba] section!"
            log "FYI: Linux /etc/samba/smb.conf part template could looks like this:"
            cat "${START_DIR}/lib/templates/smbshare.conf.template"
        fi
    fi
    return 0
}
# mounting cifs/smbfs
function checkmountremote()
{
    sudo mount | grep -q "${Config["smbmountpoint"]}" && umountremote
    sleep 1
}
function mountremote()
{
    log "Mounting Samba share and checking rw access..."
    sudo mount -t cifs ${Config["smbshare"]} ${Config["smbmountpoint"]} ${Config["smbmountoptions"]}
    if [ "$?" -ne 0 ]; then log "ERR: Can't mount ${Config["smbshare"]}!"; exit 1;fi
    touch "${Config["smbmountpoint"]}/testfile" && rm -f "${Config["smbmountpoint"]}/testfile" || exit $?
}
#
function umountremote()
{
    log "Unounting Samba share..."
    sudo umount "${Config["smbmountpoint"]}"
    if [ "$?" -ne 0 ]; then log "ERR: Can't unmount ${Config["smbmountpoint"]}!"; exit 1;fi
}
# prepare CoreFunctions
function prepare_corefunctions_ps()
{
    local cf_src_dir=''
    local cf_zipfile=''
    cf_src_dir=$(cd "${START_DIR}"/../WindowsPowerShell && pwd)
    cd "${cf_src_dir}" && make all >> /dev/null 2>&1
    if [ "$?" -ne 0 ]; then
        log "Err: Can't build powershell CoreFunctions !"
        exit 2
    fi
    cf_zipfile="${cf_src_dir}"/CoreFunctions.zip
    if [ ! -f "${cf_zipfile}" ]; then
        log "Err: Please, check make parameters at ${cf_src_dir} of file name for ${cf_zipfile} !"
        exit 2
    fi
    mv "${cf_zipfile}" "${Config["downloadsdir"]}"
}
# Download
function downloadrequirements()
{
    local sw_required=false
    local sw_redownload=false
    local sw_download_from=''
    local sw_download_as=''
    local sw_download_as_fullpath=''
    for requirement in ${Config["requirements"]}
    do
        sw_required=$(iniget "${CFG_FILE}" "${requirement}" "required")
        if [ "${sw_required}" == true ]; then
            sw_download_as=$(iniget "${CFG_FILE}" "${requirement}" "saveas")
            sw_download_from=$(iniget "${CFG_FILE}" "${requirement}" "url")
            sw_redownload=$(iniget "${CFG_FILE}" "${requirement}" "redownload")
            if [ "${requirement}" == "virtio_iso" ]; then
                sw_download_as_fullpath="${WORK_DIR}/${sw_download_as}"
                Config["virtio_iso"]="${sw_download_as_fullpath}"
            else
                sw_download_as_fullpath="${Config["downloadsdir"]}/${sw_download_as}"
            fi
            if [ ! -f "${sw_download_as_fullpath}" ] || [ "${sw_redownload}" == true ]; then
                log "Downloading ${requirement}..."
                if [ "${sw_redownload}" == true ]; then rm -f "${sw_download_as_fullpath}"; log ".redownload for ${requirement} enabled" ;fi
                wget -q "${sw_download_from}" -O "${sw_download_as_fullpath}"
                if [ "$?" -ne 0 ]; then log "Wrn: Error occurred during downloading of ${sw_download_from} !";fi
            fi
        fi
    done
}
# show win_releases
function show_configured_win_releases()
{
    local rel_enabled=false
    local rel_iso=''
    local rel_desc=''
    local rel_edits=''
    for release in ${Config["win_releases"]}
    do
        rel_enabled=$(iniget "${CFG_FILE}" "${release}" "enabled")
        if [ "${rel_enabled}" == true ]; then
            rel_iso=$(iniget "${CFG_FILE}" "${release}" "iso")
            if [ -f "${rel_iso}" ]; then
                rel_desc=$(iniget "${CFG_FILE}" "${release}" "description")
                rel_edits=$(iniget "${CFG_FILE}" "${release}" "editions")
                log "[${release}] - ${rel_desc}(${rel_edits/ /,})"
            else
                log "Err: Can't access ${rel_iso}, please check ${CFG_FILE} [${release}] section!"
            fi
        fi
    done

}
# prepare mirror
function preparemirror()
{
    local mirrordir="${WORK_DIR}/mirror"
    if [ ! -d "${mirrordir}" ]; then
        mkdir "${mirrordir}"
    else
        rm -rf "${mirrordir}"
    fi
    mkdir -p "${mirrordir}/Scripts"
    mkdir -p "${mirrordir}/Files"
    cp -r "${Config["downloadsdir"]}"/* "${mirrordir}"/Files/
    cp -r "${START_DIR}"/lib/windowssetup/scripts/* "${mirrordir}"/Scripts/
}
# copy mirror to smbshare
function copymirrortomnt()
{
    local mirrordir="${WORK_DIR}/mirror"
    cp -r "${mirrordir}"/* "${Config["smbmountpoint"]}"/ || exit $?
    rm -rf "${mirrordir}"
}
# prepare virtual floppy image
function make_virtualfloppy()
{
    local unattend_dir="${1}"
    local vms_path="${2}"
    local vfloppy=''
    local smbcreds=''
    local retval=0
    if [ ! -d "${vms_path}" ]; then log "Err: Can't access ${vms_path}, check [defaults]/vmsworkdir parameter !"; return "${retval}"; fi
    vfloppy="${vms_path}/startup.vfd"
    sudo rm -f $vfloppy
    if [ ! -f "${vfloppy}" ]; then
        dd bs=512 count=2880 if=/dev/zero of="${vfloppy}" >> /dev/null 2>&1 || return $?
        mkfs.msdos "${vfloppy}" >> /dev/null || retval=$?
        mkdir -p "${vms_path}"/mnt/floppy || retval=$?
        mount | grep -q "${vms_path}"/mnt/floppy && sudo umount "${vms_path}"/mnt/floppy 2>/dev/null
        sudo mount -t vfat ${Config["loopmountoptions"]} "${vfloppy}" "${vms_path}"/mnt/floppy/  || return $?
        cp "${unattend_dir}/autounattend.xml.template" "${vms_path}"/mnt/floppy/autounattend.xml
        cp "${unattend_dir}/unattend.xml.template" "${vms_path}"/mnt/floppy/nextunattend.xml
        sed "s/%_IMAGE_BUILDER_HOST_%/$(iniget "${CFG_FILE}" "samba" "host")/g" -i "${vms_path}"/mnt/floppy/autounattend.xml  || retval=$?
        sed "s/%_SHARE_PATH_%/$(iniget "${CFG_FILE}" "samba" "sharename")/g" -i "${vms_path}"/mnt/floppy/autounattend.xml  || retval=$?
        if [ "$(iniget "${CFG_FILE}" "samba" "mode")" == "local" ]; then
            smbcreds=''
        else
            local smbdomain
            smbdomain=$(iniget "${CFG_FILE}" "samba" "domain")
            if [ -z "${smbdomain}" ]; then smbdomain=$(iniget "${CFG_FILE}" "samba" "host"); fi
            smbcreds="\"$(iniget "${CFG_FILE}" "samba" "password")\" \/USER:${smbdomain}\\\\$(iniget "${CFG_FILE}" "samba" "user")"
        fi
        sed "s/%_SHARE_CREDS_%/${smbcreds}/g" -i "${vms_path}"/mnt/floppy/autounattend.xml  || retval=$?
        sleep 1
        sudo umount "${vms_path}"/mnt/floppy  || return $?
        rm -rf "${vms_path}"/mnt  || return $?
    fi
    return "${retval}"
}
# copy virtio iso-
function copy_virtiodrv()
{
    local vms_path="${1}"
    if [ ! -f "${Config["virtio_iso"]}" ]; then
        log "Err: Cant access ${Config["virtio_iso"]}, check [vitrio_iso] configuration section or file ${Config["virtio_iso"]} exists !"
        exit 2
    else
        cp -f "${Config["virtio_iso"]}" "${vms_path}"/virtio.iso || return $?
    fi
    return 0
}
# start install
function start_win_vm()
{
    local vms_path="${1}"
    local win_boot_iso_path="${2}"
    local vm_virtio_iso_path=''
    local vm_setup_vfd_path=''
    local vm_name=''
    local vm_build_log=''
    local vm_img_ref_path=''
    vm_virtio_iso_path="${vms_path}"/virtio.iso
    vm_setup_vfd_path="${vms_path}"/startup.vfd
    vm_name="$(basename "${vms_path}")-$(uuidgen --time)"
    vm_build_log="${LOG_DIR}/${vm_name}.log"
    vm_img_ref_path="${WORK_DIR}/$(basename "${vms_path}")-ref.qcow2"
    if [ "${Config["runparallel"]}" == true ]; then
        IMAGE_BUILDER_ROOT=${vms_path} IMAGE_NAME=${vm_name} VIRTIO_ISO=${vm_virtio_iso_path} FLOPPY_IMG=${vm_setup_vfd_path} BOOT_ISO=${win_boot_iso_path} VM_REF_IMG_COPY_TO_WORKSPACE=${vm_img_ref_path} bash "${START_DIR}/launch-vm.sh" >> "${vm_build_log}" 2>&1 &
        log " vm preparations in progress, reference image would be built as ${vm_img_ref_path}, check build logfile - ${vm_build_log} !"
    else
        IMAGE_BUILDER_ROOT=${vms_path} IMAGE_NAME=${vm_name} VIRTIO_ISO=${vm_virtio_iso_path} FLOPPY_IMG=${vm_setup_vfd_path} BOOT_ISO=${win_boot_iso_path} VM_REF_IMG_COPY_TO_WORKSPACE=${vm_img_ref_path} bash "${START_DIR}/launch-vm.sh" 2>&1 | tee -a "${vm_build_log}"
    fi
}
# cycled build
function process_windows()
{
    local rel_enabled=false
    local rel_iso=''
    local rel_desc=''
    local rel_edits=''
    local rel_unattend_templ_prefix=''
    local rel_unattend_templ_dir=''
    local rel_vms_temp_dir=''
    for release in ${Config["win_releases"]}
    do
        rel_enabled=$(iniget "${CFG_FILE}" "${release}" "enabled")
        if [ "${rel_enabled}" == true ]; then
            rel_desc=$(iniget "${CFG_FILE}" "${release}" "description")
            rel_iso=$(iniget "${CFG_FILE}" "${release}" "iso")
            rel_edits=$(iniget "${CFG_FILE}" "${release}" "editions")
            rel_unattend_templ_prefix=$(iniget "${CFG_FILE}" "${release}" "unattend_template_prefix")
            if [ -z "${rel_unattend_templ_prefix}" ]; then
                rel_unattend_templ_prefix="${release}"
            fi
            if [ -f "${rel_iso}" ]; then
                for rel_edition in ${rel_edits}
                do
                    rel_unattend_templ_dir="${START_DIR}/lib/windowssetup/unattend/${rel_unattend_templ_prefix}-${rel_edition}"
                    rel_vms_temp_dir="${Config["vmsworkdir"]}/${rel_unattend_templ_prefix}-${rel_edition}"
                    mkdir -p "${rel_vms_temp_dir}" || exit 2
                    make_virtualfloppy "${rel_unattend_templ_dir}" "${rel_vms_temp_dir}"
                    if [ "$?" -ne 0 ]; then
                        log "Err: Can't create virtual floppy at ${rel_vms_temp_dir} with autounattend.xml !"
                        exit 2
                    fi
                    copy_virtiodrv "${rel_vms_temp_dir}"
                    if [ "$?" -ne 0 ]; then
                        log "Err: Can't copy virt-io drivers iso(${Config["virtio_iso"]}) to ${rel_vms_temp_dir} !"
                        exit 2
                    fi
                    log "[${release}] - ${rel_edition} - build started at - ${rel_vms_temp_dir}..."
                    start_win_vm "${rel_vms_temp_dir}" "${rel_iso}"
                done
            else
                log "Err: Can't access ${rel_iso}, please check ${CFG_FILE} [${release}] section!"
            fi
        fi
    done
}
# usage
function usage()
{
    echo  "${0} --help - Help information
         --check-smb - Check or configure Samba server, please RUN this command at 1st!(${CFG_FILE} [samba] options)
         --download-requirements - Download required software dicribed in ${CFG_FILE}
         --show-configured - Display chosen MS Windows releases to build(${CFG_FILE} [default]/available_win_versions value)
         --run - Run automated image creation"
}
# aka main
function run_normal()
{
    check_free_space
    check_libvirtnet
    prepare_corefunctions_ps
    downloadrequirements
    preparemirror
    prepare_local_sambaserver
    if [ "$?" -eq 0 ]; then
        checkmountremote
        mountremote
        copymirrortomnt
        process_windows
        sleep 1
        umountremote
    fi
    rm -f "${Config["smbcredsfile"]}" 2>/dev/null
}
#------------------------------------------------------------------------------
# start of main logic
#
if [ "$#" -eq 0 ]; then
    usage
    exit 1
fi
#
check_sys_packages false
init
# processing command line args
while [ "$#" -ge 1 ]
do
key="${1}"
case ${key} in
    --show-configured)
        show_configured_win_releases
        break
        ;;
    --config-file)
        if [ ! -z "${2}" ] & [ -f "${2}" ]; then
            CFG_FILE="${2}"
            init
        else
            echo "Config file not set properly!"
            exit 2
        fi
        shift
        ;;
    --download-requirements)
        downloadrequirements
        break
        ;;
    --check-smb)
        prepare_local_sambaserver true true
        if [ "$?" -eq 0 ]; then
            checkmountremote
            mountremote
            sleep 1
            umountremote
            rm -f "${Config["smbcredsfile"]}" 2>/dev/null
        fi
        break
        ;;
    --forceinstall-dependencies)
        check_sys_packages true
        shift
        ;;
    --run)
        run_normal
        break
        ;;
    *)
        usage
        break
        ;;
esac
shift
done
#------------------------------------------------------------------------------
