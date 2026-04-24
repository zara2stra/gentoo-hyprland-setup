#!/bin/bash

clean_name() {
    echo "$1" | LC_ALL=C sed 's/[^ -~]//g' | sed 's/  */ /g; s/ *$//'
}

strip_ansi() {
    sed 's/\x1b\[[0-9;]*m//g' | tr -d '\r'
}

POWERED=$(echo "show" | bluetoothctl 2>/dev/null | grep "Powered:" | awk '{print $2}')

if [ "$POWERED" != "yes" ]; then
    CHOSEN=$(echo -e "  Power On" | rofi -dmenu -i \
        -theme ~/.config/rofi/volume-popup.rasi \
        -theme-str 'textbox-prompt { str: "󰂲  Bluetooth Off"; text-color: #a6adc8; }' \
        -theme-str 'window { border-color: #45475a; width: 350px; }' \
        -theme-str 'listview { lines: 1; }' \
        -p "" 2>/dev/null)
    if [ -n "$CHOSEN" ]; then
        echo -e "power on\nquit" | bluetoothctl 2>/dev/null
        sleep 2
    fi
    exit 0
fi

MENU=""
PAIRED_RAW=$(echo "devices Paired" | bluetoothctl 2>/dev/null | grep "^Device")
DEVINFO=""
while read -r line; do
    [ -z "$line" ] && continue
    MAC=$(echo "$line" | awk '{print $2}')
    NAME=$(clean_name "$(echo "$line" | cut -d' ' -f3-)")
    [ -z "$MAC" ] && continue
    CONN=$(echo "info $MAC" | bluetoothctl 2>/dev/null | grep "Connected:" | awk '{print $2}')
    if [ "$CONN" = "yes" ]; then
        MENU+="󰂱  $NAME  [connected]\n"
    else
        MENU+="󰂯  $NAME  [paired]\n"
    fi
    DEVINFO+="${NAME};;${MAC};;${CONN}\n"
done <<< "$PAIRED_RAW"

[ -n "$MENU" ] && MENU+="─────────────────\n"
MENU+="  Scan for New Devices\n"
MENU+="  Power Off"

SEL=$(echo -e "$MENU" | rofi -dmenu -i \
    -theme ~/.config/rofi/volume-popup.rasi \
    -theme-str 'textbox-prompt { str: "󰂯  Bluetooth"; text-color: #89b4fa; }' \
    -theme-str 'window { border-color: #89b4fa; width: 500px; }' \
    -theme-str 'listview { lines: 12; }' \
    -p "" 2>/dev/null)

