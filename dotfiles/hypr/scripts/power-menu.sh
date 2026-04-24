#!/bin/bash
OPTIONS="  Lock\n  Logout\n  Suspend\n  Reboot\n  Shutdown"

CHOSEN=$(echo -e "$OPTIONS" | rofi -dmenu -i -p "Power" -theme-str 'window {width: 250px;} listview {lines: 5;}')

case "$CHOSEN" in
    *Lock)     hyprlock ;;
    *Logout)   hyprctl dispatch exit ;;
    *Suspend)  systemctl suspend ;;
    *Reboot)   systemctl reboot ;;
    *Shutdown) systemctl poweroff ;;
esac
