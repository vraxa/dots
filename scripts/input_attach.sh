#!/bin/sh

virsh attach-device default /home/$USER/.VFIOinput/input_1.xml
virsh attach-device win11 /home/$USER/.VFIOinput/input_2.xml
