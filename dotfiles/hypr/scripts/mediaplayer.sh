#!/bin/bash

clean() {
    LC_ALL=C sed 's/[^ -~]//g; s/  */ /g; s/^ *//; s/ *$//'
}

STATUS=$(playerctl status 2>/dev/null)
if [ "$STATUS" != "Playing" ] && [ "$STATUS" != "Paused" ]; then
    echo ""
    exit 0
fi

TITLE=$(playerctl metadata title 2>/dev/null | clean)
ARTIST=$(playerctl metadata artist 2>/dev/null | clean)
PLAYER=$(playerctl metadata --format "{{playerName}}" 2>/dev/null)
ALBUM=$(playerctl metadata album 2>/dev/null | clean)

case "$PLAYER" in
    brave)   ICON="󰖟" ;;
    firefox) ICON="󰈹" ;;
    spotify) ICON="󰓇" ;;
    chromium) ICON="󰊯" ;;
    *)       ICON="󰎈" ;;
esac

[ "$STATUS" = "Paused" ] && ICON="󰏤"

[ -z "$TITLE" ] && TITLE="Unknown"

if [ -n "$ARTIST" ]; then
    TEXT="$ICON  $TITLE - $ARTIST"
else
    TEXT="$ICON  $TITLE"
fi

MAX=35
if [ ${#TEXT} -gt $MAX ]; then
    TEXT="${TEXT:0:$((MAX-1))}…"
fi

CLASS=$(echo "$STATUS" | tr '[:upper:]' '[:lower:]')

TOOLTIP="$PLAYER: $TITLE"
[ -n "$ALBUM" ] && TOOLTIP="$TOOLTIP\n$ALBUM"

printf '{"text": "%s", "tooltip": "%s", "class": "%s"}\n' \
    "$TEXT" "$TOOLTIP" "$CLASS"
