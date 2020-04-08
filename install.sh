# import modules
source './modules/disks'

# force packages database refresh
pacman -Syy

#########################################################################

## pre installations steps

#########################################################################

# load keyboard layout
loadkeys uk

# update system clock
timedatectl set-ntp true

#########################################################################

## partition disks

#########################################################################

# partition drives
clear_partition /dev/sda
clear_partition /dev/sdb

# partition drives
make_partition /dev/sda 10240000 # boot - 100mb
make_partition /dev/sda # root - freespace
make_partition /dev/sda 51200000 # swap - 512mb
make_partition /dev/sdb # storage - freespace

# format partiitions
mkfs.vfat -F32 /dev/sda1
mkfs.btrfs /dev/sda2
mkfs.btrfs /dev/sdb1

# make swap disk
mkswap /dev/sda3
swapon /dev/sda3

# mount root volume
mount /dev/sda2 /mnt
mount /dev/sdb1 /mnt/storage

# create subvolumes
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@{home,var,cache,docker}

btrfs subvolume create /mnt/storage/@
btrfs subvolume create /mnt/storage/@{archive,media,projects,vault,workspace}

# umount root volume
umount /mnt/storage
umount /mnt

# mount root subvolumes
mount -o compress=zstd,noatime,nodiratime,ssd,subvol=@ /dev/sda2 /mnt

# creating mounting folders
mkdir -p /mnt/{boot,home,var}
mkdir -p /mnt/storage/{archive,media,projects,vault,workspace}
mkdir -p /mnt/var/cache
mkdir -p /mnt/var/lib/docker

# mount remaining volues

mount /dev/sda1 /mnt/boot

for i in home var cache docker
do
	mount -o compress=zstd,noatime,nodiratime,ssd,subvol=@$i /dev/sda2 /mnt/$i
done

mount -o compress=zstd,noatime,nodiratime,ssd,subvol=@home /dev/sda2 /mnt/home
mount -o compress=zstd,noatime,nodiratime,ssd,subvol=@var /dev/sda2 /mnt/var
mount -o compress=zstd,noatime,nodiratime,ssd,subvol=@cache /dev/sda2 /mnt/var/cache
mount -o compress=zstd,noatime,nodiratime,ssd,subvol=@cache /dev/sda2 /mnt/var/lib/docker
mount -o compress=zstd,noatime,nodiratime,ssd,subvol=@ /dev/sdb1 /mnt/storage

for i in archive media projects vault workspace
do
	mount -o compress=zstd,noatime,nodiratime,ssd,subvol=@$i /dev/sda2 /mnt/storage/$i
done

#########################################################################

## Install Operating System

#########################################################################

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

# generate & verify fstab
fstabgen -U /mnt >> /mnt/etc/fstab
cat /mnt/etc/fstab

#########################################################################

## Configure Systems

#########################################################################

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

# add hooks to initial ramdisk - order is important
export HOOKS="base udev autodetect modconf block btrfs filesystems keyboard fsck"
mkinitcpio -p linux56

#########################################################################

## Packages

#########################################################################

# sublime text

curl -O https://download.sublimetext.com/sublimehq-pub.gpg
pacman-key --add sublimehq-pub.gpg
pacman-key --lsign-key 8A8F901A
rm sublimehq-pub.gpg
echo -e "\n[sublime-text]\nServer = https://download.sublimetext.com/arch/stable/x86_64" | tee -a /etc/pacman.conf
