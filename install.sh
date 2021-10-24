#!/usr/bin/env bash
########################################################
###  This script will set up Arch Linux with a bunch ###
###  of settings that i like, in a way that i prefer ###
###  Your milage may vary.                           ###
########################################################

########################################################
###                Setting variables                 ###
########################################################

## Termianl Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e ${RED}"-------------------------------------------------"
echo -e ${RED}"---${CYAN}            Setting up Mirrors             ${RED}---"
echo -e ${RED}"-------------------------------------------------"${NC}

timedatectl set-ntp true
pacman -Sy
pacman -S --noconfirm pacman-contrib
sed -i 's/^#ParallelDownloads = 5/ParallelDownloads = 15/' /etc/pacman.conf
pacman -S --noconfirm reflector rsync
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
reflector -a 48 -c SE -c DK -c NO -c UK -c DE -f 25 -l 20 --sort rate --save /etc/pacman.d/mirrorlist
pacman -Sy

nc=$(grep -c ^processor /proc/cpuinfo)
sudo sed -i 's/#MAKEFLAGS="-j2"/MAKEFLAGS="-j$nc"/g' /etc/makepkg.conf
sudo sed -i 's/COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -T $nc -z -)/g' /etc/makepkg.conf

echo -e ${RED}"-------------------------------------------------"
echo -e ${RED}"---${CYAN}           Setting up Disk Tools           ${RED}---"
echo -e ${RED}"-------------------------------------------------"${NC}
pacman -S --noconfirm gptfdisk btrfs-progs


echo -e ${RED}"-------------------------------------------------"
echo -e ${RED}"---${CYAN}                User Input                 ${RED}---"
echo -e ${RED}"-------------------------------------------------"${NC}

## Set Keymap
echo -e "${RED}Select Keymap. (${GREEN}Swedish is sv-latin1${RED})${NC}"
read -p ">>" keymap
localectl --no-ask-password set-keymap ${keymap}
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/^#sv_SE.UTF-8 UTF-8/sv_SE.UTF-8 UTF-8/' /etc/locale.gen


## Pick a username
echo -e "${RED}Please enter a username:${NC}"
read -p ">>" username

# Stable or Beta drivers
if lspci | grep -E "NVIDIA|GeForce"; then
    echo -p "${RED}Do you prefer ${CYAN}Beta ${RED}or ${CYAN} Stable${RED} NVidia drivers?${NC}"
    read -p >> nvidia
fi

lsblk
echo -e ${RED}"Please enter the disk to install on: (${GREEN}example /dev/sda${RED})"${NC}
read -p ">>" DISK
echo -e "${RED}Are you sure? ${DISK} will be deleted during the setup if you use this one.${NC}"
read -p "Continue? (Y/N):" formatdisk
case $formatdisk in

y|Y|yes|Yes|YES)
    echo -e "${RED} Okey then, here we go!${NC}"
    
    # disk prep
    sgdisk -Z ${DISK} # zap disk
    sgdisk -a 2048 -o ${DISK} # new gpt disk 2048 alignment

    # create partitions
    sgdisk -n 1:0:+1000M ${DISK} # partition 1 (UEFI SYS), default start block, 512MB
    sgdisk -n 2:0:0     ${DISK} # partition 2 (Root), default start, remaining

    # set partition types
    sgdisk -t 1:ef00 ${DISK} # EFI System Partition
    sgdisk -t 2:8300 ${DISK} # Swap

    # label partitions
    sgdisk -c 1:"UEFISYS" ${DISK}
    sgdisk -c 2:"ROOT" ${DISK}

    # make filesystems
    mkdir /mnt
    if [[ ${DISK} =~ "nvme" ]]; then
    mkfs.vfat -F32 -n "UEFISYS" "${DISK}p1"
    mkfs.btrfs -L "ROOT" "${DISK}p2" -f
    mount -t btrfs "${DISK}p2" /mnt
    else
    mkfs.vfat -F32 -n "UEFISYS" "${DISK}1"
    mkfs.btrfs -L "ROOT" "${DISK}2" -f
    mount -t btrfs "${DISK}2" /mnt
    fi
    ls /mnt | xargs btrfs subvolume delete
    btrfs subvolume create /mnt/@
    umount /mnt
    mount -t btrfs -o subvol=@ -L ROOT /mnt
    mkdir /mnt/boot
    mkdir /mnt/boot/efi
    mount -t vfat -L UEFISYS /mnt/boot/
    ;;
n|N|no|No|NO)
    echo -e "${RED}Fine! come back when you know where to install.${NC}"
    exit
    ;;
esac

echo -e ${RED}"-------------------------------------------------"
echo -e ${RED}"---${CYAN}        Installing Arch on drive           ${RED}---"
echo -e ${RED}"-------------------------------------------------"${NC}

pacstrap /mnt base base-devel linux linux-firmware vim nano sudo archlinux-keyring wget libnewt --noconfirm --needed
genfstab -U /mnt >> /mnt/etc/fstab
echo "keyserver hkp://keyserver.ubuntu.com" >> /mnt/etc/pacman.d/gnupg/gpg.conf


echo -e ${RED}"-------------------------------------------------"
echo -e ${RED}"---${CYAN}    Installing Systemd bootloader          ${RED}---"
echo -e ${RED}"-------------------------------------------------"${NC}
bootctl install --esp-path=/mnt/boot
[ ! -d "/mnt/boot/loader/entries" ] && mkdir -p /mnt/boot/loader/entries
cat <<EOF > /mnt/boot/loader/entries/arch.conf
title Arch Linux  
linux /vmlinuz-linux  
initrd  /initramfs-linux.img  
options root=LABEL=ROOT rw rootflags=subvol=@
EOF
cp -R ~/arch /mnt/root/
cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist
cp /etc/makepkg.conf /mnt/etc/makepkg.conf
cp /etc/locale.gen /mnt/etc/locale.gen

