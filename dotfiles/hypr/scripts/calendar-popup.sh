#!/bin/bash
CAL=$(cal -3 2>/dev/null)
echo "$CAL" | rofi -dmenu -theme ~/.config/rofi/info-popup.rasi \
    -theme-str "textbox-prompt { str: \"  Calendar\"; text-color: #89b4fa; }" \
    -theme-str "window { border-color: #89b4fa; width: 720px; }" \
    -theme-str "element-text { font: \"JetBrains Mono 13\"; }" \
    -p "" > /dev/null 2>&1
