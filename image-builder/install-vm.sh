#!/bin/sh
# automation job script
 

# Variables below may be changed thru 'env' command when script called like
#   env BUILD_ROOT=/opt install-vm.sh
# PLEASE BE CAREFUL RENAMING THEM!
BUILD_ROOT=${BUILD_ROOT:='/opt/build-system'}
VM_NAME=${VM_NAME:='WinServ2k12-custom'}-REF
VM_IMG_SIZE='40G'
BOOT_ISO=${BOOT_ISO:='ws-2012-eval.iso'}
VIRTIO_ISO=${VIRTIO_ISO:='virtio-win-0.1-52.iso'}
FLOPPY_IMG=${FLOPPY_IMG:='floppy.img'}

# Other variables
LIBVIRT_IMAGES_DIR=$BUILD_ROOT/libvirt/images
HDD_IMG_NAME="$VM_NAME.img"
VM_IMG_PATH="$LIBVIRT_IMAGES_DIR/$HDD_IMG_NAME"
VM_REF_IMG_PATH="$BUILD_ROOT/share/images/ws-2012-core.qcow2"



# Functions
#------------------------------------------------------------------------------

die() {
    echo ''
    echo "STOP: $@"
    echo '*** SCRIPT FAILED ***'
    echo ''
    exit 1
}


prealloc_img() {
    echo ''
    echo '-> Allocating new image file for VM ...'
    echo "* Image file: '$VM_IMG_PATH', requested size: '$VM_IMG_SIZE'"
    qemu-img create -f raw $VM_IMG_PATH $VM_IMG_SIZE \
      || die "Command 'qemu-img create' failed."
    echo '<- done'
}


compress_and_transfer_ready_img() {
    echo ''
    echo '-> Converting VM image to QCOW2 format ...'
    echo "* Compressing QCOW2 image ('$VM_IMG_PATH' --> '$VM_REF_IMG_PATH') ..."
    qemu-img convert -O qcow2 $VM_IMG_PATH $VM_REF_IMG_PATH \
      || die "Command 'qemu-img convert' failed."
    echo '<- done'
}


start_vm_install() {
    echo ''
    echo '-> Starting VM ...'
    virt-install --connect qemu:///system \
      --hvm \
      --name $VM_NAME \
      --ram 2048 \
      --vcpus 2 \
      --cdrom $LIBVIRT_IMAGES_DIR/$BOOT_ISO \
      --disk path=$LIBVIRT_IMAGES_DIR/$VIRTIO_ISO,device=cdrom \
      --disk path=$LIBVIRT_IMAGES_DIR/$FLOPPY_IMG,device=floppy \
      --disk path=$VM_IMG_PATH,format=raw,bus=virtio,io=native,cache=none \
      --network network=default,model=virtio \
      --vnc \
      --os-type=windows \
      --os-variant=win2k8 \
      --noautoconsole \
      --accelerate \
      --noapic \
      --keymap=en-us \
      --video=cirrus \
      --force

    if [ $? -ne 0 ]; then
        die "virt-install for VM '$VM_NAME' failed."
    fi

    # waiting for autounuttended setup completes
    while true 
    do 
        DOM_STATE=$(get_domain_state $VM_NAME)
        if [ "$DOM_STATE" = 'shut off' ]; then 
            break
        else 
            echo "* Domain $VM_NAME still running"
            sleep 60
        fi
    done

    echo '<- done'
}


delete_vm() {
    echo ''
    echo '-> Deleting VM ...'
    #virsh undefine $VM_NAME --storage $VM_IMG_PATH
    virsh undefine $VM_NAME || die "Unable to undefine VM '$VM_NAME'."
    #virsh vol-delete $VM_IMG_PATH || die "Unable to delete volume '$VM_IMG_PATH'."
    echo '<- done'
}



get_domain_state() {
    local domain_name
    local domain_state
    
    domain_name=$1
    domain_state=$(virsh domstate $domain_name)
    if [ $? -ne 0 ] ; then
        echo ''
    fi
    echo $domain_state
}

#------------------------------------------------------------------------------




# Workflow steps below
#------------------------------------------------------------------------------
# Check if guest vm with same name exists and not running
#-----
DOM_STATE=$(get_domain_state $VM_NAME)

if [ -z "$DOM_STATE" ]; then
    echo "Domain '$VM_NAME' not exist."
else
    if [ "$DOM_STATE" != 'shut off' ]; then
        die "Guest '$VM_NAME' exists and in state '$DOM_STATE'."
    fi

    echo ''
    echo "Guest '$VM_NAME' exists, shut off and will be deleted."
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
#delete_vm
#-----


echo ''
echo "Work done, reference system image path is '$VM_REF_IMG_PATH'."
echo ''

#------------------------------------------------------------------------------

