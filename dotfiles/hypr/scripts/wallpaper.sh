#!/bin/sh
~/.local/bin/swww-daemon &
sleep 2
~/.local/bin/swww img ~/Pictures/wallpaper.png --transition-type wipe --transition-duration 2
