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
sed -i 's/^#Color/Color/' /etc/pacman.conf
sed -i '/^Architecture/a ILoveCandy' /etc/pacman.conf

echo -e ${RED}"-------------------------------------------------"
echo -e ${RED}"---${CYAN}                User Input                 ${RED}---"
echo -e ${RED}"-------------------------------------------------"${NC}

## Set Keymap
#echo -e "${RED}Select Keymap. (${GREEN}Swedish is sv-latin1${RED})${NC}"
#read -p ">>" keymap
localectl --no-ask-password set-keymap sv-latin1
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/^#sv_SE.UTF-8 UTF-8/sv_SE.UTF-8 UTF-8/' /etc/locale.gen


## Pick a username
echo -e "${RED}Please pick a username:${NC}"
read -p ">>" username

## Pick a password
echo -e "${RED}Please pick a password:${NC}"
read -p ">>" password

## Pick a hostname
echo -e "${RED}Please pick a hostname:${NC}"
read -p ">>" hostname

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


echo -e ${RED}"-------------------------------------------------"
echo -e ${RED}"---${CYAN}            Setting up Mirrors             ${RED}---"
echo -e ${RED}"-------------------------------------------------"${NC}

timedatectl set-ntp true
pacman -Sy --noconfirm pacman-contrib
sed -i 's/^#ParallelDownloads = 5/ParallelDownloads = 15/' /etc/pacman.conf
# pacman -S --noconfirm reflector rsync
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
reflector -a 48 -c SE -c DK -c NO -c UK -c DE -f 25 -l 20 --sort rate --save /etc/pacman.d/mirrorlist
pacman -Sy

nc=$(grep -c ^processor /proc/cpuinfo)
sudo sed -i 's/#MAKEFLAGS="-j2"/MAKEFLAGS="-j$nc"/g' /etc/makepkg.conf
sudo sed -i 's/COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -T $nc -z -)/g' /etc/makepkg.conf


echo -e ${RED}"-------------------------------------------------"
echo -e ${RED}"---${CYAN}              Preparing Disk               ${RED}---"
echo -e ${RED}"-------------------------------------------------"${NC}
pacman -Sy --noconfirm btrfs-progs

case $formatdisk in

y|Y|yes|Yes|YES)
    
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
echo -e ${RED}"---${CYAN}      Installing essential packages        ${RED}---"
echo -e ${RED}"-------------------------------------------------"${NC}

## Bootstraping Base packages
pacstrap /mnt base base-devel linux linux-firmware nano sudo archlinux-keyring wget libnewt --noconfirm --needed
genfstab -U /mnt >> /mnt/etc/fstab
echo "keyserver hkp://keyserver.ubuntu.com" >> /mnt/etc/pacman.d/gnupg/gpg.conf

## installing bootloader
arch-chroot /mnt pacman -Sy grub grub-btrfs efibootmgr --noconfirm
arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Arch
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

## Installing Network Components
arch-chroot /mnt pacman -S networkmanager dhclient --noconfirm --needed
arch-chroot /mnt systemctl enable --now NetworkManager
echo $hostname > /etc/hostname

echo -e ${RED}"-------------------------------------------------"
echo -e ${RED}"---${CYAN}               Set locale                  ${RED}---"
echo -e ${RED}"-------------------------------------------------"${NC}

arch-chroot /mnt locale-gen
arch-chroot /mnt timedatectl --no-ask-password set-timezone Europe/Stockholm
arch-chroot /mnt timedatectl --no-ask-password set-ntp 1
arch-chroot /mnt localectl --no-ask-password set-locale LANG="en_US.UTF-8" LC_COLLATE="" LC_TIME="sv_SE.UTF-8"


echo -e ${RED}"-------------------------------------------------"
echo -e ${RED}"---${CYAN}          Copy configs over                ${RED}---"
echo -e ${RED}"-------------------------------------------------"${NC}
echo -e "Copying mirrorlist ... ${cyan}DONE!"${NC}
cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist
echo -e "Copying makepkg.conf ... ${cyan}DONE!"${NC}
cp /etc/makepkg.conf /mnt/etc/makepkg.conf
echo -e "Copying locale.gen ...${cyan}DONE!"${NC}
cp /etc/locale.gen /mnt/etc/locale.gen
echo -e "Copying pacman.conf ...${cyan}DONE!"${NC}
cp /etc/pacman.conf /mnt/etc/pacman.conf
echo -e "Copying pkgs.conf ...${cyan}DONE!"${NC}
cp -R ~/arch/pkgs.conf /mnt/root/

