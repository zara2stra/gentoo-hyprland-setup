# Gentoo Hyprland Desktop Setup

Automated installer that transforms a minimal Gentoo system into a fully configured Hyprland Wayland desktop with Catppuccin theming, custom Waybar widgets, Rofi popups, and all the trimmings.

![Desktop Screenshot](assets/screenshot.png)

## What you get

- **Hyprland** Wayland compositor with polished config
- **Waybar** with weather, Bluetooth, media player, CPU/RAM, WiFi, volume, and battery widgets
- **Rofi** application launcher and interactive popup panels
- **Kitty** terminal with transparency and JetBrains Mono font
- **Mako** notification daemon (Catppuccin themed)
- **PipeWire** audio with WirePlumber tuning for stable speaker/BT audio switching
- **Bluetooth** with interactive Rofi-based pairing/management
- **NetworkManager** with Rofi WiFi picker
- **imv** Wayland-native image viewer (set as default for all image types)
- **Brave** browser, Telegram, Zoom, LibreOffice, GNOME Calendar
- **Automatic hardware detection** (Intel/AMD CPU, Intel/AMD/NVIDIA GPU)
- **NVIDIA Optimus** support (Intel iGPU + NVIDIA dGPU with runtime PM)
- **nftables** firewall (SSH-only inbound)
- **GRUB** with gentoo_glass theme
- **Cyberpunk wallpaper** via hyprpaper/waypaper
- **Starship** prompt with Catppuccin colors
- **zsh** with fzf, bat, fastfetch on login

## Prerequisites

A working minimal Gentoo install with:

- Booted and running (**systemd** init, not OpenRC)
- Kernel installed and booting (`gentoo-kernel` dist-kernel recommended)
- GRUB bootloader configured
- Network connectivity (ethernet or WiFi via `wpa_supplicant`)
- `fstab` configured for your disk layout
- Root access

