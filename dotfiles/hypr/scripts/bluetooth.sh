#!/bin/bash

clean_name() {
    echo "$1" | LC_ALL=C sed 's/[^ -~]//g' | sed 's/  */ /g; s/ *$//'
}

INFO=$(echo "show" | bluetoothctl 2>/dev/null)
POWERED=$(echo "$INFO" | grep "Powered:" | awk '{print $2}')

if [ "$POWERED" != "yes" ]; then
    printf '{"text": "Off", "tooltip": "Bluetooth off", "class": "off"}\n'
    exit 0
fi

CONNECTED=$(echo "devices Connected" | bluetoothctl 2>/dev/null | grep "^Device")
if [ -n "$CONNECTED" ]; then
    DEV_NAME=$(clean_name "$(echo "$CONNECTED" | head -1 | cut -d' ' -f3-)")
    COUNT=$(echo "$CONNECTED" | wc -l)
    if [ "$COUNT" -gt 1 ]; then
        DEV_NAME="$DEV_NAME +$((COUNT-1))"
    fi
    TOOLTIP="Connected: $DEV_NAME"
    printf '{"text": "%s", "tooltip": "%s", "class": "connected"}\n' "$DEV_NAME" "$TOOLTIP"
else
    printf '{"text": "On", "tooltip": "Bluetooth on, no devices", "class": "on"}\n'
fi
