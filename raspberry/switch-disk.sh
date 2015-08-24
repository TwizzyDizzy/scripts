#!/bin/bash

# this script is used in the wrapper script "switch_raid.sh"

# script to enable or disable a hard disk on my Raspberry Pi. This script
# is pretty much tailored to my needs so you may use it rather as an
# inspiration than using it in it's current form.

# the ATA controller in my external USB device is the JMicron JMB363

CONTROLLER_BASE_PATH="/dev/disk/by-id/usb-WDC_WD50_00AAKX-001CA0_DCAD43109288-0"

# use device on my jmicron crontroller port X
CONTROLLER_PORT=$1

DEVICE="$CONTROLLER_BASE_PATH:$CONTROLLER_PORT"

# what to do with the drive, "on" or "off"
ACTION=$2

if [[ "$CONTROLLER_PORT" -ne "0" && "$CONTROLLER_PORT" -ne "1" ]]; then
	echo "Controller Port must be either \"0\" or \"1\"!"
	exit 1
fi

if [[ "$ACTION" != "on" && "$ACTION" != "off" ]]; then
	echo "Action must be either \"on\" or \"off\"!"
	exit 1
fi

if [[ "$ACTION" == "on" ]]; then
	# read raw disk data while bypassing the host cache and most probably
	# the disk cache, too. Need to investigate the latter.
	dd if=$DEVICE count=1 iflag=direct > /dev/null 2>&1
else
	# if $ACTION is "OFF"
	smartctl -q silent -d usbjmicron,$CONTROLLER_PORT -s standby,now $DEVICE
fi
