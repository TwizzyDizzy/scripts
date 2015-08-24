#!/bin/bash

# script script the process of bringing up powered off USB SATA devices
# and assembling them into the given MD raid device. This script
# is pretty much tailored to my needs so you may use it rather as an
# inspiration than using it in its current form.

MD_RAID_DEVICE="behring5.chickenkiller.com:0"
MD_RAID_COMPONENTS="/dev/disk/by-id/usb-WDC_WD50_00AAKX-001CA0_DCAD43109288-0:0-part1 /dev/disk/by-id/usb-WDC_WD50_00AAKX-001CA0_DCAD43109288-0:1-part1"

# what to do with the MD raid, "on" or "off"
ACTION=$1

if [[ "$ACTION" != "on" && "$ACTION" != "off" ]]; then
	echo "Action must be either \"on\" or \"off\"!"
	exit 1
fi


if [[ "$ACTION" == "on" ]]; then
	# switch on physical hard drives, as they are currently sleeping and spun down
	./switch-disk.sh 0 on
	./switch-disk.sh 1 on

	# assemble MD raid
	mdadm --assemble $MD_RAID_DEVICE $MD_RAID_COMPONENTS

	# mount MD device to path specified in /etc/fstab
	mount /dev/disk/by-id/$MD_RAID_DEVICE
else
	# if $ACTION is "OFF"

	# sync to disk
	sync

	# unmount MD device
	umount /dev/disk/by-id/$MD_RAID_DEVICE

	# stopping the MD raid device
	mdadm --stop /dev/disk/by-id/$MD_RAID_DEVICE

	./switch-disk.sh 0 off
	./switch-disk.sh 1 off
fi
