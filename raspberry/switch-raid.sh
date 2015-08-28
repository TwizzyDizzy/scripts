#!/bin/bash

# Script to enable or disable an external hard disk on my Raspberry Pi.
# It is pretty much tailored to my needs so you may use it rather as an
# inspiration than using it in it's current form. SATA controller in my
# external USB device is the JMicron JMB363.
#
# This script assumes, that the MD raid will be auto assembled on turning on the disks.
# You may take appropriate steps to make sure this happens. To my knowledge this includes
# at least setting the partition type of the raid partitions to "fd" (Linux raid auto)
#
# This script is to be used by scripts that want to write or read something from this
# otherwise turned off MD raid.
#
# The script handles concurrent script calls meaning that no script will be able to shutdown
# the raid while another script is still running and using the raid.
#
# Example: write or read something from disk with prio spinup and shutdown afterwards.
#
# #!/bin/bash
#
# . /path/to/switch-raid.sh
# 
# if ! switch_raid_on; then
#   echo "Danger, Danger! The raid was not brought up successfully!"
#   exit 1
# else
#   [write something to disk or read something from disk]
#
#   if ! switch_raid_off; then
#     echo "Danger, Danger! The raid could not be shut down properly. It is now locked for further interaction in its current state!"
#     exit 1
#   fi

export RAID_SPINUP_TIME=15
export RAID_USB_PORT="1-1.2"
export CONTROLLER_BASE_PATH="/dev/disk/by-id/usb-WDC_WD50_00AAKX-001CA0_DCAD43109288-0"
export MD_RAID_NAME="behring5.chickenkiller.com:0"
export MD_RAID_DEVICE="/dev/disk/by-id/md-name-$MD_RAID_NAME"
export DEVICE_MD_NAME="md0"
export RAID_LOCKFILE="/root/raid-locked"
export UNIQUE_RUN_IDENTIFIER=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
export RAID_RUNFILE_BASE="/root/raid-used"
export RAID_RUNFILE_UNIQUE="$RAID_RUNFILE_BASE-$UNIQUE_RUN_IDENTIFIER"
export RAID_INITFILE_BASE="/root/raid-initializing"
export RAID_INITFILE_UNIQUE="$RAID_INITFILE_BASE-$UNIQUE_RUN_IDENTIFIER"
export RAID_SHUTDOWNFILE_BASE="/root/raid-shutdown"
export RAID_SHUTDOWNFILE_UNIQUE="$RAID_SHUTDOWNFILE_BASE-$UNIQUE_RUN_IDENTIFIER"

function bind_usb {
	echo "1-1.2" > /sys/bus/usb/drivers/usb/bind
	return $?
}

function unbind_usb {
	echo "1-1.2" > /sys/bus/usb/drivers/usb/unbind
	return $?
}

function raid_used {
	# returns 1 if there is another process already using the raid, otherwise 0
	if [[ $(ls -1 $RAID_RUNFILE_BASE-* 2>/dev/null | grep -v $UNIQUE_RUN_IDENTIFIER | wc -l) -gt "0" ]]; then
		return 0
	else
		return 1
	fi
}

function raid_initializing {
	# returns 1 if there is another process currently starting the raid
	if [[ $(ls -1 $RAID_INITFILE_BASE-* 2>/dev/null | grep -v $UNIQUE_RUN_IDENTIFIER | wc -l) -gt "0" ]]; then
		return 0
	else
		return 1
	fi
}

function raid_shutting_down {
	# returns 1 if there is another process currently starting the raid
	if [[ $(ls -1 $RAID_SHUTDOWNFILE_BASE-* 2>/dev/null | grep -v $UNIQUE_RUN_IDENTIFIER | wc -l) -gt "0" ]]; then
		return 0
	else
		return 1
	fi
}

