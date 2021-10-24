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

lsblk
echo -e ${RED}"Please enter the disk to install on: (example /dev/sda)"${NC}
read DISK
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


#Enable multilib
arch-chroot /mnt sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf

#Add Chaotic AUR
arch-chroot /mnt pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
arch-chroot /mnt pacman-key --lsign-key 3056513887B78AEB
arch-chroot /mnt pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
arch-chroot /mnt echo "[chaotic-aur]" >> /etc/pacman.conf
arch-chroot /mnt echo "Include = /etc/pacman.d/chaotic-mirrorlist" >> /etc/pacman.conf

arch-chroot /mnt pacman -Sy --noconfirm

arch-chroot /mnt sed -i 's/^# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers

PKGS=(
'alsa-plugins' # audio plugins
'alsa-utils' # audio utils
'ark' # compression
'audiocd-kio' 
'autoconf' # build
'automake' # build
'base'
'bash-completion'
'bind'
'binutils'
'bison'
'bluedevil'
'bluez'
'bluez-libs'
'breeze'
'breeze-gtk'
'bridge-utils'
'btrfs-progs'
'code' # Visual Studio code
'cronie'
'cups'
'dhcpcd'
'dialog'
'discover'
'dmidecode'
'dnsmasq'
'dolphin'
'dosfstools'
'drkonqi'
'edk2-ovmf'
'efibootmgr' # EFI boot
'egl-wayland'
'exfat-utils'
'flex'
'fuse2'
'fuse3'
'fuseiso'
'gamemode'
'gcc'
'git'
'gparted' # partition management
'gptfdisk'
'groff'
'grub'
'grub-customizer'
'gst-libav'
'gst-plugins-good'
'gst-plugins-ugly'
'haveged'
'htop'
'iptables-nft'
'jdk-openjdk' # Java 17
'kactivitymanagerd'
'kate'
'kvantum-qt5'
'kcalc'
'kcharselect'
'kcron'
'kde-cli-tools'
'kde-gtk-config'
'kdecoration'
'kdenetwork-filesharing'
'kdeplasma-addons'
'kdesdk-thumbnailers'
'kdialog'
'keychain'
'kfind'
'kgamma5'
'kgpg'
'khotkeys'
'kinfocenter'
'kitty'
'kmenuedit'
'kmix'
'konsole'
'kscreen'
'kscreenlocker'
'ksshaskpass'
'ksystemlog'
'ksystemstats'
'kwallet-pam'
'kwalletmanager'
'kwayland-integration'
'kwayland-server'
'kwin'
'kwrite'
'kwrited'
'layer-shell-qt'
'libguestfs'
'libkscreen'
'libksysguard'
'libnewt'
'libtool'
'linux'
'linux-firmware'
'linux-headers'
'lsof'
'lutris'
'lzop'
'm4'
'make'
'milou'
'nano'
'neofetch'
'networkmanager'
'ntfs-3g'
'okular'
'openbsd-netcat'
'openssh'
'os-prober'
'oxygen'
'p7zip'
'pacman-contrib'
'patch'
'picom'
'pkgconf'
'plasma-browser-integration'
'plasma-desktop'
'plasma-disks'
'plasma-firewall'
'plasma-integration'
'plasma-nm'
'plasma-pa'
'plasma-sdk'
'plasma-systemmonitor'
'plasma-thunderbolt'
'plasma-vault'
'plasma-workspace'
'plasma-workspace-wallpapers'
'polkit-kde-agent'
'powerdevil'
'powerline-fonts'
'print-manager'
'pulseaudio'
'pulseaudio-alsa'
'pulseaudio-bluetooth'
'python-pip'
'qemu'
'rsync'
'sddm'
'sddm-kcm'
'snapper'
'spectacle'
'steam'
'sudo'
'swtpm'
'synergy'
'systemsettings'
'terminus-font'
'texinfo'
'traceroute'
'ufw'
'unrar'
'unzip'
'usbutils'
'vde2'
'vim'
'virt-manager'
'virt-viewer'
'wget'
'which'
'wine-gecko'
'wine-mono'
'winetricks'
'xdg-desktop-portal-kde'
'xdg-user-dirs'
'xorg'
'xorg-server'
'xorg-xinit'
'yakuake'
'zeroconf-ioslave'
'zip'
'zsh'
'zsh-syntax-highlighting'
'zsh-autosuggestions'
)

for PKG in "${PKGS[@]}"; do
    echo "INSTALLING: ${PKG}"
    arch-chroot /mnt sudo pacman -S "$PKG" --noconfirm --needed
done