echo -e ${RED}"-------------------------------------------------"
echo -e ${RED}"---${CYAN}   Enable Multilib and Chaotic AUR          ${RED}---"
echo -e ${RED}"-------------------------------------------------"${NC}

#Enable multilib
arch-chroot /mnt sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
arch-chroot /mnt pacman -Sy

#Add Chaotic AUR
arch-chroot /mnt pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
arch-chroot /mnt pacman-key --lsign-key 3056513887B78AEB
arch-chroot /mnt pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' --noconfirm --needed
echo "[chaotic-aur]" >> /mnt/etc/pacman.conf
echo "Include = /etc/pacman.d/chaotic-mirrorlist" >> /mnt/etc/pacman.conf
arch-chroot /mnt pacman -Sy paru --noconfirm
arch-chroot /mnt paru -Sy powerpill --noconfirm
sed -i 's/^#BottomUp/BottomUp/' /mnt/etc/paru.conf


echo -e ${RED}"-------------------------------------------------"
echo -e ${RED}"---${CYAN}            Install Software               ${RED}---"
echo -e ${RED}"-------------------------------------------------"${NC}


sed -i 's/^# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/' /mnt/etc/sudoers

echo -e ${PURPLE}"Reading Package list"
source /root/arch/pkgs.conf
echo -e ${PURPLE}"Installing BASE Packages"
for BASE in "${BASE[@]}"; do
    arch-chroot /mnt paru -S --noconfirm $PKG
done
echo -e ${PURPLE}"Installing GAMING Packages"
for GAMING in "${GAMING[@]}"; do
    arch-chroot /mnt paru -S --noconfirm $GAMING
done
echo -e ${PURPLE}"Installing AUR Packages"
for AUR in "${AUR[@]}"; do
    arch-chroot /mnt paru -S --noconfirm $AUR
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
elif lspci | grep -E "Radeon|AMD/ATI"; then
    arch-chroot /mnt pacman -S xf86-video-amdgpu --noconfirm --needed
elif lspci | grep -E "Integrated Graphics Controller"; then
    arch-chroot /mnt pacman -S libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-intel-driver libva-utils --needed --noconfirm
fi

echo -e ${RED}"-------------------------------------------------"
echo -e ${RED}"---${CYAN}          Create User on system            ${RED}---"
echo -e ${RED}"-------------------------------------------------"${NC}

arch-chroot /mnt useradd -m -G wheel,libvirt,docker -s /bin/zsh $username
echo -e "$username:$password" | arch-chroot /mnt chpasswd
# cp -R /root/arch /mnt/home/$username/



echo -e ${RED}"-------------------------------------------------"
echo -e ${RED}"---${CYAN}           Costumizing System              ${RED}---"
echo -e ${RED}"-------------------------------------------------"${NC}
# arch-chroot /mnt wget https://cloud.kieeps.com/s/QzpPF5Tcw2tHY3L/download -O /home/kieeps/kieeps.knsv
# arch-chroot /mnt sudo konsave -i /home/kieeps/kieeps.knsv
# arch-chroot /mnt sudo konsave -a kieeps

touch "/mnt/home/$username/.cache/zshhistory"
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git /mnt/home/$username/powerlevel10k
cp -R ~/arch/.zshrc /mnt/home/$username/
cp -R ~/arch/.p10k.zsh /mnt/home/$username/
arch-chroot /mnt chown -R $username:$username /home/$username/

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
arch-chroot /mnt systemctl enable docker.service

echo -e ${RED}"-------------------------------------------------"
echo -e ${RED}"---${CYAN}                Finishing                  ${RED}---"
echo -e ${RED}"-------------------------------------------------"${NC}

sed -i 's/^%wheel ALL=(ALL) NOPASSWD: ALL/# %wheel ALL=(ALL) NOPASSWD: ALL/' /mnt/etc/sudoers
sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /mnt/etc/sudoers