case "$SEL" in
    ""|"─"*) exit 0 ;;

    *"Power Off"*)
        echo -e "power off\nquit" | bluetoothctl 2>/dev/null
        sleep 1
        exit 0 ;;

    *"Scan for New"*)
        # --- SCAN + PAIR in ONE session ---
        NOTI_ID=$(notify-send -p -t 22000 "󰂯 Bluetooth" "Scanning for devices (20s)...")

        ID=$(date +%s%N)
        FIFO="/tmp/bt_fifo_${ID}"
        OUT="/tmp/bt_out_${ID}"
        rm -f "$FIFO" "$OUT"; mkfifo "$FIFO"
        script -qc "bluetoothctl" /dev/null < "$FIFO" > "$OUT" 2>&1 &
        BTPID=$!
        exec 4>"$FIFO"

        echo "power on" >&4
        echo "scan on" >&4
        sleep 20

        echo "devices" >&4
        sleep 1

        RAW=$(strip_ansi < "$OUT")

        SCANLIST=""
        SCANMENU=""
        while read -r dline; do
            DMAC=$(echo "$dline" | awk '{print $2}')
            DNAME=$(clean_name "$(echo "$dline" | cut -d' ' -f3-)")
            [ -z "$DMAC" ] && continue
            echo "$DNAME" | grep -qE '^([0-9A-Fa-f]{2}[-:]){5}[0-9A-Fa-f]{2}$' && continue
            echo -e "$DEVINFO" | grep -q "$DMAC" && continue
            SCANLIST+="${DNAME};;${DMAC}\n"
            SCANMENU+="󰂲  $DNAME\n"
        done <<< "$(echo "$RAW" | grep "^Device " | sort -u)"

        if [ -z "$SCANMENU" ]; then
            echo "scan off" >&4; sleep 1; echo "quit" >&4
            exec 4>&-; wait $BTPID 2>/dev/null
            rm -f "$FIFO" "$OUT"
            notify-send -r "$NOTI_ID" -t 3000 "󰂲 Bluetooth" "No new devices found"
            exit 0
        fi

        # Keep scan running while user picks from menu
        SSEL=$(echo -e "$SCANMENU" | rofi -dmenu -i \
            -theme ~/.config/rofi/volume-popup.rasi \
            -theme-str 'textbox-prompt { str: "󰂯  New Devices"; text-color: #89b4fa; }' \
            -theme-str 'window { border-color: #89b4fa; width: 500px; }' \
            -theme-str 'listview { lines: 15; }' \
            -p "" 2>/dev/null)

        if [ -z "$SSEL" ]; then
            echo "scan off" >&4; sleep 1; echo "quit" >&4
            exec 4>&-; wait $BTPID 2>/dev/null
            rm -f "$FIFO" "$OUT"
            exit 0
        fi

        SSEL_NAME=$(echo "$SSEL" | sed 's/^[^ ]* *//')
        SSEL_MAC=$(echo -e "$SCANLIST" | grep "$SSEL_NAME" | head -1 | awk -F';;' '{print $2}')

        NOTI_ID=$(notify-send -p -r "$NOTI_ID" -t 40000 "󰂯 Bluetooth" "Pairing with $SSEL_NAME...")

        # Ensure device MAC is in adapter cache before pairing
        FOUND=0
        for _w in $(seq 1 15); do
            if strip_ansi < "$OUT" | grep -q "Device $SSEL_MAC"; then
                FOUND=1; break
            fi
            sleep 1
        done

        if [ "$FOUND" = "0" ]; then
            echo "scan off" >&4; sleep 1; echo "quit" >&4
            exec 4>&-; wait $BTPID 2>/dev/null
            rm -f "$FIFO" "$OUT"
            notify-send -r "$NOTI_ID" -t 5000 "󰂲 Bluetooth" "Device $SSEL_NAME not found. Ensure it's in pairing mode."
            exit 0
        fi

        echo "trust $SSEL_MAC" >&4
        sleep 1
        echo "pair $SSEL_MAC" >&4
        sleep 10
        echo "connect $SSEL_MAC" >&4
        sleep 6
        echo "scan off" >&4
        sleep 1
        echo "quit" >&4
        exec 4>&-
        wait $BTPID 2>/dev/null
        PAIRLOG=$(strip_ansi < "$OUT")
        rm -f "$FIFO" "$OUT"

        if echo "$PAIRLOG" | grep -q "Connection successful"; then
            notify-send -r "$NOTI_ID" -t 3000 "󰂱 Bluetooth" "Connected to $SSEL_NAME"
        elif echo "$PAIRLOG" | grep -q "Pairing successful"; then
            notify-send -r "$NOTI_ID" -t 3000 "󰂱 Bluetooth" "Paired with $SSEL_NAME (may need reconnect)"
        else
            notify-send -r "$NOTI_ID" -t 5000 "󰂲 Bluetooth" "Failed to connect $SSEL_NAME. Ensure it's in pairing mode."
        fi
        exit 0
        ;;

    *)
        # --- DEVICE ACTION ---
        SEL_NAME=$(echo "$SEL" | sed 's/^[^ ]* *//' | sed 's/ *\[connected\]$//' | sed 's/ *\[paired\]$//')
        SEL_MAC=$(echo -e "$DEVINFO" | grep "$SEL_NAME" | head -1 | awk -F';;' '{print $2}')
        SEL_CONN=$(echo -e "$DEVINFO" | grep "$SEL_NAME" | head -1 | awk -F';;' '{print $3}')

        if [ "$SEL_CONN" = "yes" ]; then
            DEVACT=$(echo -e "  Disconnect\n  Remove Device" | rofi -dmenu -i \
                -theme ~/.config/rofi/volume-popup.rasi \
                -theme-str "textbox-prompt { str: \"󰂱  $SEL_NAME\"; text-color: #a6e3a1; }" \
                -theme-str 'window { border-color: #a6e3a1; width: 400px; }' \
                -theme-str 'listview { lines: 2; }' \
                -p "" 2>/dev/null)
            case "$DEVACT" in
                *"Disconnect"*)
                    ID=$(date +%s%N)
                    FIFO="/tmp/bt_fifo_${ID}"; OUT="/tmp/bt_out_${ID}"
                    rm -f "$FIFO" "$OUT"; mkfifo "$FIFO"
                    script -qc "bluetoothctl" /dev/null < "$FIFO" > "$OUT" 2>&1 &
                    BTPID=$!; exec 4>"$FIFO"
                    echo "disconnect $SEL_MAC" >&4
                    sleep 5
                    echo "quit" >&4; exec 4>&-; wait $BTPID 2>/dev/null
                    rm -f "$FIFO" "$OUT"
                    notify-send -t 3000 "󰂲 Bluetooth" "Disconnected $SEL_NAME"
                    ;;
                *"Remove"*)
                    RN=$(notify-send -p -t 15000 "󰂲 Bluetooth" "Removing $SEL_NAME...")
                    ID=$(date +%s%N)
                    FIFO="/tmp/bt_fifo_${ID}"; OUT="/tmp/bt_out_${ID}"
                    rm -f "$FIFO" "$OUT"; mkfifo "$FIFO"
                    script -qc "bluetoothctl" /dev/null < "$FIFO" > "$OUT" 2>&1 &
                    BTPID=$!; exec 4>"$FIFO"
                    echo "disconnect $SEL_MAC" >&4
                    sleep 5
                    echo "untrust $SEL_MAC" >&4
                    sleep 1
                    echo "remove $SEL_MAC" >&4
                    sleep 3
                    echo "quit" >&4; exec 4>&-; wait $BTPID 2>/dev/null
                    RESULT=$(strip_ansi < "$OUT")
                    rm -f "$FIFO" "$OUT"
                    if echo "$RESULT" | grep -q "Device has been removed"; then
                        notify-send -r "$RN" -t 3000 "󰂲 Bluetooth" "Removed $SEL_NAME"
                    else
                        notify-send -r "$RN" -t 3000 "⚠ Bluetooth" "Remove may have failed for $SEL_NAME"
                    fi
                    ;;
            esac
        else
            DEVACT=$(echo -e "  Connect\n  Remove Device" | rofi -dmenu -i \
                -theme ~/.config/rofi/volume-popup.rasi \
                -theme-str "textbox-prompt { str: \"󰂯  $SEL_NAME\"; text-color: #89b4fa; }" \
                -theme-str 'window { border-color: #89b4fa; width: 400px; }' \
                -theme-str 'listview { lines: 2; }' \
                -p "" 2>/dev/null)
            case "$DEVACT" in
                *"Connect"*)
                    CN=$(notify-send -p -t 8000 "󰂯 Bluetooth" "Connecting to $SEL_NAME...")
                    ID=$(date +%s%N)
                    FIFO="/tmp/bt_fifo_${ID}"; OUT="/tmp/bt_out_${ID}"
                    rm -f "$FIFO" "$OUT"; mkfifo "$FIFO"
                    script -qc "bluetoothctl" /dev/null < "$FIFO" > "$OUT" 2>&1 &
                    BTPID=$!; exec 4>"$FIFO"
                    echo "connect $SEL_MAC" >&4
                    sleep 6
                    echo "quit" >&4; exec 4>&-; wait $BTPID 2>/dev/null
                    CONNLOG=$(strip_ansi < "$OUT")
                    rm -f "$FIFO" "$OUT"
                    if echo "$CONNLOG" | grep -q "Connection successful"; then
                        notify-send -r "$CN" -t 3000 "󰂱 Bluetooth" "Connected to $SEL_NAME"
                    else
                        notify-send -r "$CN" -t 5000 "󰂲 Bluetooth" "Failed to connect to $SEL_NAME"
                    fi
                    ;;
                *"Remove"*)
                    RN=$(notify-send -p -t 15000 "󰂲 Bluetooth" "Removing $SEL_NAME...")
                    ID=$(date +%s%N)
                    FIFO="/tmp/bt_fifo_${ID}"; OUT="/tmp/bt_out_${ID}"
                    rm -f "$FIFO" "$OUT"; mkfifo "$FIFO"
                    script -qc "bluetoothctl" /dev/null < "$FIFO" > "$OUT" 2>&1 &
                    BTPID=$!; exec 4>"$FIFO"
                    echo "untrust $SEL_MAC" >&4
                    sleep 1
                    echo "remove $SEL_MAC" >&4
                    sleep 3
                    echo "quit" >&4; exec 4>&-; wait $BTPID 2>/dev/null
                    RESULT=$(strip_ansi < "$OUT")
                    rm -f "$FIFO" "$OUT"
                    if echo "$RESULT" | grep -q "Device has been removed"; then
                        notify-send -r "$RN" -t 3000 "󰂲 Bluetooth" "Removed $SEL_NAME"
                    else
                        notify-send -r "$RN" -t 3000 "⚠ Bluetooth" "Remove may have failed for $SEL_NAME"
                    fi
                    ;;
            esac
        fi
        ;;
esac
