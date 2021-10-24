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
    ;;
n|N|no|No|NO)
    echo -e "${RED}Fine! come back when you know where to install.${NC}"
    exit
    ;;


esac