echo -e ${RED}"-------------------------------------------------"
echo -e ${RED}"---${CYAN}    Installing Network Components          ${RED}---"
echo -e ${RED}"-------------------------------------------------"${NC}

arch-chroot /mnt pacman -S networkmanager dhclient --noconfirm --needed
arch-chroot /mnt systemctl enable --now NetworkManager

echo -e ${RED}"-------------------------------------------------"
echo -e ${RED}"---${CYAN}               Set locate                  ${RED}---"
echo -e ${RED}"-------------------------------------------------"${NC}

arch-chroot /mnt locale-gen
arch-chroot /mnt timedatectl --no-ask-password set-timezone Europe/Stockholm
arch-chroot /mnt timedatectl --no-ask-password set-ntp 1
arch-chroot /mnt localectl --no-ask-password set-locale LANG="en_US.UTF-8" LC_COLLATE="" LC_TIME="sv_SE.UTF-8"

echo -e ${RED}"-------------------------------------------------"
echo -e ${RED}"---${CYAN}      Enable Multilib and Chaotic          ${RED}---"
echo -e ${RED}"-------------------------------------------------"${NC}
#Enable multilib
arch-chroot /mnt sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf

#Add Chaotic AUR
arch-chroot /mnt pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
arch-chroot /mnt pacman-key --lsign-key 3056513887B78AEB
arch-chroot /mnt pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
echo "[chaotic-aur]" >> /mnt/etc/pacman.conf
echo "Include = /etc/pacman.d/chaotic-mirrorlist" >> /mnt/etc/pacman.conf

echo -e ${RED}"-------------------------------------------------"
echo -e ${RED}"---${CYAN}    Install Basesystem and software        ${RED}---"
echo -e ${RED}"-------------------------------------------------"${NC}


sed -i 's/^# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/' /mnt/etc/sudoers

arch-chroot /mnt pacman -Sy yay --noconfirm --needed
source /root/arch/pkgs.conf
for PKG in "${PKGS[@]}"; do
    arch-chroot /mnt sudo yay -S --noconfirm $PKG
done

echo -e ${RED}"-------------------------------------------------"
echo -e ${RED}"---${CYAN}            Install Microcode              ${RED}---"
echo -e ${RED}"-------------------------------------------------"${NC}

proc_type=$(lscpu | awk '/Vendor ID:/ {print $3}')
case "$proc_type" in
	GenuineIntel)
		arch-chroot /mnt pacman -S --noconfirm intel-ucode
		arch-chroot /mnt proc_ucode=intel-ucode.img
		;;
	AuthenticAMD)
		arch-chroot /mnt pacman -S --noconfirm amd-ucode
		arch-chroot /mnt proc_ucode=amd-ucode.img
		;;
esac	

echo -e ${RED}"-------------------------------------------------"
echo -e ${RED}"---${CYAN}           Install GPU Drivers             ${RED}---"
echo -e ${RED}"-------------------------------------------------"${NC}

if lspci | grep -E "NVIDIA|GeForce"; then
    if [[ ${nvidia} =~ "eta" ]]; then
        arch-chroot /mnt pacman -S nvidia-beta --noconfirm --needed
        arch-chroot /mnt nvidia-xconfig
    else
        arch-chroot /mnt pacman -S nvidia --noconfirm --needed
	    arch-chroot /mnt nvidia-xconfig
    fi
elif lspci | grep -E "Radeon"; then
    arch-chroot /mnt pacman -S xf86-video-amdgpu --noconfirm --needed
elif lspci | grep -E "Integrated Graphics Controller"; then
    arch-chroot /mnt pacman -S libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-intel-driver libva-utils --needed --noconfirm
fi

echo -e ${RED}"-------------------------------------------------"
echo -e ${RED}"---${CYAN}          Create User on system            ${RED}---"
echo -e ${RED}"-------------------------------------------------"${NC}

arch-chroot /mnt useradd -m -G wheel,libvirt -s /bin/bash $username
arch-chroot /mnt passwd $username
cp -R /root/arch /mnt/home/$username/
arch-chroot /mnt chown -R $username: /home/$username/arch

echo -e ${RED}"-------------------------------------------------"
echo -e ${RED}"---${CYAN}            Enabling Services              ${RED}---"
echo -e ${RED}"-------------------------------------------------"${NC}

arch-chroot /mnt systemctl enable sddm.service
arch-chroot /mnt systemctl enable cups.service
arch-chroot /mnt ntpd -qg
arch-chroot /mnt systemctl enable ntpd.service
arch-chroot /mnt systemctl disable dhcpcd.service
arch-chroot /mnt systemctl stop dhcpcd.service
arch-chroot /mnt systemctl enable NetworkManager.service

echo -e ${RED}"-------------------------------------------------"
echo -e ${RED}"---${CYAN}                Finishing                  ${RED}---"
echo -e ${RED}"-------------------------------------------------"${NC}

sed -i 's/^%wheel ALL=(ALL) NOPASSWD: ALL/# %wheel ALL=(ALL) NOPASSWD: ALL/' /mnt/etc/sudoers
sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /mnt/etc/sudoers