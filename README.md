# debootstrap
Debootstrap-based install scripts.

### What Does This Get You?
These scripts will get you a basic Ubuntu desktop (or server) install with the following changes from the norm:
* 3 standard partitions (no LVM, swap, other cruft).
  * EFI (FAT32)
  * Boot (ext4)
  * Root (LUKS-encrypted ext4)
* Canonical-isms removed.
  * snap
* Standard things added.
  * Firefox/Chrome + dock pins (on desktop installs).
  * Flatpak + default repos.
  * Gnome Firmware for firmware updates.
  * systemd-networkd based DHCP for all physical adapters (on server installs).


### Using These Scripts
1. As the numbering might suggest, you want to start by running `00_start_here.sh` to populate the `answers.env` file, unless you already have one.
2. Once the `answers.env` file is set up correctly (or you imported a previous one), `01_base_install.sh` will do the debootstrap and initial config, copy over the files to the chroot, and continue there.
3. `02_chroot_install.sh` handles the install steps that take place in the chroot, and then kicks it back out when it's done.
