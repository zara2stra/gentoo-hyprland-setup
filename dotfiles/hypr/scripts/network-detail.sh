#!/bin/bash
IFACE=$(ip route | grep default | awk "{print \$5}" | head -1)
IP=$(ip -4 addr show "$IFACE" 2>/dev/null | grep inet | awk "{print \$2}")
GW=$(ip route | grep default | awk "{print \$3}" | head -1)
DNS=$(grep nameserver /etc/resolv.conf | head -1 | awk "{print \$2}")
SSID=$(iw dev 2>/dev/null | grep ssid | awk "{print \$2}")
SIGNAL=$(iw dev "$IFACE" link 2>/dev/null | grep signal | awk "{print \$2\" \"\$3}")
FREQ=$(iw dev "$IFACE" link 2>/dev/null | grep freq | awk "{print \$2}")
TX=$(iw dev "$IFACE" link 2>/dev/null | grep "tx bitrate" | awk "{print \$3\" \"\$4}")
PUBLIC_IP=$(curl -sf --max-time 3 ifconfig.me)

LINES="  Interface    $IFACE"
[ -n "$SSID" ]      && LINES="$LINES\n  SSID         $SSID"
[ -n "$SIGNAL" ]    && LINES="$LINES\n  Signal       $SIGNAL"
[ -n "$FREQ" ]      && LINES="$LINES\n  Frequency    ${FREQ} MHz"
[ -n "$TX" ]        && LINES="$LINES\n  TX Rate      $TX"
LINES="$LINES\n  Local IP     $IP"
LINES="$LINES\n  Gateway      $GW"
LINES="$LINES\n  DNS          $DNS"
[ -n "$PUBLIC_IP" ] && LINES="$LINES\n  Public IP    $PUBLIC_IP"

echo -e "$LINES" | rofi -dmenu -theme ~/.config/rofi/info-popup.rasi \
    -theme-str "textbox-prompt { str: \"  Network\"; text-color: #89b4fa; }" \
    -theme-str "window { border-color: #89b4fa; }" \
    -p "" > /dev/null 2>&1
