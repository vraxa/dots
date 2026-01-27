!#/bin/bash

clipse -clear

sudo timeshift --create --comments "auto-update snapshot"

sudo grub-mkconfig -o /boot/grub/grub.cfg

sudo pacman -Syyu --noconfirm > /home/tt/update_logger.txt

notify-send "Trevs Updater" "Update Completed"
