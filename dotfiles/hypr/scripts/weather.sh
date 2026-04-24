#!/bin/bash
CACHE="$HOME/.cache/weather.json"
CACHE_AGE=900

refresh_cache() {
    DATA=$(curl -sf "wttr.in/?format=j1" 2>/dev/null)
    if [ -n "$DATA" ]; then
        echo "$DATA" > "$CACHE"
    fi
}

if [ ! -f "$CACHE" ] || [ $(($(date +%s) - $(stat -c %Y "$CACHE" 2>/dev/null || echo 0))) -gt "$CACHE_AGE" ]; then
    refresh_cache
fi

if [ ! -f "$CACHE" ]; then
    echo '{"text": "--°", "tooltip": "No data"}'
    exit 0
fi

TEMP=$(jq -r '.current_condition[0].temp_C // "--"' "$CACHE")
FEEL=$(jq -r '.current_condition[0].FeelsLikeC // "--"' "$CACHE")
DESC=$(jq -r '.current_condition[0].weatherDesc[0].value // "Unknown"' "$CACHE")
HUMIDITY=$(jq -r '.current_condition[0].humidity // "--"' "$CACHE")
WIND=$(jq -r '.current_condition[0].windspeedKmph // "--"' "$CACHE")
CODE=$(jq -r '.current_condition[0].weatherCode // "0"' "$CACHE")

case "$CODE" in
    113) ICON="󰖙" ;;
    116) ICON="󰖐" ;;
    119|122) ICON="󰖐" ;;
    143|248|260) ICON="󰖑" ;;
    176|263|266|293|296) ICON="󰖗" ;;
    299|302|305|308|311|314|317) ICON="󰖖" ;;
    320|323|326|329|332|335|338|350|368|371|374|377|392|395) ICON="󰖘" ;;
    200|386|389) ICON="󰖓" ;;
    *) ICON="󰖙" ;;
esac

TOOLTIP="$DESC\nFeels like: ${FEEL}°C\nHumidity: ${HUMIDITY}%\nWind: ${WIND} km/h"

printf '{"text": "%s°C", "tooltip": "%s", "icon": "%s"}\n' "$TEMP" "$TOOLTIP" "$ICON"
