#!/bin/bash

set -e

#### Preflight Checks ####

# Make sure we're root.
if [[ "$(id -u)" -ne 0 ]]; then
  echo "Please run this script as root or with sudo."
  exit 1
fi

#### Collect Data For Install ####

# List all disks, exclude partitions, exclude USB and loop devices.
DISKS="$(lsblk -pldn -o TRAN,NAME,SIZE | grep -v 'usb' | grep -v 'loop' | tr -s ' ' | cut -d ' ' -f 2)"
DISK_NUM="$(lsblk -pldn -o TRAN | grep -v -e '^$' | wc -l)"

# Show user the disks on system.
echo "I found the following disks on your system:"
for DISK in $DISKS; do
    echo "- $DISK"
done

# Prompt user to enter the disk they want to install on.
while [[ ! -e "$PRE_BOOT_DISK" ]]; do
    echo ""
    read -r -p "Please enter the disk you want to install on (eg. /dev/sda, /dev/nvme0n1, /dev/vda, etc.): " PRE_BOOT_DISK
done

# Prompt user for LUKS unlock.
while [[ -z "$PRE_LUKS_PASS" ]]; do
    echo ""
    read -r -i "unl0ckMyD1sk" -p "Please enter a LUKS password or accept the default: " -e PRE_LUKS_PASS
done

# Prompt user for local admin info.
while [[ -z "$PRE_NEW_USER" ]]; do
    echo ""
    read -r -i "ubuntu" -p "Please enter a local admin username or accept the default: " -e PRE_NEW_USER
done
while [[ -z "$PRE_USER_PASS" ]]; do
    echo
    read -r -i "ubuntu" -p "Please enter a local admin password or accept the default: " -e PRE_USER_PASS
done

# Prompter user for install type.
while [[ -z "$PRE_INSTALL_TYPE" ]]; do
    echo ""
    read -r -i "desktop" -p "Please enter an install type or accept the default (Valid types are 'desktop' and 'server'): " -e PRE_INSTALL_TYPE
done

# Prompter user for dual-boot or single-boot.
while [[ -z "$PRE_DUAL_BOOT" ]]; do
    echo ""
    read -r -i "no" -p "Please indicate whether the system is a dual-boot or accept the default (Valid types are 'yes' and 'no'): " -e PRE_DUAL_BOOT
done

# Prompt user for timezone.
while [[ -z "$PRE_TIMEZONE" ]]; do
    echo ""
    read -r -i "America/Los_Angeles" -p "Please enter a timezone or accept the default: " -e PRE_TIMEZONE
done

# Prompt user for locale.
while [[ -z "$PRE_LOCALE" ]]; do
    echo ""
    read -r -i "en_US.UTF-8" -p "Please enter a locale or accept the default: " -e PRE_LOCALE
done

#### Export Answers ###
if [[ $PRE_BOOT_DISK =~ "nvme" ]]; then
    PRE_EFI_PART="$PRE_BOOT_DISK"p1
    PRE_BOOT_PART="$PRE_BOOT_DISK"p2
    PRE_ROOT_PART="$PRE_BOOT_DISK"p3
else
    PRE_EFI_PART="$PRE_BOOT_DISK"1
    PRE_BOOT_PART="$PRE_BOOT_DISK"2
    PRE_ROOT_PART="$PRE_BOOT_DISK"3
fi

touch confs/answers.env
echo '#!/bin/bash' >> confs/answers.env
echo "export LUKS_PASS=$PRE_LUKS_PASS" >> confs/answers.env
echo "export BOOT_DISK=$PRE_BOOT_DISK" >> confs/answers.env
echo "export EFI_PART=$PRE_EFI_PART" >> confs/answers.env
echo "export BOOT_PART=$PRE_BOOT_PART" >> confs/answers.env
echo "export ROOT_PART=$PRE_ROOT_PART" >> confs/answers.env
echo "export DUAL_BOOT=$PRE_DUAL_BOOT" >> confs/answers.env
echo "export TIMEZONE=$PRE_TIMEZONE" >> confs/answers.env
echo "export LOCALE=$PRE_LOCALE" >> confs/answers.env
echo "export NEW_USER=$PRE_NEW_USER" >> confs/answers.env
echo "export USER_PASS=$PRE_USER_PASS" >> confs/answers.env
echo "export INSTALL_TYPE=$PRE_INSTALL_TYPE" >> confs/answers.env

echo "export PRE_INSTALL=COMPLETE" >> confs/answers.env

echo 'Answers file complete, starting the install...'
./01_base_install.sh
