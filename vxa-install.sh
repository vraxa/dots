#!/bin/bash

# VXA Dotfiles Installation Script for Fedora
# Installs Hyprland and all required packages, then copies configs

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    error "This script should not be run as root"
fi

# Check if running on Fedora
if ! grep -q "Fedora" /etc/os-release; then
    error "This script is designed for Fedora"
fi

log "Starting VXA dotfiles installation..."

# Update system
log "Updating system packages..."
sudo dnf update -y

# Enable RPM Fusion repositories (needed for some packages)
log "Enabling RPM Fusion repositories..."
sudo dnf install -y \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm \
    || warning "RPM Fusion may already be installed"

# Install Hyprland and core dependencies
log "Installing Hyprland and core components..."
sudo dnf install -y \
    hyprland \
    hyprlock \
    hyprpaper \
    xdg-desktop-portal-hyprland \
    xdg-desktop-portal-gtk \
    polkit-gnome \
    qt6ct \
    qt5ct

# Install window manager essentials
log "Installing window manager essentials..."
sudo dnf install -y \
    waybar \
    wofi \
    kitty \
    thunar \
    pavucontrol \
    brightnessctl \
    playerctl \
    grim \
    slurp \
    wl-clipboard

# Install audio system
log "Installing audio components..."
sudo dnf install -y \
    pipewire \
    pipewire-alsa \
    pipewire-pulse \
    pipewire-jack-audio-connection-kit \
    wireplumber

# Install development and system tools
log "Installing development and system tools..."
sudo dnf install -y \
    neovim \
    git \
    curl \
    wget \
    fastfetch \
    htop \
    tree \
    unzip \
    zip

# Install fonts
log "Installing fonts..."
sudo dnf install -y \
    'jetbrains-mono-fonts*' \
    'google-noto-fonts*' \
    fontawesome-fonts

# Install flatpak if not present and add Flathub
log "Setting up Flatpak..."
sudo dnf install -y flatpak
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Create config directories if they don't exist
log "Creating config directories..."
mkdir -p ~/.config
mkdir -p ~/.local/share

# Backup existing configs (if any)
BACKUP_DIR="$HOME/.config_backup_$(date +%Y%m%d_%H%M%S)"
CONFIG_DIRS=("hypr" "waybar" "kitty" "wofi" "nvim" "fastfetch" "gtk-3.0" "gtk-4.0")

for dir in "${CONFIG_DIRS[@]}"; do
    if [[ -d "$HOME/.config/$dir" ]]; then
        log "Backing up existing $dir config..."
        mkdir -p "$BACKUP_DIR"
        mv "$HOME/.config/$dir" "$BACKUP_DIR/"
    fi
done

# Copy config files
log "Copying configuration files..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -d "$SCRIPT_DIR/config" ]]; then
    error "Config directory not found. Make sure you're running this from the dotfiles repo."
fi

# Copy each config directory
for dir in "${CONFIG_DIRS[@]}"; do
    if [[ -d "$SCRIPT_DIR/config/$dir" ]]; then
        log "Installing $dir configuration..."
        cp -r "$SCRIPT_DIR/config/$dir" "$HOME/.config/"
        success "$dir config installed"
    fi
done

# Set proper permissions
log "Setting proper permissions..."
chmod +x "$HOME/.config/waybar/mediaplayer.sh" 2>/dev/null || true
find "$HOME/.config" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

# Enable and start required services
log "Enabling required services..."
systemctl --user enable --now pipewire pipewire-pulse wireplumber 2>/dev/null || true

# Set up environment variables
log "Setting up environment variables..."
ENV_FILE="$HOME/.profile"
if ! grep -q "QT_QPA_PLATFORMTHEME" "$ENV_FILE" 2>/dev/null; then
    cat >> "$ENV_FILE" << 'EOF'

# Hyprland environment variables
export QT_QPA_PLATFORMTHEME=qt6ct
export XCURSOR_SIZE=24
export HYPRCURSOR_SIZE=24
export XDG_CURRENT_DESKTOP=Hyprland
export XDG_SESSION_TYPE=wayland
export XDG_SESSION_DESKTOP=Hyprland
EOF
fi

# Install Neovim plugins (if lazy.nvim is used)
if [[ -f "$HOME/.config/nvim/init.lua" ]]; then
    log "Setting up Neovim..."
    # Run nvim headlessly to install plugins
    nvim --headless +qall 2>/dev/null || true
fi

# Optional: Install additional useful packages
read -p "$(echo -e "${YELLOW}Do you want to install additional useful packages? (firefox, code, discord, etc.) [y/N]:${NC} ")" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log "Installing additional packages..."
    
    # Install via DNF
    sudo dnf install -y \
        firefox \
        code \
        gimp \
        vlc \
        libreoffice \
        thunderbird \
        transmission-gtk
    
    # Install via Flatpak
    log "Installing Flatpak applications..."
    flatpak install -y flathub \
        com.discordapp.Discord \
        com.spotify.Client \
        org.telegram.desktop \
        com.obsproject.Studio \
        org.blender.Blender \
        2>/dev/null || warning "Some Flatpak apps may have failed to install"
fi

# Create a desktop entry for Hyprland if it doesn't exist
HYPR_DESKTOP="/usr/share/wayland-sessions/hyprland.desktop"
if [[ ! -f "$HYPR_DESKTOP" ]]; then
    log "Creating Hyprland desktop entry..."
    sudo tee "$HYPR_DESKTOP" > /dev/null << EOF
[Desktop Entry]
Name=Hyprland
Comment=An intelligent dynamic tiling Wayland compositor
Exec=Hyprland
Type=Application
EOF
fi

# Final setup instructions
echo
success "Installation completed successfully!"
echo
log "Setup complete! Here's what was installed:"
echo -e "  ${GREEN}✓${NC} Hyprland window manager with all dependencies"
echo -e "  ${GREEN}✓${NC} Waybar status bar with custom configuration"
echo -e "  ${GREEN}✓${NC} Kitty terminal with custom theme"
echo -e "  ${GREEN}✓${NC} Wofi application launcher"
echo -e "  ${GREEN}✓${NC} All configuration files"
echo -e "  ${GREEN}✓${NC} Audio system (PipeWire)"
echo -e "  ${GREEN}✓${NC} Fonts and themes"
echo

if [[ -d "$BACKUP_DIR" ]]; then
    warning "Your old configs were backed up to: $BACKUP_DIR"
fi

echo
log "To start using Hyprland:"
echo "  1. Log out of your current session"
echo "  2. Select 'Hyprland' from your display manager"
echo "  3. Log in and enjoy!"
echo
log "Key bindings:"
echo "  Super + Return    : Open terminal (kitty)"
echo "  Super + Space     : Open app launcher (wofi)"
echo "  Super + F         : Open file manager (thunar)"
echo "  Super + L         : Lock screen"
echo "  Super + Q         : Close window"
echo "  Super + M         : Exit Hyprland"
echo "  Super + 1-9       : Switch workspaces"
echo
log "Check ~/.config/hypr/configs/binds.conf for all keybindings"
echo

success "Enjoy your new Hyprland setup! 🚀"