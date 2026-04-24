#!/bin/bash
SCREENSHOTS_DIR="$HOME/Pictures/Screenshots"
mkdir -p "$SCREENSHOTS_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
FILENAME="$SCREENSHOTS_DIR/screenshot_$TIMESTAMP.png"

do_edit() {
    if command -v swappy &>/dev/null; then
        swappy -f "$1" -o "$1"
    fi
}

case "$1" in
    --full)
        grim "$FILENAME"
        if [ "$2" = "--edit" ]; then do_edit "$FILENAME"; fi
        wl-copy < "$FILENAME"
        notify-send -i "$FILENAME" "Screenshot" "Fullscreen saved"
        ;;
    --edit)
        grim -g "$(slurp -d)" "$FILENAME"
        do_edit "$FILENAME"
        wl-copy < "$FILENAME"
        notify-send -i "$FILENAME" "Screenshot" "Region saved & edited"
        ;;
    *)
        grim -g "$(slurp -d)" "$FILENAME"
        wl-copy < "$FILENAME"
        notify-send -i "$FILENAME" "Screenshot" "Region saved"
        ;;
esac
