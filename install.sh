#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log()  { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*" >&2; }
phase() { echo -e "\n${CYAN}${BOLD}=== Phase $1: $2 ===${NC}\n"; }

usage() {
    echo "Usage: $0 --user <username> --password <password> --hostname <hostname> [--timezone <tz>]"
    echo ""
    echo "  --user       Username to create (added to wheel, video, audio, input)"
    echo "  --password   Password for the new user"
    echo "  --hostname   Machine hostname"
    echo "  --timezone   Timezone (default: Europe/Amsterdam)"
    echo ""
    echo "Run as root on a minimal Gentoo install with kernel + bootloader only."
    exit 1
}

TARGET_USER=""
TARGET_PASS=""
TARGET_HOSTNAME=""
TARGET_TZ="Europe/Amsterdam"

while [[ $# -gt 0 ]]; do
    case $1 in
        --user)      TARGET_USER="$2"; shift 2 ;;
        --password)  TARGET_PASS="$2"; shift 2 ;;
        --hostname)  TARGET_HOSTNAME="$2"; shift 2 ;;
        --timezone)  TARGET_TZ="$2"; shift 2 ;;
        -h|--help)   usage ;;
        *)           err "Unknown option: $1"; usage ;;
    esac
done

[[ -z "$TARGET_USER" ]] && { err "--user is required"; usage; }
[[ -z "$TARGET_PASS" ]] && { err "--password is required"; usage; }
[[ -z "$TARGET_HOSTNAME" ]] && { err "--hostname is required"; usage; }
[[ $EUID -ne 0 ]] && { err "This script must be run as root"; exit 1; }
TARGET_HOME="/home/$TARGET_USER"

echo -e "${BOLD}"
echo "  Gentoo Hyprland Desktop Setup"
echo "  =============================="
echo -e "${NC}"
echo "  User:     $TARGET_USER"
echo "  Password: ****"
echo "  Hostname: $TARGET_HOSTNAME"
echo "  Timezone: $TARGET_TZ"
echo "  Cores:    $(nproc)"
echo ""
read -rp "Proceed? [y/N] " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

# ─────────────────────────────────────────────
phase 1 "Portage configuration"
# ─────────────────────────────────────────────

NCORES=$(nproc)
log "Detected $NCORES CPU cores"

log "Installing make.conf"
cp "$SCRIPT_DIR/portage/make.conf" /etc/portage/make.conf
sed -i "s/MAKEOPTS=\"-j[0-9]*\"/MAKEOPTS=\"-j${NCORES}\"/" /etc/portage/make.conf

