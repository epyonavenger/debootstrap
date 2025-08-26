#!/bin/bash

set -e

#### Preflight Checks ####
if [[ -f "/root/answers.env" ]]; then
    source "/root/answers.env"
else
    echo "Answers file is missing, please exit chroot and try again."
    exit 1
fi

#### Required Package Management Tasks ####

# Configure timezone, locales, and keyboard layout.
echo "$TIMEZONE" > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata
update-locale "$LOCALE"
locale-gen --purge "$LOCALE"
dpkg-reconfigure -f noninteractive locales
dpkg-reconfigure -f noninteractive keyboard-configuration

# Update base packages.
apt -qq update
apt -qq -y dist-upgrade

# Make sure `/etc/crypttab` is populated.
echo "cryptroot $(blkid -o export $ROOT_PART | grep ^UUID) none luks,discard" >> /etc/crypttab

# Install kernel and friends.
apt -qq -y install linux-{,image-,headers-,tools-}generic-hwe-*-edge linux-firmware initramfs-tools cryptsetup-initramfs efibootmgr dosfstools keyutils dmidecode

## Set hostname.
HOSTNAME="$(dmidecode -s system-serial-number)"
if [[ -z "$HOSTNAME" ]]; then
    HOSTNAME="$(date | md5sum | cut -d ' ' -f1)"
else
    echo "$HOSTNAME" > /etc/hostname
    echo "127.0.1.1 $HOSTNAME" >> /etc/hosts
fi

#### User Management Tasks ####
useradd -mG sudo,adm -s /usr/bin/bash "$NEW_USER"
yes "$USER_PASS" | passwd "$NEW_USER"

#### Base System Type Install ####

# Allow errors here because of snap and cloud-init changes earlier.
set +e

if [[ "$INSTALL_TYPE" -eq "SERVER" ]]; then
    apt -qq -y install ubuntu-minimal ubuntu-standard ubuntu-server-minimal ubuntu-server ssh htop iftop iotop tree nano bash-completion wget
    # Set up server networking.
    systemctl enable systemd-networkd systemd-resolved
fi

if [[ "$INSTALL_TYPE" -eq "DESKTOP" ]]; then
    apt -qq -y install ubuntu-minimal ubuntu-standard ubuntu-desktop-minimal ssh firefox flatpak gnome-software-plugin-flatpak gnome-firmware htop iftop iotop tree nano bash-completion wget
    # Configure flatpak instead of snap.
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    # Install Google Chrome.
    apt -qq -y install /root/google-chrome-stable_current_amd64.deb
fi

# Return to bailing on errors.
set -e

#### Final Tasks ####

# Make sure initramfs is up to date.
update-initramfs -u -k all

# Install a bootloader.
apt -qq -y install shim-signed grub-efi
grub-install "$BOOT_DISK"
update-grub

# Clean up apt cruft.
apt -qq -y autopurge
apt -qq -y clean

# Clean up installer files.
rm /root/answers.env
rm /root/02_chroot_install.sh
rm /root/google-chrome-stable_current_amd64.deb

# Lock root on the way out.
passwd --lock root
usermod --lock root

# Exit chroot.
exit
