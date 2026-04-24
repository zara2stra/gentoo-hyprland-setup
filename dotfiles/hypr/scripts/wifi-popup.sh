#!/bin/bash

CURRENT=$(nmcli -t -f NAME connection show --active 2>/dev/null | head -1)

MENU=""
SEEN=""
while IFS=: read -r SSID SIGNAL SEC INUSE; do
    [ -z "$SSID" ] && continue
    echo "$SEEN" | grep -qF "$SSID" && continue
    SEEN+="$SSID\n"

    if [ "$INUSE" = "*" ]; then
        MENU+="󰤨  $SSID  ${SIGNAL}%  [$SEC]  [connected]\n"
    else
        MENU+="󰤯  $SSID  ${SIGNAL}%  [$SEC]\n"
    fi
done <<< "$(nmcli -t -f SSID,SIGNAL,SECURITY,IN-USE device wifi list 2>/dev/null)"

MENU+="─────────────────\n"
MENU+="󰤩  Rescan\n"
MENU+="  Edit Connections"

SEL=$(echo -e "$MENU" | rofi -dmenu -i \
    -theme ~/.config/rofi/volume-popup.rasi \
    -theme-str 'textbox-prompt { str: "󰤨  Wi-Fi"; text-color: #89b4fa; }' \
    -theme-str 'window { border-color: #89b4fa; width: 500px; }' \
    -theme-str 'listview { lines: 15; }' \
    -p "" 2>/dev/null)

case "$SEL" in
    ""|"─"*) exit 0 ;;
    *"Rescan"*)
        notify-send -t 5000 "󰤨 Wi-Fi" "Scanning..."
        nmcli device wifi rescan 2>/dev/null
        sleep 2
        exec "$0"
        ;;
    *"Edit Connections"*)
        nm-connection-editor &
        exit 0
        ;;
    *"[connected]"*)
        SSID=$(echo "$SEL" | sed 's/^[^ ]* *//' | sed 's/  .*//')
        DEVACT=$(echo -e "  Disconnect\n  Connection Info" | rofi -dmenu -i \
            -theme ~/.config/rofi/volume-popup.rasi \
            -theme-str "textbox-prompt { str: \"󰤨  $SSID\"; text-color: #a6e3a1; }" \
            -theme-str 'window { border-color: #a6e3a1; width: 350px; }' \
            -theme-str 'listview { lines: 2; }' \
            -p "" 2>/dev/null)
        case "$DEVACT" in
            *"Disconnect"*)
                nmcli connection down "$SSID" 2>/dev/null
                notify-send -t 3000 "󰤮 Wi-Fi" "Disconnected from $SSID"
                ;;
            *"Info"*)
                INFO=$(nmcli device wifi list 2>/dev/null | head -1; nmcli -f GENERAL,IP4 device show 2>/dev/null | grep -E "GENERAL\.|IP4\." | head -10)
                echo "$INFO" | rofi -dmenu -theme ~/.config/rofi/info-popup.rasi -p "" > /dev/null 2>&1
                ;;
        esac
        ;;
    *)
        SSID=$(echo "$SEL" | sed 's/^[^ ]* *//' | sed 's/  .*//')
        KNOWN=$(nmcli -t -f NAME connection show 2>/dev/null | grep -Fx "$SSID")
        if [ -n "$KNOWN" ]; then
            notify-send -t 5000 "󰤨 Wi-Fi" "Connecting to $SSID..."
            RESULT=$(nmcli connection up "$SSID" 2>&1)
            if echo "$RESULT" | grep -q "successfully activated"; then
                notify-send -t 3000 "󰤨 Wi-Fi" "Connected to $SSID"
            else
                notify-send -t 5000 "󰤮 Wi-Fi" "Failed to connect to $SSID"
            fi
        else
            PASS=$(rofi -dmenu -password \
                -theme ~/.config/rofi/volume-popup.rasi \
                -theme-str "textbox-prompt { str: \"󰌌  Password for $SSID\"; text-color: #89b4fa; }" \
                -theme-str 'window { border-color: #89b4fa; width: 450px; }' \
                -theme-str 'listview { lines: 0; }' \
                -p "" 2>/dev/null)
            [ -z "$PASS" ] && exit 0
            notify-send -t 5000 "󰤨 Wi-Fi" "Connecting to $SSID..."
            RESULT=$(nmcli device wifi connect "$SSID" password "$PASS" 2>&1)
            if echo "$RESULT" | grep -q "successfully activated"; then
                notify-send -t 3000 "󰤨 Wi-Fi" "Connected to $SSID"
            else
                notify-send -t 5000 "󰤮 Wi-Fi" "Failed: $RESULT"
            fi
        fi
        ;;
esac
