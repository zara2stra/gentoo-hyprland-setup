#!/bin/bash
cliphist list | rofi -dmenu -p "Clipboard" -display-columns 2 | cliphist decode | wl-copy
