#!/bin/sh

reboot_pi () {
  umount /boot
  sync
  echo b > /proc/sysrq-trigger
  sleep 5
  exit 0
}

check_commands () {
  if ! command -v whiptail > /dev/null; then
      echo ="whiptail not found"
      sleep 5
      return 1
  fi
  for COMMAND in grep cut sed parted fdisk; do
    if ! command -v $COMMAND > /dev/null; then
      FAIL_REASON="$COMMAND not found"
      return 1
    fi
  done
  return 0
}

check_noobs () {
  if [ "$BOOT_PART_DEV" = "/dev/mmcblk0p1" ]; then
    NOOBS=0
  else
    NOOBS=1
  fi
}

get_variables () {
  ROOT_PART_DEV=`grep -Eo 'root=[[:graph:]]+' /proc/cmdline | cut -d "=" -f 2-`
  ROOT_PART_NAME=`echo $ROOT_PART_DEV | cut -d "/" -f 3`
  ROOT_DEV_NAME=`echo /sys/block/*/${ROOT_PART_NAME} | cut -d "/" -f 4`
  ROOT_DEV="/dev/${ROOT_DEV_NAME}"
  ROOT_PART_NUM=`cat /sys/block/${ROOT_DEV_NAME}/${ROOT_PART_NAME}/partition`

  BOOT_PART_DEV=`cat /proc/mounts | grep " /boot " | cut -d " " -f 1`
  BOOT_PART_NAME=`echo $BOOT_PART_DEV | cut -d "/" -f 3`
  BOOT_DEV_NAME=`echo /sys/block/*/${BOOT_PART_NAME} | cut -d "/" -f 4`
  BOOT_PART_NUM=`cat /sys/block/${BOOT_DEV_NAME}/${BOOT_PART_NAME}/partition`

  check_noobs

  ROOT_DEV_SIZE=`cat /sys/block/${ROOT_DEV_NAME}/size`
  TARGET_END=`expr $ROOT_DEV_SIZE - 1`

  PARTITION_TABLE=`parted -m $ROOT_DEV unit s print | tr -d 's'`

  LAST_PART_NUM=`echo "$PARTITION_TABLE" | tail -n 1 | cut -d ":" -f 1`

  ROOT_PART_LINE=`echo "$PARTITION_TABLE" | grep -e "^${ROOT_PART_NUM}:"`
  ROOT_PART_START=`echo $ROOT_PART_LINE | cut -d ":" -f 2`
  ROOT_PART_END=`echo $ROOT_PART_LINE | cut -d ":" -f 3`

  if [ "$NOOBS" = "1" ]; then
    EXT_PART_LINE=`echo "$PARTITION_TABLE" | grep ":::;" | head -n 1`
    EXT_PART_NUM=`echo $EXT_PART_LINE | cut -d ":" -f 1`
    EXT_PART_START=`echo $EXT_PART_LINE | cut -d ":" -f 2`
    EXT_PART_END=`echo $EXT_PART_LINE | cut -d ":" -f 3`
  fi
}

check_variables () {
  if [ "$NOOBS" = "1" ]; then
    if [ $EXT_PART_NUM -gt 4 ] || \
       [ $EXT_PART_START -gt $ROOT_PART_START ] || \
       [ $EXT_PART_END -lt $ROOT_PART_END ]; then
      FAIL_REASON="Unsupported extended partition"
      return 1
    fi
  fi

  if [ $ROOT_PART_NUM -ne $LAST_PART_NUM ]; then
    FAIL_REASON="Root partition should be last partition"
    return 1
  fi

  if [ $ROOT_PART_END -gt $TARGET_END ]; then
    FAIL_REASON="Root partition runs past the end of device"
    return 1
  fi

  if [ ! -b $ROOT_DEV ] || [ ! -b $ROOT_PART_DEV ] || [ ! -b $BOOT_PART_DEV ] ; then
    FAIL_REASON="Could not determine partitions"
    return 1
  fi
}

main () {
  get_variables

  if ! check_variables; then
    return 1
  fi

  if [ "$NOOBS" = "1" ]; then
    BCM_MODULE=`cat /proc/cpuinfo | grep -e "^Hardware" | cut -d ":" -f 2 | tr -d " " | tr '[:upper:]' '[:lower:]'`
    if ! modprobe $BCM_MODULE; then
      FAIL_REASON="Couldn't load BCM module $BCM_MODULE"
      return 1
    fi
    echo $BOOT_PART_NUM > /sys/module/${BCM_MODULE}/parameters/reboot_part
  fi

  if [ $ROOT_PART_END -eq $TARGET_END ]; then
    reboot_pi
  fi

  if [ "$NOOBS" = "1" ]; then
    if ! parted -m $ROOT_DEV u s resizepart $EXT_PART_NUM yes $TARGET_END; then
      FAIL_REASON="Extended partition resize failed"
      return 1
    fi
  fi

if ! parted -m $ROOT_DEV u s resizepart $ROOT_PART_NUM $TARGET_END; then
    FAIL_REASON="Root partition resize failed"
    return 1
  fi

  return 0
}

mount -t proc proc /proc
mount -t sysfs sys /sys

mount /boot
sed -i 's/ quiet init=.*$//' /boot/cmdline.txt
mount /boot -o remount,ro
sync

echo 1 > /proc/sys/kernel/sysrq

if ! check_commands; then
  reboot_pi
fi

if main; then
  whiptail --infobox "Resized root filesystem. Rebooting in 5 seconds..." 20 60
  sleep 5
else
  sleep 5
  whiptail --msgbox "Could not expand filesystem, please try raspi-config or rc_gui.\n${FAIL_REASON}" 20 60
fi

reboot_pi
