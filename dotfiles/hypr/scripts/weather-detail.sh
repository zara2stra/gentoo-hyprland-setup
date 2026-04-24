#!/bin/bash

DATA=$(curl -sf "wttr.in/?format=j1" 2>/dev/null)
if [ -z "$DATA" ]; then
    echo "  Could not fetch weather data" | rofi -dmenu -theme ~/.config/rofi/weather-popup.rasi -p ""
    exit 0
fi

get_icon() {
    case "$1" in
        113) echo "󰖙" ;;
        116) echo "󰖐" ;;
        119|122) echo "󰖐" ;;
        143|248|260) echo "󰖑" ;;
        176|263|266|293|296) echo "󰖗" ;;
        299|302|305|308|311|314|317) echo "󰖖" ;;
        320|323|326|329|332|335|338|350|368|371|374|377|392|395) echo "󰖘" ;;
        200|386|389) echo "󰖓" ;;
        *) echo "󰖙" ;;
    esac
}

LOCATION=$(echo "$DATA" | jq -r '.nearest_area[0].areaName[0].value // "Unknown"')
COUNTRY=$(echo "$DATA" | jq -r '.nearest_area[0].country[0].value // ""')

NOW_TEMP=$(echo "$DATA" | jq -r '.current_condition[0].temp_C')
NOW_FEEL=$(echo "$DATA" | jq -r '.current_condition[0].FeelsLikeC')
NOW_DESC=$(echo "$DATA" | jq -r '.current_condition[0].weatherDesc[0].value')
NOW_CODE=$(echo "$DATA" | jq -r '.current_condition[0].weatherCode')
NOW_HUM=$(echo "$DATA" | jq -r '.current_condition[0].humidity')
NOW_WIND=$(echo "$DATA" | jq -r '.current_condition[0].windspeedKmph')
NOW_WDIR=$(echo "$DATA" | jq -r '.current_condition[0].winddir16Point')
NOW_PRES=$(echo "$DATA" | jq -r '.current_condition[0].pressure')
NOW_UV=$(echo "$DATA" | jq -r '.current_condition[0].uvIndex')
NOW_VIS=$(echo "$DATA" | jq -r '.current_condition[0].visibility')
NOW_PREC=$(echo "$DATA" | jq -r '.current_condition[0].precipMM')
NOW_ICON=$(get_icon "$NOW_CODE")

LINES=""
LINES+="$NOW_ICON  $NOW_DESC  ·  $LOCATION, $COUNTRY\n"
LINES+="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
LINES+="󰔏  Temperature     ${NOW_TEMP}°C  (feels ${NOW_FEEL}°C)\n"
LINES+="󰖌  Humidity         ${NOW_HUM}%\n"
LINES+="󰖝  Wind             ${NOW_WIND} km/h  $NOW_WDIR\n"
LINES+="󰖖  Precipitation    ${NOW_PREC} mm\n"
LINES+="󰈈  Visibility       ${NOW_VIS} km\n"
LINES+="󰖨  UV Index         ${NOW_UV}\n"
LINES+="󰕤  Pressure         ${NOW_PRES} hPa\n"
LINES+="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"

for i in 0 1 2; do
    DAY_DATE=$(echo "$DATA" | jq -r ".weather[$i].date")
    DAY_HI=$(echo "$DATA" | jq -r ".weather[$i].maxtempC")
    DAY_LO=$(echo "$DATA" | jq -r ".weather[$i].mintempC")
    DAY_SUN=$(echo "$DATA" | jq -r ".weather[$i].astronomy[0].sunrise")
    DAY_SET=$(echo "$DATA" | jq -r ".weather[$i].astronomy[0].sunset")
    DAY_MOON=$(echo "$DATA" | jq -r ".weather[$i].astronomy[0].moon_phase")
    DAY_RAIN=$(echo "$DATA" | jq -r "[.weather[$i].hourly[].chanceofrain | tonumber] | max")

    if [ "$i" = "0" ]; then DAYNAME="Today";
    elif [ "$i" = "1" ]; then DAYNAME="Tomorrow";
    else DAYNAME=$(date -d "$DAY_DATE" +%A 2>/dev/null || echo "$DAY_DATE"); fi

    LINES+="󰃶  $DAYNAME  ($DAY_DATE)    ▲ ${DAY_HI}°   ▼ ${DAY_LO}°   󰖖 ${DAY_RAIN}%\n"
    LINES+="    󰖨 $DAY_SUN   󰖛 $DAY_SET   󰽥 $DAY_MOON\n"

    HOURS=$(echo "$DATA" | jq -r ".weather[$i].hourly | length")
    for h in $(seq 0 $((HOURS-1))); do
        H_TIME=$(echo "$DATA" | jq -r ".weather[$i].hourly[$h].time")
        H_TEMP=$(echo "$DATA" | jq -r ".weather[$i].hourly[$h].tempC")
        H_CODE=$(echo "$DATA" | jq -r ".weather[$i].hourly[$h].weatherCode")
        H_DESC=$(echo "$DATA" | jq -r ".weather[$i].hourly[$h].weatherDesc[0].value")
        H_RAIN=$(echo "$DATA" | jq -r ".weather[$i].hourly[$h].chanceofrain")
        H_ICON=$(get_icon "$H_CODE")

        H_FMT=$(printf "%04d" "$H_TIME")
        H_DISP="${H_FMT:0:2}:${H_FMT:2:2}"

        printf -v HLINE "    %s  %s  %3s°C  %-20s  󰖖%s%%" "$H_DISP" "$H_ICON" "$H_TEMP" "$H_DESC" "$H_RAIN"
        LINES+="$HLINE\n"
    done

    if [ "$i" -lt 2 ]; then
        LINES+="─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─\n"
    fi
done

echo -e "$LINES" | rofi -dmenu -theme ~/.config/rofi/weather-popup.rasi -p "" > /dev/null 2>&1
