#!/bin/bash

CPU=$(awk '/^cpu /{u=$2+$4; t=$2+$4+$5; if(t>0) printf "%.0f", u*100/t}' /proc/stat)
MEM=$(awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{printf "%.0f", (t-a)*100/t}' /proc/meminfo)

printf '{"text": "%s%%  %s%%", "tooltip": "CPU: %s%%\\nRAM: %s%%", "class": ""}\n' \
    "$CPU" "$MEM" "$CPU" "$MEM"
