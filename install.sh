# import modules
source './modules/disks'

# force packages database refresh
pause "update packages"
pacman -Syy

# ================================================================================
#  pre installations steps
# ================================================================================

pause "pre installation"

# load keyboard layout
loadkeys uk

# update system clock
timedatectl set-ntp true

# ================================================================================
# partition disks
# ================================================================================

# clear drives
pause "clear partitions"
clear_partition /dev/sda
clear_partition /dev/sdb

# partition drives
pause "create new partitions"
make_partition /dev/sda 10240000 # boot - 100mb
make_partition /dev/sda # root - freespace
make_partition /dev/sda 51200000 # swap - 512mb
make_partition /dev/sdb # storage - freespace

# format partiitions
pause "format partitions"
mkfs.vfat -F32 /dev/sda1
mkfs.btrfs /dev/sda2
mkfs.btrfs /dev/sdb1

# make swap disk
pause "enable swap disk"
mkswap /dev/sda3
swapon /dev/sda3

# ================================================================================
# configure root drive
# ================================================================================

pause "mount root partitions"

mount /dev/sda2 /mnt

pause "create root subvolumes & folders"
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@/{home,var}
btrfs subvolume create /mnt/@/var/{cache}

pause "remount root subvolume root"
umount /mnt
mount -o compress=zstd,noatime,nodiratime,ssd,subvol=@ /dev/sda2 /mnt

# ================================================================================
# configure storage drive
# ================================================================================

pause "mount storage partition"
mkdir -p /mnt/storage
mount /dev/sdb1 /mnt/storage

pause "create storage subvolumes & folders"
btrfs subvolume create /mnt/storage/@
btrfs subvolume create /mnt/storage/@/{archive,games,media,projects,resources,services,software,vault,virtual,workspace}

pause "remount storage subvolume root"
umount /mnt/storage
mount -o compress=zstd,noatime,nodiratime,ssd,subvol=@ /dev/sdb1 /mnt/storage

# mount remaining volues
pause "mount boot volume"
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
