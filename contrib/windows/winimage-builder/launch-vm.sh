#!/bin/bash
# automation job script
export LANG=C
export LC_ALL=C
# Default values
IMAGE_BUILDER_ROOT=${IMAGE_BUILDER_ROOT:-'/opt/build-system'}
VIRTIO_ISO=${VIRTIO_ISO:-'virtio-win-0.1-52.iso'}
VM_IMG_SIZE=${VM_IMG_SIZE:-'40G'}
VM_IMG_FORMAT=${VM_IMG_FORMAT:-'raw'}
VM_NETWORK_NAME=${VM_NETWORK_NAME:-default}

# Variables below may be changed thru 'env' command when script called like
#   env IMAGE_BUILDER_ROOT=/opt install-vm.sh
# PLEASE BE CAREFUL RENAMING THEM!
IMAGE_NAME=${IMAGE_NAME:-'ws-2012-std'}
VM_NAME=${VM_NAME:-${IMAGE_NAME}-REF}
BOOT_ISO=${BOOT_ISO:-'ws-2012-eval.iso'}
FLOPPY_IMG=${FLOPPY_IMG:-'floppy.img'}

# Other variables
IMAGES_DIR=${IMAGE_BUILDER_ROOT}
VM_IMG_NAME=${VM_NAME}.${VM_IMG_FORMAT}
VM_IMG_PATH=${IMAGES_DIR}/${VM_IMG_NAME}
VM_REF_IMG_PATH=${IMAGE_BUILDER_ROOT}/$(basename "${IMAGE_BUILDER_ROOT}")-ref.qcow2
VM_REF_IMG_COPY_TO_WORKSPACE=${VM_REF_IMG_COPY_TO_WORKSPACE:-false}

# Tuncating VM name to 50 chars
VM_NAME="${VM_NAME:0:50}"

# Functions
#------------------------------------------------------------------------------
# exit on error
function die()
{
    cat << EOF
*** SCRIPT FAILED ***
"$#"
EOF
    exit 1
}

function die_if_no_file()
{
    if [ ! -f "${1}" ]; then
        die "File '${1}' not exist!"
    fi
}
# creting empty image
function prealloc_img() {
    echo ''
    echo '-> Allocating new image file for VM ...'
    echo "* Image file: '${VM_IMG_PATH}', requested size: '${VM_IMG_SIZE}'"
    if [ -f "${VM_IMG_PATH}" ]; then die "Err: image ${VM_IMG_PATH} exists!"; fi
    qemu-img create -f ${VM_IMG_FORMAT} ${VM_IMG_PATH} ${VM_IMG_SIZE} || die "Command 'qemu-img create' failed."

    echo '<- done'
}
# process ready image
function compress_and_transfer_ready_img() {
    echo ''
    echo '-> Converting VM image to QCOW2 format ...'
    echo "* Compressing QCOW2 image ('${VM_IMG_PATH}' --> '${VM_REF_IMG_PATH}') ..."
    qemu-img convert -O qcow2 ${VM_IMG_PATH} ${VM_REF_IMG_PATH} || die "Command 'qemu-img convert' failed."
    if [ "${VM_REF_IMG_COPY_TO_WORKSPACE}" != false ]; then
        cp -f ${VM_REF_IMG_PATH} ${VM_REF_IMG_COPY_TO_WORKSPACE}
        rm "${VM_REF_IMG_PATH}"
        if [ -f "${VM_REF_IMG_COPY_TO_WORKSPACE}" ]; then VM_REF_IMG_PATH="${VM_REF_IMG_COPY_TO_WORKSPACE}"; fi
    fi
    echo '<- done'
}
# start vm install
function start_vm_install() {
    echo ''
    echo '-> Starting VM ...'
    virt-install --connect qemu:///system \
      --hvm \
      --name ${VM_NAME} \
      --ram 2048 \
      --vcpus 2 \
      --cdrom ${BOOT_ISO} \
      --disk path=${VIRTIO_ISO},device=cdrom \
      --disk path=${FLOPPY_IMG},device=floppy \
      --disk path=${VM_IMG_PATH},format=${VM_IMG_FORMAT},bus=virtio,io=native,cache=none \
      --network network=${VM_NETWORK_NAME},model=virtio \
      --vnc \
      --os-type=windows \
      --os-variant=win2k8 \
      --noautoconsole \
      --accelerate \
      --noapic \
      --keymap=en-us \
      --video=cirrus \
      --force
    if [ "$?" -ne 0 ]; then
        die "virt-install for VM '${VM_NAME}' failed."
    fi
    # waiting for autounuttended setup completes
    while true; do
        DOM_STATE=$(get_domain_state "${VM_NAME}")
        if [ "${DOM_STATE}" = 'shut off' ]; then
            break
        else
            echo "* Domain ${VM_NAME} still running"
            sleep 60
        fi
    done
    echo '<- done'
}
# delete vm after install
function delete_vm()
{
    echo ''
    echo '-> Deleting VM ...'
    virsh undefine ${VM_NAME} || die "Unable to undefine VM '${VM_NAME}'."
    rm -f "$VIRTIO_ISO"
    rm -f "$FLOPPY_IMG"
    rm -f "$VM_IMG_PATH"
    rm -rf "$IMAGE_BUILDER_ROOT"
    echo '<- done'
}
# checking vm install state
function get_domain_state()
{
    local domain_name
    local domain_state
    domain_name="${1}"
    domain_state=$(LANG=C virsh domstate "${domain_name}")
    if [ "$?" -ne 0 ] ; then
        echo ''
    fi
    echo "${domain_state}"
}

#------------------------------------------------------------------------------

# Check if files are exist
#-------------------------
die_if_no_file "$BOOT_ISO"
die_if_no_file "$VIRTIO_ISO"
die_if_no_file "$FLOPPY_IMG"
#-------------------------

# Workflow steps below
#------------------------------------------------------------------------------
# Check if guest vm with same name exists and not running
#-----
DOM_STATE=$(get_domain_state "${VM_NAME}")

if [ -z "${DOM_STATE}" ]; then
    echo "Domain '${VM_NAME}' not exist."
else
    if [ "${DOM_STATE}" != 'shut off' ]; then
        die "Guest '${VM_NAME}' exists and in state '${DOM_STATE}'."
    fi
    echo ''
    echo "Guest '${VM_NAME}' exists, shut off and will be deleted."
    delete_vm
fi
#-----
# Preallocate guest vm disk image
#-----
prealloc_img
#-----
# Start guest vm installation
#-----
start_vm_install
#-----
# Compress and copy redy image
#-----
compress_and_transfer_ready_img
#-----
# Delete vm
#-----
delete_vm
#-----
echo ''
echo "Work done, reference system image path is '${VM_REF_IMG_PATH}'."
echo ''
#------------------------------------------------------------------------------