function switch_disk_off {
	# use device on my jmicron crontroller port X
	CONTROLLER_PORT=$1

	DEVICE="$CONTROLLER_BASE_PATH:$CONTROLLER_PORT"

	if [[ "$CONTROLLER_PORT" -ne "0" && "$CONTROLLER_PORT" -ne "1" ]]; then
		echo "Controller Port must be either \"0\" or \"1\"!"
		return 1
	fi

	# send device into "Stand-by"-mode (aka "spin down disk")
	smartctl -q silent -d usbjmicron,$CONTROLLER_PORT -s standby,now $DEVICE

	# check if drive was shut down properly
	if ! smartctl -x -d usbjmicron,$CONTROLLER_PORT $DEVICE | grep "Device State" | grep -q Stand-by; then
		echo "Device $DEVICE has not been shut down properly. Please investigate."
		return 1
	else
		return 0
	fi
}

function lock_raid {
	export LOCK_RAID=1
	touch $RAID_LOCKFILE
}

function switch_raid_on {
	# abort if raid is locked
	if [[ -f $RAID_LOCKFILE ]]; then
		echo "Raid has been locked. Please investigate errors and remove the lockfile $RAID_LOCKFILE after all errors have been fixed"
		return 1
	fi


	# abort if another process has already started the raid
	# return 0, because this is no error. the calling script can now write to the raid
	if raid_used || raid_initializing; then
		# wait for other process's spin up to complete
		sleep $RAID_SPINUP_TIME
		return 0
	else
		touch $RAID_INITFILE_UNIQUE

		# bind usb port - this will lead to the disks spinning up, the raid will auto-assemble, too
		bind_usb

		# wait for disks to spin up and for raid to auto-assemble
		sleep $RAID_SPINUP_TIME
	fi

	if ! mount $MD_RAID_DEVICE; then
		echo "$MD_RAID_DEVICE could not be mounted to the path specified in /etc/fstab. Please investigate."
		return 1
		lock_raid
	fi

	rm $RAID_INITFILE_UNIQUE
	touch $RAID_RUNFILE_UNIQUE
	return 0
}

function switch_raid_off {
	# abort if raid is locked
	if [[ -f $RAID_LOCKFILE ]]; then
		echo "Raid has been locked. Please investigate errors and remove the lockfile $RAID_LOCKFILE after all errors have been fixed."
		return 1
	fi

	# return 0, because this is no error. the calling script does not need to shut down the raid
	# because there is another process still running that will shutdown the raid after finishing
	if raid_used || raid_shutting_down; then
		return 0
	fi

	touch $RAID_SHUTDOWNFILE_UNIQUE

	# sync to disk
	sync

	# unmount MD device
	if ! umount $MD_RAID_DEVICE; then
		echo "$MD_RAID_DEVICE could not be unmounted. Please investigate. Raid has been locked."
		lock_raid
	fi

	# stopping the MD raid device
	if ! mdadm --quiet --stop $MD_RAID_DEVICE; then
		echo "$MD_RAID_DEVICE could not be stopped. Please investigate. Raid has been locked."
		lock_raid
	fi

	# send physical hard drives to standby. This will make the disks spin down
	if ! switch_disk_off 0 || ! switch_disk_off 1; then
		echo "One of the hard drives could not be shut down properly. Please investigate. Raid has been locked."
		lock_raid
	fi

	# unbind USB device so no bus scans will wake up the devices from their spun down state
	# ! need to investigate on what made the disks spin up automatically after some time
	# ! but I guess this was some regular USB bus scan or something? Any clues? Send me a mail!
	unbind_usb

	if [[ -z "$LOCK_RAID" ]]; then
		# remove runfile so other calls of switch_raid_on will mount the raid again.
		rm $RAID_SHUTDOWNFILE_UNIQUE
		rm $RAID_RUNFILE_UNIQUE
		return 0
	else
		# some error occured above, raid raid has now be locked for further actions
		# manual intervention is necessary
		return 1
	fi
}
