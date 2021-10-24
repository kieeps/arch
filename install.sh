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
echo -e ${RED}"---${CYAN}                User Input                 ${RED}---"
echo -e ${RED}"-------------------------------------------------"${NC}

lsblk
echo -e ${RED}"Please enter the disk to install on: (example /dev/sda)"${NC}
read DISK
echo -e "Are you sure? ${DISK} will be deleted during the setup if you use this one."
read -p "Continue? (Y/N):" formatdisk
case $formatdisk in

y|Y|yes|Yes|YES)
echo -e "${RED} Okey then, here we go!"