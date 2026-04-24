#!/bin/bash
VOL=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)
PERCENT=$(echo "$VOL" | awk "{printf \"%.0f\", \$2*100}")
IS_MUTED=""
echo "$VOL" | grep -q MUTED && IS_MUTED=" [MUTED]"

OPTS="  Current: ${PERCENT}%${IS_MUTED}
  Mute Toggle
  25%
  50%
  75%
  100%
  Open Mixer"

CHOSEN=$(echo -e "$OPTS" | rofi -dmenu -i -theme ~/.config/rofi/volume-popup.rasi -p "" 2>/dev/null)

case "$CHOSEN" in
    *"Mute Toggle"*)  wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
    *"25%"*)          wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.25 ;;
    *"50%"*)          wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.50 ;;
    *"75%"*)          wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.75 ;;
    *"100%"*)         wpctl set-volume @DEFAULT_AUDIO_SINK@ 1.00 ;;
    *"Open Mixer"*)   kitty --title volume-popup -e pulsemixer ;;
esac
