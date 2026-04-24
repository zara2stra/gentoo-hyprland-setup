#!/bin/bash
VOL=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)
PERCENT=$(echo "$VOL" | awk "{printf \"%.0f\", \$2*100}")
if echo "$VOL" | grep -q MUTED; then
    echo "{\"text\": \"Muted\", \"tooltip\": \"Volume: ${PERCENT}% [Muted]\", \"class\": \"muted\", \"percentage\": 0}"
else
    echo "{\"text\": \"${PERCENT}%\", \"tooltip\": \"Volume: ${PERCENT}%\", \"class\": \"\", \"percentage\": ${PERCENT}}"
fi
