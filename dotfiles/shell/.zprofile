if [ -z "$WAYLAND_DISPLAY" ] && [ "$XDG_VTNR" -eq 1 ] 2>/dev/null; then
    exec start-hyprland
fi
