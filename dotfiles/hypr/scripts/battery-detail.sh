#!/bin/bash
BAT="/sys/class/power_supply/BAT0"
[ ! -d "$BAT" ] && BAT="/sys/class/power_supply/BAT1"
if [ ! -d "$BAT" ]; then
    echo "No battery found" | rofi -dmenu -theme ~/.config/rofi/info-popup.rasi -p ""
    exit 0
fi

STATUS=$(cat "$BAT/status" 2>/dev/null)
CAPACITY=$(cat "$BAT/capacity" 2>/dev/null)
ENERGY_NOW=$(cat "$BAT/energy_now" 2>/dev/null)
ENERGY_FULL=$(cat "$BAT/energy_full" 2>/dev/null)
ENERGY_DESIGN=$(cat "$BAT/energy_full_design" 2>/dev/null)
POWER=$(cat "$BAT/power_now" 2>/dev/null)
CYCLE=$(cat "$BAT/cycle_count" 2>/dev/null)
TECH=$(cat "$BAT/technology" 2>/dev/null)

HEALTH=""
if [ -n "$ENERGY_FULL" ] && [ -n "$ENERGY_DESIGN" ] && [ "$ENERGY_DESIGN" -gt 0 ]; then
    HEALTH=$(awk "BEGIN {printf \"%.1f%%\", ($ENERGY_FULL/$ENERGY_DESIGN)*100}")
fi

WATTS=""
TIME_LEFT=""
if [ -n "$POWER" ] && [ "$POWER" -gt 0 ]; then
    WATTS=$(awk "BEGIN {printf \"%.1fW\", $POWER/1000000}")
    if [ "$STATUS" = "Discharging" ] && [ -n "$ENERGY_NOW" ]; then
        HOURS=$(awk "BEGIN {printf \"%.1f\", $ENERGY_NOW/$POWER}")
        TIME_LEFT="${HOURS}h remaining"
    elif [ "$STATUS" = "Charging" ] && [ -n "$ENERGY_FULL" ] && [ -n "$ENERGY_NOW" ]; then
        REMAIN=$((ENERGY_FULL - ENERGY_NOW))
        HOURS=$(awk "BEGIN {printf \"%.1f\", $REMAIN/$POWER}")
        TIME_LEFT="${HOURS}h to full"
    fi
fi

LINES="  Status       $STATUS"
LINES="$LINES\n  Charge       ${CAPACITY}%"
[ -n "$WATTS" ]     && LINES="$LINES\n  Power        $WATTS"
[ -n "$TIME_LEFT" ] && LINES="$LINES\n  Estimate     $TIME_LEFT"
[ -n "$HEALTH" ]    && LINES="$LINES\n  Health       $HEALTH"
[ -n "$CYCLE" ]     && LINES="$LINES\n  Cycles       $CYCLE"
[ -n "$TECH" ]      && LINES="$LINES\n  Technology   $TECH"

echo -e "$LINES" | rofi -dmenu -theme ~/.config/rofi/info-popup.rasi \
    -theme-str "textbox-prompt { str: \"  Battery\"; text-color: #a6e3a1; }" \
    -theme-str "window { border-color: #a6e3a1; width: 450px; }" \
    -p "" > /dev/null 2>&1
