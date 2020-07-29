#!/bin/bash

# For usage, run without arguments
#

VM_NAME=$1
DVD_PATH=${2:---}
OS_TYPE="${3:-${OS_TYPE:-Windows10_64}}"
RAM_SIZE="${4:-${RAM_SIZE:-8192}}"
HDD_SIZE="${5:-${HDD_SIZE:-51200}}"
NUM_CPUS="${6:-${NUM_CPUS:-2}}"
#VRDE_PORT="${7:-${VRDE_PORT:-3393}}"
#PNIC=enp6s0

SCRIPT_NAME="$(basename "$0")"

print_usage_and_exit()
{
  cat <<-MSG | sed -e 's/^  //'

  $SCRIPT_NAME: provisions a virtualbox VM"

  Usage:

     $SCRIPT_NAME VM_NAME [DVD_PATH|--] [OS_TYPE] [RAM_SIZE] [HDD_SIZE] [NUM_CPUS] [VRDE_PORT]

     To provision from ISO:

        $SCRIPT_NAME vm1 path/to/filename.iso

     To provision from PXE:

        $SCRIPT_NAME vm1 --

     To provision using defaults, except for a later argument:

        NUM_CPUS=3 $SCRIPT_NAME vm1

     After provisioning the VM, use normal VirtualBox commands to use it:

       VBoxManage startvm vm1 -type headless  # Start the VM
       VBoxManage controlvm vm1 poweroff      # Shutdown the VM
       VBoxManage controlvm vm1 reset         # Reboot the VM
       VBoxManage unregistervm vm1 --delete   # Delete the VM

   WARNING: If VM_NAME already exists, it will be destroyed and re-provisioned!

MSG
  exit 0
}

MACHINE_FOLDER=$(VBoxManage list systemproperties | grep '^Default machine folder:' | cut -d: -f 2 | sed -e 's/^ *//g;s/ *$//g')
HDD_PATH="${MACHINE_FOLDER}/${VM_NAME}/${VM_NAME}.vdi"
[ -z "$1" ] && print_usage_and_exit

VBoxManage showvminfo "$VM_NAME" >& /dev/null
if [ $? -eq 0 ]; then
  echo "== WARNING: VM '$VM_NAME' already exists... DELETING! =="
  VBoxManage unregistervm "$VM_NAME" --delete
  echo '=================='
  VBoxManage closemedium "$HDD_PATH" &> /dev/null
  [ -f "$HDD_PATH" ] && rm -f "$HDD_PATH"
fi

VBoxManage createvm -name "$VM_NAME" -ostype "$OS_TYPE" --register || exit 10

VBoxManage modifyvm "$VM_NAME" \
    --memory "$RAM_SIZE" \
    --cpus "$NUM_CPUS" \
    --vram 128 \
    --clipboard bidirectional \
    --pae on \
    --apic on \
    --usbxhci on \
    --nic1 bridged
[ $? -eq 0 ] || exit 1

VBoxManage createmedium disk --filename "$HDD_PATH" --size "$HDD_SIZE" --format VDI || exit 11
VBoxManage storagectl "$VM_NAME" --name "IDE Controller" --add ide || exit 12
VBoxManage storagectl "$VM_NAME" --name "SATA Controller" --add sata  || exit 13

if [ "$DVD_PATH" != "--" ]; then
  VBoxManage storageattach "$VM_NAME" --storagectl "IDE Controller" --port 1 \
     --device 0 --type dvddrive --medium "$DVD_PATH" || exit 14
fi

VBoxManage storageattach "$VM_NAME" --storagectl "SATA Controller" --port 0 \
  --device 0 --type hdd --medium "$HDD_PATH" || exit 15

VBoxManage sharedfolder add "$VM_NAME" --name shared --hostpath  "/home/${USER}/Downloads"
