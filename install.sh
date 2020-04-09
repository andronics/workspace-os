#!/usr/bin/bash

# force packages database refresh
pacman -Sy 

# ================================================================================
#  pre installations steps
# ================================================================================

# load keyboard layout
loadkeys uk

# update system clock
timedatectl set-ntp true

# install parted
pacman -S --noconfirm parted

# ================================================================================
# configure root drive
# ================================================================================

echo "partition system disk?"
select ynx in "Yes" "No" "Exit"; do

	case $ynx in
		Exit )
			exit
			;;
		No )
			break
			;;
		Yes )
			dd if=/dev/urandom of=/dev/sda bs=1M count=100
			parted -s /dev/sda mktable msdos
			parted -s -a optimal /dev/sda mkpart pri 1MB 101MB
			parted -s -a optimal /dev/sda mkpart pri 101MB 90%
			parted -s -a optimal /dev/sda mkpart pri 90% 100%
			mkfs.vfat -F32 /dev/sda1
			mkfs.btrfs /dev/sda2
			mkswap /dev/sda3
			swapon /dev/sda3
			break
			;;
	esac

done

echo "create system subvolumes?"
select ynx in "Yes" "No" "Exit"; do

	case $ynx in
		Exit )
			exit
			;;
		No )
			break
			;;
		Yes )
			mount /dev/sda2 /mnt
			btrfs subvolume create /mnt/@
			btrfs subvolume create /mnt/@/home
			btrfs subvolume create /mnt/@/var
			btrfs subvolume create /mnt/@/var/cache
			mkdir -p /mnt/@/boot
			mkdir -p /mnt/@/storage
			umount /mnt
			break
			;;
	esac

done

# ================================================================================
# configure storage drive
# ================================================================================

echo "partition storage disk?"
select ynx in "Yes" "No" "Exit"; do

	case $ynx in
		Exit )
			exit
			;;
		No )
			break
			;;
		Yes )
			dd if=/dev/urandom of=/dev/sdb bs=1M count=100
			parted -s /dev/sdb mktable msdos
			parted -s -a optimal /dev/sdb mkpart pri 0% 100%
			mkfs.btrfs /dev/sdb1
			break
			;;
	esac

done

echo "create storage subvolumes?"
select ynx in "Yes" "No" "Exit"; do

	case $ynx in
		Exit )
			exit
			;;
		No )
			break
			;;
		Yes )
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
			break
			;;
	esac

done

# ================================================================================
# mount subvolumes
# ================================================================================

echo "mount subvolumes?"
select ynx in "Yes" "No" "Exit"; do

	case $ynx in
		Exit )
			exit
			;;
		No )
			break
			;;
		Yes )
			mount -o compress=zstd,noatime,nodiratime,ssd,subvol=@ /dev/sda2 /mnt
			mount -o compress=zstd,noatime,nodiratime,ssd,subvol=@ /dev/sdb1 /mnt/storage
			mount /dev/sda1 /mnt/boot
			break
			;;
	esac

done

# ================================================================================
# install operating system
# ================================================================================

echo "basestrap operating system?"
select ynx in "Yes" "No" "Exit"; do

	case $ynx in
		Exit )
			exit
			;;
		No )
			break
			;;
		Yes )
			# pacstrap base os 
			basestrap /mnt base base-devel
			# kernel + firmware
			basestrap /mnt intel-ucode linux56 linux56-firmware
			# display manager
			basestrap /mnt lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings
			# windows manager
			basestrap /mnt awesome awesome-extra
			# other utilities
			basestrap /mnt btrfs-progs manjaro-zsh-config networkmanager nano mkinitcpio sudo systemd-boot-manager vim
			break
			;;
	esac

done

echo "generate fstab?"
select ynx in "Yes" "No" "Exit"; do

	case $ynx in
		Exit )
			exit
			;;
		No )
			break
			;;
		Yes )
			fstabgen -U /mnt >> /mnt/etc/fstab
			cat /mnt/etc/fstab
			break
			;;
	esac

done

# ================================================================================
# configure systems
# ================================================================================

# configure system 
manjaro-chroot /mnt /bin/bash

echo "configure system?"
select ynx in "Yes" "No" "Exit"; do

	case $ynx in
		Exit )
			exit
			;;
		No )
			break
			;;
		Yes )
			# set hostname
			printf  "%s" andronics-pc > /etc/hostname
			# update hosts file
			printf "%s\t%s" "127.0.1.1" "andronics-pc" > /etc/hosts
			# set systems administrators
			printf "%wheel ALL=(ALL) ALL" > /etc/sudeors
			# change default shell
			chsh -s /bin/zsh
			# set timezone & update rtc
			ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime
			# clock
			hwclock --systohc --utc
			# enable network mamanger
			systemctl enable networkmanager
			# enable time syncronization
			systemctl enable systemd-timesyncd
			# locals
			echo en_GB.UTF_8 > /etc/locale.conf
			echo en_GB.UTF_8 UTF-8 > /etc/locale.gen
			local-gen
			break
			;;
	esac

done

echo "configure bootloader?"
select ynx in "Yes" "No" "Exit"; do

	case $ynx in
		Exit )
			exit
			;;
		No )
			break
			;;
		Yes )
			# add hooks to initial ramdisk - order is important
			export HOOKS="base udev autodetect modconf block btrfs filesystems keyboard fsck"
			# initramfs
			mkinitcpio -p linux56
			# grub for efi system
			grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Manjaro
			# grub configuration
			grub-mkconfig -o /boot/grub/grub.cfg
			break
			;;
	esac

done

exit
# ================================================================================
# third-party packages repositories
# ================================================================================

# sublime text

# curl -O https://download.sublimetext.com/sublimehq-pub.gpg
# pacman-key --add sublimehq-pub.gpg
# pacman-key --lsign-key 8A8F901A
# rm sublimehq-pub.gpg
# echo -e "\n[sublime-text]\nServer = https://download.sublimetext.com/arch/stable/x86_64" | tee -a /etc/pacman.conf
