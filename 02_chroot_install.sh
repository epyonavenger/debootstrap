#!/bin/bash

PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin"

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

# Install dummy packages to prevent apt errors.
apt -qq -y install '/root/snapd_2.68.5_amd64.deb'
apt -qq -y install '/root/gnome-initial-setup_46.3-1ubuntu3~24.04.2_amd64.deb'

## Set hostname.
echo "$HOST_NAME" > /etc/hostname
echo "127.0.1.1 $HOST_NAME" >> /etc/hosts

#### User Management Tasks ####
useradd -mG sudo,adm -s /usr/bin/bash "$NEW_USER"
yes "$USER_PASS" | passwd "$NEW_USER"

#### Base System Type Install ####
if "$DESKTOP_INSTALL"; then
    apt -qq -y install ubuntu-minimal ubuntu-standard ubuntu-desktop-minimal ssh firefox flatpak gnome-software-plugin-flatpak gnome-firmware htop iftop iotop tree nano bash-completion wget systemd-zram-generator clinfo mesa-opencl-icd intel-opencl-icd pocl-opencl-icd vainfo vulkan-tools
    # Configure flatpak instead of snap.
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    # Install Google Chrome.
    apt -qq -y install /root/google-chrome-stable_current_amd64.deb
    install -d -m 0755 /usr/local/share/applications
    mv /root/google-chrome.desktop /usr/local/share/applications/google-chrome.desktop
    # Disable user list in GDM.
    sed -i 's/# disable-user-list=true/disable-user-list=true/' /etc/gdm3/greeter.dconf-defaults
else
    apt -qq -y install ubuntu-minimal ubuntu-standard ubuntu-server-minimal ubuntu-server ssh htop iftop iotop tree nano bash-completion wget systemd-zram-generator clinfo pocl-opencl-icd
    # Set up server networking.
    systemctl enable systemd-networkd systemd-resolved
fi

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
rm /root/*

# Lock root on the way out.
passwd --lock root
usermod --lock root

# Exit chroot.
exit