The script auto-detects CPU and GPU hardware. See [Hardware compatibility](#hardware-compatibility) below for tested and untested configurations.

## Usage

On the target machine (as root):

```bash
# Install git and clone the repo
emerge -q dev-vcs/git
git clone https://github.com/zara2stra/gentoo-hyprland-setup.git
cd gentoo-hyprland-setup

# Run the installer
./install.sh --user johndoe --password 's3cret!' --hostname mygentoo

# With custom timezone:
./install.sh --user johndoe --password 's3cret!' --hostname mygentoo --timezone America/New_York
```

The script will:

1. **Detect hardware** (CPU vendor, GPU vendor) and configure accordingly
2. Configure Portage (USE flags, overlays, keywords, `VIDEO_CARDS`)
3. Install ~75 packages (this takes hours on first run)
4. Create the user account
5. Deploy all dotfiles and configs
6. Set up system configs (firewall, GPU drivers, GRUB, Bluetooth, udev)
7. Enable systemd services (including GPU-specific ones if applicable)
8. Rebuild initramfs and GRUB config
9. Offer to reboot

After reboot, log in on TTY1 and Hyprland starts automatically.

## Parameters

| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--user` | Yes | - | Username to create |
| `--password` | Yes | - | Password for the new user |
| `--hostname` | Yes | - | Machine hostname |
| `--timezone` | No | `Europe/Amsterdam` | Timezone |

## Repo structure

```
portage/           Portage config (make.conf, world, USE flags, keywords, overlays)
dotfiles/          User dotfiles (~/.config/* and shell rc files)
  hypr/            Hyprland config + lock screen + idle + 16 scripts
  waybar/          Waybar config and CSS
  rofi/            Rofi launcher and popup themes
  kitty/           Kitty terminal config
  mako/            Notification daemon config
  wireplumber/     PipeWire/WirePlumber audio tuning
  gtk-3.0/         GTK3 dark theme settings
  gtk-4.0/         GTK4 dark theme settings
  waypaper/        Wallpaper manager config
  cava/            Audio visualizer config
  udiskie/         USB automount config
  fastfetch/       System info display config
  shell/           .zshrc and .zprofile
  starship.toml    Starship prompt theme
system/            System configs (root-owned)
  udev/            NVIDIA runtime PM (conditional), keyboard backlight
  modprobe.d/      NVIDIA kernel module options (conditional)
  grub/            GRUB defaults (nvidia cmdline stripped if no NVIDIA)
  bluetooth/       BlueZ config
  nftables.conf    Firewall rules
assets/            Wallpaper image and GRUB theme
install.sh         Master install script
```

## Hardware compatibility

The install script automatically detects CPU and GPU hardware via `/proc/cpuinfo` and `lspci`, then adjusts Portage settings, kernel parameters, driver packages, modprobe configs, udev rules, and systemd services accordingly.

### Tested configurations

| Configuration | CPU | GPU | Status |
|---|---|---|---|
| Intel + NVIDIA (Optimus) | Intel | NVIDIA dGPU + Intel iGPU | **Tested** -- source laptop |

### Untested configurations

These profiles are supported by the detection logic but have **not been verified on real hardware**. They should work, but manual troubleshooting may be needed after install.

| Configuration | CPU | GPU | What the script does |
|---|---|---|---|
| AMD + NVIDIA | AMD | NVIDIA dGPU | Installs NVIDIA drivers, skips intel-microcode, sets `VIDEO_CARDS="nvidia"` |
| AMD APU (integrated) | AMD | AMD Radeon (integrated) | No proprietary drivers, mesa-only, sets `VIDEO_CARDS="amdgpu radeonsi"` |
| AMD + AMD dGPU | AMD | AMD Radeon (discrete) | Same as APU -- mesa handles both, sets `VIDEO_CARDS="amdgpu radeonsi"` |
| Intel (integrated only) | Intel | Intel iGPU (no dGPU) | No NVIDIA drivers/configs, sets `VIDEO_CARDS="intel"` |

> **Important**: If you are running an untested configuration, the desktop environment should still work, but you may need to troubleshoot GPU-specific issues. The script will show the detected hardware before proceeding so you can verify it is correct.

### What changes per hardware profile

| Component | NVIDIA present | AMD GPU (no NVIDIA) | Intel-only (no NVIDIA) |
|---|---|---|---|
| `VIDEO_CARDS` in make.conf | includes `nvidia` | `amdgpu radeonsi` | `intel` |
| `x11-drivers/nvidia-drivers` | installed | not installed | not installed |
| `sys-firmware/intel-microcode` | Intel CPU only | not installed | installed |
| `media-libs/mesa` USE flags | default | `vulkan vaapi` added | default |
| `media-libs/vulkan-loader` | pulled by nvidia-drivers | added to world | not added |
| `/etc/modprobe.d/nvidia.conf` | installed | skipped | skipped |
| `/etc/udev/rules.d/80-nvidia-pm.rules` | installed | skipped | skipped |
| GRUB `nvidia-drm.modeset=1` | set | removed | removed |
| nvidia-suspend/hibernate services | enabled | skipped | skipped |

### Troubleshooting (untested hardware)

If Hyprland doesn't start or shows a black screen on AMD GPU:

1. Check that the `amdgpu` kernel module is loaded: `lsmod | grep amdgpu`
2. Verify `VIDEO_CARDS` in `/etc/portage/make.conf` contains `amdgpu radeonsi`
3. Ensure `mesa` was built with `vulkan` and `vaapi` USE flags: `emerge -pv mesa`
4. Check Hyprland logs: `cat /tmp/hypr/$HYPRLAND_INSTANCE_SIGNATURE/hyprland.log`
5. If using an older AMD GPU (pre-GCN), you may need `VIDEO_CARDS="radeon"` instead
6. Ensure `sys-kernel/linux-firmware` is installed (provides AMD GPU firmware blobs)

If the display works but Vulkan apps fail or performance is poor on AMD:

1. Verify `media-libs/vulkan-loader` is installed: `emerge -pv vulkan-loader`
2. Verify Vulkan is working: `vulkaninfo | head` (install `dev-util/vulkan-tools` if missing)
3. Check that `LIBVA_DRIVER_NAME=radeonsi` is set for VA-API hardware video decode

### General hardware notes

- `MAKEOPTS` is auto-detected from CPU core count
- Keyboard backlight udev rule only applies if `asus::kbd_backlight` is detected
- `fstab` is not touched (handled during base Gentoo install)
- Kernel config is not included (dist-kernel auto-configures)

## Post-install

- Change wallpaper: run `waypaper` from Rofi
- Bluetooth: click the Waybar Bluetooth widget
- WiFi: click the Waybar network widget
- Screenshots: `Print Screen` (region select), `Shift+Print` (region + edit), `Super+Print` (fullscreen)
- Images: double-click any image in Thunar to open in imv
- Power menu: click the power icon in Waybar
