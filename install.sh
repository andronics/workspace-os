# import modules
source './modules/bash.sh'
source './modules/disks.sh'

# force packages database refresh
pause "package db update"
pacman -Sy 

# ================================================================================
#  pre installations steps
# ================================================================================

pause "pre installation"

# load keyboard layout
loadkeys uk

# update system clock
timedatectl set-ntp truemake/

# install parted
pacman -S --noconfirm parted

# ================================================================================
# configure root drive
# ================================================================================

pause "partition system disk"

clear_partition /dev/sda
parted -s /dev/sda mktable msdos
parted -s -a optimal /dev/sda mkpart pri 1MB 101MB
parted -s -a optimal /dev/sda mkpart pri 101MB 90%
parted -s -a optimal /dev/sda mkpart pri 90% 100%
mkfs.vfat -F32 /dev/sda1
mkfs.btrfs /dev/sda2
mkswap /dev/sda3
swapon /dev/sda3

pause "create & mount system subvolumes"

mount /dev/sda2 /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@/home
btrfs subvolume create /mnt/@/var
btrfs subvolume create /mnt/@/var/cache
mkdir -p /mnt/boot
mkdir -p /mnt/storage
umount /mnt

# ================================================================================
# configure storage drive
# ================================================================================

pause "partition storage disk"

clear_partition /dev/sdb
parted -s /dev/sdb mktable msdos
parted -s -a optimal /dev/sdb mkpart pri 0% 100%
mkfs.btrfs /dev/sdb1

pause "create & mount storage subvolumes"
mount /dev/sdb1 /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@/archive
btrfs subvolume create /mnt/@/games
btrfs subvolume create /mnt/@/media
btrfs subvolume create /mnt/@/projects
btrfs subvolume create /mnt/@/resources
btrfs subvolume create /mnt/@/services
btrfs subvolume create /mnt/@/software
btrfs subvolume create /mnt/@/vault
btrfs subvolume create /mnt/@/virtual
btrfs subvolume create /mnt/@/workspace
umount /mnt

# ================================================================================
# mount subvolumes
# ================================================================================

pause "mount subvolumes boot partition"
mount -o compress=zstd,noatime,nodiratime,ssd,subvol=@ /dev/sda2 /mnt
mount -o compress=zstd,noatime,nodiratime,ssd,subvol=@ /dev/sdb1 /mnt/storage
mount /dev/sda1 /mnt/boot

# ================================================================================
# install operating system
# ================================================================================

pause "install base os + packages"

# pacstrap base os 
pacstrap /mnt base base-devel

# kernel + firmware
pacstrap /mnt intel-ucode linux56 linux56-firmware

# display manager
pacstrap /mnt lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings

# windows manager
pacstrap /mnt awesome awesome-extra

# other utilities
pacstrap /mnt btrfs-progs manjaro-zsh-config networkmanager nano mkinitcpio sudo systemd-boot-manager vim

pause "generate fstab"

# generate & verify fstab
fstabgen -U /mnt >> /mnt/etc/fstab
cat /mnt/etc/fstab

# ================================================================================
# configure systems
# ================================================================================

pause "configure system"

# configure system 
arch-chroot /mnt /bin/zsh

# set hostname
echo laptop > /etc/hostname

# change default shell
chsh -s /bin/zsh

# set timezone & update rtc
ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime
hwclock --systohc

# enable network mamanger
systemctl enable networkmanager

# enable ntp client
systemctl enable systemd-timesyncd

# locals
echo en_GB.UTF_8 > /etc/locale.conf
echo en_GB.UTF_8 UTF-8 > /etc/locale.gen
local-gen

pause "setup ramdisk hooks"

# add hooks to initial ramdisk - order is important
export HOOKS="base udev autodetect modconf block btrfs filesystems keyboard fsck"
mkinitcpio -p linux56

# ================================================================================
# third-party packages repositories
# ================================================================================

pause "install third party repos "

# sublime text

curl -O https://download.sublimetext.com/sublimehq-pub.gpg
pacman-key --add sublimehq-pub.gpg
pacman-key --lsign-key 8A8F901A
rm sublimehq-pub.gpg
echo -e "\n[sublime-text]\nServer = https://download.sublimetext.com/arch/stable/x86_64" | tee -a /etc/pacman.conf