log "Installing package.use files"
[[ -f /etc/portage/package.use ]] && mv /etc/portage/package.use /etc/portage/package.use.bak
mkdir -p /etc/portage/package.use
cp "$SCRIPT_DIR"/portage/package.use/* /etc/portage/package.use/

log "Installing package.accept_keywords files"
[[ -f /etc/portage/package.accept_keywords ]] && mv /etc/portage/package.accept_keywords /etc/portage/package.accept_keywords.bak
mkdir -p /etc/portage/package.accept_keywords
cp "$SCRIPT_DIR"/portage/package.accept_keywords/* /etc/portage/package.accept_keywords/

log "Installing eselect-repository and git"
emerge -q app-eselect/eselect-repository dev-vcs/git 2>&1 | tail -5 || true

log "Enabling overlay repositories"
while IFS= read -r repo; do
    [[ -z "$repo" ]] && continue
    if eselect repository list -i 2>/dev/null | grep -q "$repo"; then
        warn "Repo '$repo' already enabled, skipping"
    else
        log "Enabling repo: $repo"
        eselect repository enable "$repo"
    fi
done < "$SCRIPT_DIR/portage/repos.list"

log "Syncing repositories (this may take a while)"
emerge --sync -q 2>&1 | tail -5 || true

# ─────────────────────────────────────────────
phase 2 "Package installation"
# ─────────────────────────────────────────────

log "Installing world file"
cp "$SCRIPT_DIR/portage/world" /var/lib/portage/world

log "Installing all packages (this will take a very long time on first run)"
log "Running: emerge -uDN @world"
set +o pipefail
emerge -uDN @world 2>&1 | tee /var/log/gentoo-setup-emerge.log
EMERGE_RC=${PIPESTATUS[0]}
set -o pipefail
if [[ $EMERGE_RC -ne 0 ]]; then
    err "emerge failed (exit code $EMERGE_RC)! Check /var/log/gentoo-setup-emerge.log"
    exit 1
fi

log "Merging config file updates"
etc-update --automode -5 2>&1 | tail -5 || true

log "Installing waypaper (pip)"
pip install --break-system-packages waypaper 2>&1 | tail -3 || warn "waypaper pip install failed (non-critical)"

# ─────────────────────────────────────────────
phase 3 "User creation"
# ─────────────────────────────────────────────

if id "$TARGET_USER" &>/dev/null; then
    warn "User '$TARGET_USER' already exists, skipping creation"
else
    log "Creating user: $TARGET_USER"
    getent group plugdev &>/dev/null || groupadd plugdev
    useradd -m -G wheel,video,audio,input,plugdev -s /bin/zsh "$TARGET_USER"
    echo "$TARGET_USER:$TARGET_PASS" | chpasswd
    log "Password set for $TARGET_USER"
fi

mkdir -p "$TARGET_HOME"

log "Configuring sudo (passwordless for wheel group)"
if ! grep -q "^%wheel ALL=(ALL:ALL) NOPASSWD: ALL" /etc/sudoers 2>/dev/null; then
    echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers
fi

# ─────────────────────────────────────────────
phase 4 "Dotfile deployment"
# ─────────────────────────────────────────────

log "Deploying dotfiles to $TARGET_HOME/.config"
DOTCONFIG="$TARGET_HOME/.config"
mkdir -p "$DOTCONFIG"

for dir in hypr waybar rofi kitty mako wireplumber gtk-3.0 gtk-4.0 waypaper cava udiskie fastfetch; do
    if [[ -d "$SCRIPT_DIR/dotfiles/$dir" ]]; then
        log "  Installing $dir"
        cp -r "$SCRIPT_DIR/dotfiles/$dir" "$DOTCONFIG/"
    fi
done

log "Installing starship.toml"
cp "$SCRIPT_DIR/dotfiles/starship.toml" "$DOTCONFIG/"

log "Installing shell dotfiles (.zshrc, .zprofile)"
cp "$SCRIPT_DIR/dotfiles/shell/.zshrc" "$TARGET_HOME/.zshrc"
cp "$SCRIPT_DIR/dotfiles/shell/.zprofile" "$TARGET_HOME/.zprofile"

log "Making scripts executable"
chmod +x "$DOTCONFIG"/hypr/scripts/*.sh

log "Fixing path placeholders (__HOME__ -> $TARGET_HOME)"
find "$DOTCONFIG" "$TARGET_HOME/.zshrc" "$TARGET_HOME/.zprofile" \
    -type f -exec sed -i "s|__HOME__|$TARGET_HOME|g" {} +

log "Setting imv as default image viewer"
MIMEAPPS="$DOTCONFIG/mimeapps.list"
cat > "$MIMEAPPS" <<'MIME'
[Default Applications]
image/png=imv.desktop
image/jpeg=imv.desktop
image/jpg=imv.desktop
image/gif=imv.desktop
image/webp=imv.desktop
image/bmp=imv.desktop
image/tiff=imv.desktop
image/svg+xml=imv.desktop
image/x-png=imv.desktop
MIME

log "Setting ownership"
chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME"

# ─────────────────────────────────────────────
phase 5 "System configuration"
# ─────────────────────────────────────────────

log "Installing udev rules"
cp "$SCRIPT_DIR/system/udev/80-nvidia-pm.rules" /etc/udev/rules.d/

if [[ -d /sys/class/leds/asus::kbd_backlight ]]; then
    log "ASUS keyboard backlight detected, installing backlight rule"
    cp "$SCRIPT_DIR/system/udev/99-kbd-backlight.rules" /etc/udev/rules.d/
else
    warn "No asus::kbd_backlight found, skipping keyboard backlight rule"
fi

log "Installing firewall config"
cp "$SCRIPT_DIR/system/nftables.conf" /etc/nftables.conf

log "Installing modprobe configs"
cp "$SCRIPT_DIR/system/modprobe.d/nvidia.conf" /etc/modprobe.d/

log "Installing GRUB config"
cp "$SCRIPT_DIR/system/grub/default-grub" /etc/default/grub

log "Installing Bluetooth config"
cp "$SCRIPT_DIR/system/bluetooth/main.conf" /etc/bluetooth/main.conf

log "Installing wallpaper and creating user directories"
mkdir -p "$TARGET_HOME/Downloads" "$TARGET_HOME/Pictures/Screenshots"
cp "$SCRIPT_DIR/assets/cyberpunk_image.jpg" "$TARGET_HOME/Downloads/"
chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/Downloads" "$TARGET_HOME/Pictures"

log "Installing GRUB theme"
mkdir -p /boot/grub/themes
cp -r "$SCRIPT_DIR/assets/grub-theme" /boot/grub/themes/gentoo_glass

# ─────────────────────────────────────────────
phase 6 "Service enablement"
# ─────────────────────────────────────────────

SYSTEM_SERVICES=(
    bluetooth.service
    chronyd.service
    NetworkManager.service
    nftables.service
    sshd.service
    smartd.service
    power-profiles-daemon.service
    udisks2.service
    nvidia-suspend.service
    nvidia-suspend-then-hibernate.service
    nvidia-hibernate.service
    nvidia-resume.service
)

for svc in "${SYSTEM_SERVICES[@]}"; do
    if systemctl list-unit-files "$svc" &>/dev/null; then
        log "Enabling $svc"
        systemctl enable "$svc" 2>/dev/null || warn "Could not enable $svc"
    else
        warn "Service $svc not found, skipping"
    fi
done

log "Enabling PipeWire/WirePlumber user services for $TARGET_USER"
USER_SYSD="$TARGET_HOME/.config/systemd/user"
mkdir -p "$USER_SYSD/default.target.wants" \
         "$USER_SYSD/sockets.target.wants" \
         "$USER_SYSD/pipewire.service.wants"

ln -sf /usr/lib/systemd/user/pipewire.socket       "$USER_SYSD/sockets.target.wants/pipewire.socket"
ln -sf /usr/lib/systemd/user/pipewire-pulse.socket  "$USER_SYSD/sockets.target.wants/pipewire-pulse.socket"
ln -sf /usr/lib/systemd/user/pipewire.socket        "$USER_SYSD/default.target.wants/pipewire.socket"
ln -sf /usr/lib/systemd/user/pipewire-pulse.socket  "$USER_SYSD/default.target.wants/pipewire-pulse.socket"
ln -sf /usr/lib/systemd/user/wireplumber.service     "$USER_SYSD/pipewire.service.wants/wireplumber.service"
chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.config/systemd"

# ─────────────────────────────────────────────
phase 7 "Finalize"
# ─────────────────────────────────────────────

log "Setting hostname: $TARGET_HOSTNAME"
echo "$TARGET_HOSTNAME" > /etc/hostname

log "Setting timezone: $TARGET_TZ"
ln -sf "/usr/share/zoneinfo/$TARGET_TZ" /etc/localtime

log "Configuring locale"
if ! grep -q "^en_US.UTF-8" /etc/locale.gen 2>/dev/null; then
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
fi
if ! grep -q "^en_US " /etc/locale.gen 2>/dev/null; then
    echo "en_US            # American English (United States)" >> /etc/locale.gen
fi
locale-gen 2>/dev/null || true
localectl set-locale LANG=en_US.utf8 2>/dev/null || true

log "Setting default editor to vi"
eselect editor set vi 2>/dev/null || true
env-update 2>/dev/null || true

log "Rebuilding initramfs"
KVER=$(ls /lib/modules/ | sort -V | tail -1)
if [[ -n "$KVER" ]]; then
    dracut --force "/boot/initramfs-${KVER}.img" "$KVER" 2>&1 | tail -3
    log "Initramfs rebuilt for kernel $KVER"
else
    warn "No kernel modules found, skipping initramfs rebuild"
fi

log "Regenerating GRUB config"
grub-mkconfig -o /boot/grub/grub.cfg 2>&1 | tail -5

log "Running sensors-detect"
yes "" | sensors-detect --auto 2>/dev/null | tail -5 || \
    warn "sensors-detect failed (non-critical)"

log "Rebuilding font cache"
fc-cache -f 2>/dev/null || true

echo ""
echo -e "${GREEN}${BOLD}========================================${NC}"
echo -e "${GREEN}${BOLD}  Setup complete!${NC}"
echo -e "${GREEN}${BOLD}========================================${NC}"
echo ""
echo "  User:     $TARGET_USER"
echo "  Hostname: $TARGET_HOSTNAME"
echo "  Timezone: $TARGET_TZ"
echo ""
echo "  Next steps:"
echo "    1. Reboot the machine"
echo "    2. Log in as $TARGET_USER on TTY1"
echo "    3. Hyprland will start automatically"
echo ""
echo "  The full emerge log is at /var/log/gentoo-setup-emerge.log"
echo ""
read -rp "Reboot now? [y/N] " reboot_confirm
if [[ "$reboot_confirm" =~ ^[Yy]$ ]]; then
    reboot
fi
