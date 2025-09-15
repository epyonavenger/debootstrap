#!/bin/bash

set -e

#### Preflight Checks ####

# Make sure we're root.
if [[ "$(id -u)" -ne 0 ]]; then
  echo "## Please run this script as root or with sudo. ##"
  exit 1
fi

#### Collect Data For Install ####

# List all disks, exclude partitions, exclude USB and loop devices.
DISKS="$(lsblk -pldn -o TRAN,NAME,SIZE | grep -v 'usb' | grep -v 'loop' | tr -s ' ' | cut -d ' ' -f 2)"
DISK_NUM="$(lsblk -pldn -o TRAN | grep -v -e '^$' | wc -l)"

# Show user the disks on system.
echo "## I found the following disks on your system. ##"
for DISK in $DISKS; do
    echo "- $DISK"
done

# Prompt user to enter the disk they want to install on.
while [[ ! -e "$PRE_BOOT_DISK" ]]; do
    echo ""
    echo "## Please enter the disk you want to install on. (ex. /dev/sda, /dev/nvme0n1, /dev/vda) ##"
    read -r PRE_BOOT_DISK
done

# Prompt user for LUKS unlock.
while [[ -z "$PRE_LUKS_PASS" ]]; do
    echo ""
    echo "## Please enter a LUKS password or accept the default. ##"
    read -r -i "unl0ckMyD1sk" -e PRE_LUKS_PASS
done

# Prompt user for local admin info.
while [[ -z "$PRE_NEW_USER" ]]; do
    echo ""
    echo "## Please enter a local admin username or accept the default. ##"
    read -r -i "ubuntu" -e PRE_NEW_USER
done
while [[ -z "$PRE_USER_PASS" ]]; do
    echo ""
    echo "## Please enter a local admin password or accept the default. ##"
    read -r -i "ubuntu" -e PRE_USER_PASS
done

# Prompt user for hostname.
while [[ -z "$PRE_HOST_NAME" ]]; do
    echo ""
    echo "## Please enter a hostname or accept the default. ##"
    read -r -i "$(dmidecode -s system-serial-number)" -e PRE_HOST_NAME
done

# Prompter user for install type.
while [[ -z "$PRE_DESKTOP_INSTALL" ]]; do
    echo ""
    echo "## Configure for Desktop use? (Valid answers are 'true' or 'false') ##"
    read -r -i "false" -e PRE_DESKTOP_INSTALL
done

# Prompter user for dual-boot or single-boot.
while [[ -z "$PRE_DUAL_BOOT" ]]; do
    echo ""
    echo "## Configure dual-boot partition layout? (Valid answers are 'true' or 'false') ##"
    read -r -i "false" -e PRE_DUAL_BOOT
done

# Prompt user for timezone.
while [[ -z "$PRE_TIMEZONE" ]]; do
    echo ""
    echo "## Please enter a timezone or accept the default. ##"
    read -r -i "America/Los_Angeles" -e PRE_TIMEZONE
done

# Prompt user for locale.
while [[ -z "$PRE_LOCALE" ]]; do
    echo ""
    echo "## Please enter a locale or accept the default. ##"
    read -r -i "en_US.UTF-8" -e PRE_LOCALE
done

# Start doing graphics detection here.
#GRAPHICS="$(lspci |grep 'VGA')"

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

touch includes/answers.env
echo '#!/bin/bash' >> includes/answers.env
echo "export LUKS_PASS=$PRE_LUKS_PASS" >> includes/answers.env
echo "export BOOT_DISK=$PRE_BOOT_DISK" >> includes/answers.env
echo "export EFI_PART=$PRE_EFI_PART" >> includes/answers.env
echo "export BOOT_PART=$PRE_BOOT_PART" >> includes/answers.env
echo "export ROOT_PART=$PRE_ROOT_PART" >> includes/answers.env
echo "export DUAL_BOOT=$PRE_DUAL_BOOT" >> includes/answers.env
echo "export TIMEZONE=$PRE_TIMEZONE" >> includes/answers.env
echo "export LOCALE=$PRE_LOCALE" >> includes/answers.env
echo "export NEW_USER=$PRE_NEW_USER" >> includes/answers.env
echo "export USER_PASS=$PRE_USER_PASS" >> includes/answers.env
echo "export HOST_NAME=$PRE_HOST_NAME" >> includes/answers.env
echo "export DESKTOP_INSTALL=$PRE_DESKTOP_INSTALL" >> includes/answers.env

# If all the above succeeds, mark the answer file as complete.
echo "export PRE_INSTALL_COMPLETE=true" >> includes/answers.env

echo ""
echo "## Answers file complete, starting the install. ##"
./01_base_install.sh
