#!/bin/bash

set -e

#### Preflight Checks ####

# Make sure we're root.
if [[ "$(id -u)" -ne 0 ]]; then
  echo "Please run this script as root or with sudo."
  exit 1
fi

# Source answers file, error out otherwise.
if [[ ! -f "./confs/answers.env" ]] || [[ $PRE_INSTALL_COMPLETE -ne "true" ]]; then
    echo "Answers file is missing or incomplete, please re-run 00_start_here.sh"
    exit 1
else
    source confs/answers.env
fi

# Make sure the apt cache is fresh, then install required packages.
apt -qq update
apt -qq -y install debootstrap arch-install-scripts wget

#### Partitioning Tasks ####

# Nuke all existing partition data from disk.
sgdisk --zap-all "$BOOT_DISK"

# Create EFI, boot, and root partitions.
sgdisk -n "1:0:+2G" -t "1:ef00" "$BOOT_DISK"
sgdisk -c "1:EFI system partition" "$BOOT_DISK"
sgdisk -n "2:0:+2G" -t "2:8300" "$BOOT_DISK"
sgdisk -c "2:Linux filesystem" "$BOOT_DISK"
sgdisk -n "3:0:0" -t "3:8309" "$BOOT_DISK"
sgdisk -c "3:Linux LUKS" "$BOOT_DISK"
if "$DUAL_BOOT"; then
    parted "$BOOT_DISK" resizepart 3 50%
fi

# Prompt for LUKS password, or use the variable if it's set.
cryptsetup luksFormat --batch-mode "$ROOT_PART" <<< "$LUKS_PASS"
cryptsetup open "$ROOT_PART" cryptroot <<< "$LUKS_PASS"

# Create the filesystems.
echo 'y' | mkfs.vfat "$EFI_PART"
echo 'y' | mkfs.ext4 "$BOOT_PART"
echo 'y' | mkfs.ext4 /dev/mapper/cryptroot

## Mount the partitions to /mnt.
mount /dev/mapper/cryptroot /mnt
mkdir /mnt/boot
mount "$BOOT_PART" /mnt/boot
mkdir /mnt/boot/efi
mount "$EFI_PART" /mnt/boot/efi

#### Base Install Tasks ####

# Install base system using `debootstrap`.
debootstrap noble /mnt https://us.archive.ubuntu.com/ubuntu

# Populate fstab.
genfstab -U /mnt >> /mnt/etc/fstab

# Configure apt.
rm /mnt/etc/apt/sources.list
cp confs/ubuntu.sources /mnt/etc/apt/sources.list.d/ubuntu.sources
cp confs/ignored-packages /mnt/etc/apt/preferences.d/ignored-packages

# Install type related configuration.
if "$DESKTOP_INSTALL"; then
    # Additional apt configuration for desktop installs.
    # Stage Mozilla repo and signing key.
    install -d -m 0755 /mnt/etc/apt/keyrings
    wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O /mnt/etc/apt/keyrings/packages.mozilla.org.asc
    cp confs/mozilla.list /mnt/etc/apt/sources.list.d/mozilla.list
    cp confs/mozilla /mnt/etc/apt/preferences.d/mozilla
    # Stage Google Chrome.
    wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /mnt/root/google-chrome-stable_current_amd64.deb
    # Add programs to desktop dock.
    install -d -m 0755 /mnt/etc/dconf/db/site.d/
    install -d -m 0755 /mnt/etc/dconf/profile/
    cp confs/dconf-00_site_settings /mnt/etc/dconf/db/site.d/00_site_settings
    cp confs/dconf-user /mnt/etc/dconf/profile/user
    # Disable gnome-initial-setup
    cp confs/gdm-custom.conf /mnt/etc/gdm3/custom.conf
else
    # If server install, add networking file.
    cp confs/10-wired.network /mnt/etc/systemd/network/10-wired.network
fi

# Copy chroot installer files into chroot.
cp confs/answers.env /mnt/root/answers.env
cp confs/snapd_2.68.5_amd64.deb /mnt/root/snapd_2.68.5_amd64.deb
cp 02_chroot_install.sh /mnt/root/02_chroot_install.sh

# Chroot into the installation environment and continue installation.
arch-chroot /mnt bash /root/02_chroot_install.sh

## Finalization Tasks ####
umount -R /mnt
cryptsetup close /dev/mapper/cryptroot
cd ..
rm -rf ubuntu_install

echo ""
echo "Install complete! Reboot at your leisure."
