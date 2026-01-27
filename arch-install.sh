#!/bin/bash

# VXA Dotfiles Installation Script for Arch Linux
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

# Check if running on Arch Linux
if ! grep -q "Arch Linux" /etc/os-release && ! grep -q "ID=arch" /etc/os-release; then
    error "This script is designed for Arch Linux"
fi

log "Starting VXA dotfiles installation on Arch Linux..."

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -d "$SCRIPT_DIR/config" ]]; then
    error "Config directory not found. Make sure you're running this from the dotfiles repo."
fi

if [[ ! -d "$SCRIPT_DIR/scripts" ]]; then
    error "Scripts directory not found. Make sure you're running this from the dotfiles repo."
fi

# Update system
log "Updating system packages..."
sudo pacman -Syu --noconfirm

# Install yay AUR helper if not present
if ! command -v yay &> /dev/null; then
    log "Installing yay AUR helper..."
    sudo pacman -S --needed --noconfirm base-devel git
    cd /tmp
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd "$SCRIPT_DIR"
fi

# Install Hyprland and core dependencies
log "Installing Hyprland ecosystem..."
sudo pacman -S --needed --noconfirm \
    hyprland \
    hyprlock \
    hyprpaper \
    xdg-desktop-portal-hyprland \
    xdg-desktop-portal-gtk \
    polkit-gnome \
    polkit-kde-agent \
    qt6ct \
    qt5ct

# Install window manager and desktop essentials
log "Installing window manager essentials..."
sudo pacman -S --needed --noconfirm \
    waybar \
    wofi \
    kitty \
    thunar \
    mako \
    pavucontrol \
    brightnessctl \
    playerctl \
    grim \
    slurp \
    wl-clipboard

# Install nwg-look from AUR
yay -S --needed --noconfirm nwg-look

# Install audio system
log "Installing audio system..."
sudo pacman -S --needed --noconfirm \
    pipewire \
    pipewire-alsa \
    pipewire-pulse \
    pipewire-jack \
    wireplumber \
    easyeffects

# Install development and system tools
log "Installing development and system tools..."
sudo pacman -S --needed --noconfirm \
    neovim \
    git \
    curl \
    wget \
    fastfetch \
    htop \
    tree \
    unzip \
    zip \
    udiskie

# Install media and screenshot tools  
log "Installing media and screenshot tools..."
sudo pacman -S --needed --noconfirm cava
yay -S --needed --noconfirm satty

# Install clipboard manager
log "Installing clipse clipboard manager..."
yay -S --needed --noconfirm clipse

# Install fonts
log "Installing fonts..."
sudo pacman -S --needed --noconfirm \
    ttf-jetbrains-mono \
    ttf-jetbrains-mono-nerd \
    noto-fonts \
    noto-fonts-emoji \
    ttf-font-awesome \
    ttf-liberation \
    ttf-roboto

# Install themes and appearance tools
log "Installing themes and appearance..."
sudo pacman -S --needed --noconfirm \
    gtk3 \
    gtk4 \
    papirus-icon-theme \
    adwaita-icon-theme

# Install flatpak and add Flathub
log "Setting up Flatpak..."
sudo pacman -S --needed --noconfirm flatpak
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Install applications referenced in startup config
log "Installing applications from startup config..."

# Steam (gaming)
sudo pacman -S --needed --noconfirm steam

# Spotify (music)
flatpak install -y flathub com.spotify.Client || warning "Spotify flatpak install failed"

# Discord
sudo pacman -S --needed --noconfirm discord

# Zen Browser from AUR
log "Installing Zen Browser from AUR..."
yay -S --needed --noconfirm zen-browser-bin || {
    log "Zen Browser not available, installing Firefox as fallback..."
    sudo pacman -S --needed --noconfirm firefox
}

# CoreCtrl for GPU management
yay -S --needed --noconfirm corectrl || warning "CoreCtrl installation failed"

# OpenRGB for RGB control
sudo pacman -S --needed --noconfirm openrgb

# Sunshine game streaming
yay -S --needed --noconfirm sunshine || warning "Sunshine installation failed"

# Vorta backup
flatpak install -y flathub com.borgbase.Vorta || warning "Vorta flatpak install failed"

# Optional: Install additional useful packages
read -p "$(echo -e "${YELLOW}Do you want to install additional development packages? (code, gimp, vlc, etc.) [y/N]:${NC} ")" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log "Installing additional packages..."
    
    # Install via pacman
    sudo pacman -S --needed --noconfirm \
        code \
        gimp \
        vlc \
        libreoffice-fresh \
        thunderbird \
        transmission-gtk \
        obs-studio \
        blender
fi

# Create config directories if they don't exist
log "Creating config directories..."
mkdir -p ~/.config
mkdir -p ~/.local/share

# Backup existing configs (if any)
BACKUP_DIR="$HOME/.config_backup_$(date +%Y%m%d_%H%M%S)"

# Get list of config directories to copy
CONFIG_DIRS=($(ls -1 "$SCRIPT_DIR/config" | grep -v "ok.txt"))

for dir in "${CONFIG_DIRS[@]}"; do
    if [[ -d "$HOME/.config/$dir" ]]; then
        log "Backing up existing $dir config..."
        mkdir -p "$BACKUP_DIR"
        mv "$HOME/.config/$dir" "$BACKUP_DIR/"
    fi
done

# Copy config files
log "Copying configuration files..."
for dir in "${CONFIG_DIRS[@]}"; do
    if [[ -d "$SCRIPT_DIR/config/$dir" ]]; then
        log "Installing $dir configuration..."
        cp -r "$SCRIPT_DIR/config/$dir" "$HOME/.config/"
        success "$dir config installed"
    fi
done

# Copy scripts folder to home directory
log "Installing scripts to home directory..."
if [[ -d "$HOME/scripts" ]]; then
    log "Backing up existing scripts folder..."
    mv "$HOME/scripts" "$HOME/scripts_backup_$(date +%Y%m%d_%H%M%S)"
fi

cp -r "$SCRIPT_DIR/scripts" "$HOME/"
success "Scripts installed to ~/scripts"

# Set proper permissions
log "Setting proper permissions..."
chmod +x "$HOME/.config/waybar/mediaplayer.sh" 2>/dev/null || true
find "$HOME/.config" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
find "$HOME/scripts" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

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

# Set up gtk themes (referenced in startup config)
log "Setting up GTK themes..."
gsettings set org.gnome.desktop.interface color-scheme "prefer-dark" 2>/dev/null || true
gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark" 2>/dev/null || true

# Install Neovim plugins (if lazy.nvim is used)
if [[ -f "$HOME/.config/nvim/init.lua" ]]; then
    log "Setting up Neovim..."
    # Run nvim headlessly to install plugins
    nvim --headless +qall 2>/dev/null || true
fi

# Add scripts to PATH if not already there
log "Setting up scripts PATH..."
if ! grep -q "$HOME/scripts" "$HOME/.bashrc" 2>/dev/null; then
    echo 'export PATH="$HOME/scripts:$PATH"' >> "$HOME/.bashrc"
fi

if [[ -f "$HOME/.zshrc" ]] && ! grep -q "$HOME/scripts" "$HOME/.zshrc" 2>/dev/null; then
    echo 'export PATH="$HOME/scripts:$PATH"' >> "$HOME/.zshrc"
fi

# Create Pictures/Screenshots directory (referenced in keybind)
mkdir -p "$HOME/Pictures/Screenshots"

# Check if Hyprland session exists, create if needed
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
echo -e "  ${GREEN}✓${NC} Mako notification daemon"
echo -e "  ${GREEN}✓${NC} All configuration files"
echo -e "  ${GREEN}✓${NC} Audio system (PipeWire + EasyEffects)"
echo -e "  ${GREEN}✓${NC} Screenshot tools (Grim + Slurp + Satty)"
echo -e "  ${GREEN}✓${NC} Clipboard manager (Clipse)"
echo -e "  ${GREEN}✓${NC} Audio visualizer (Cava)"
echo -e "  ${GREEN}✓${NC} Scripts folder (~scripts)"
echo -e "  ${GREEN}✓${NC} Fonts and themes"
echo -e "  ${GREEN}✓${NC} Applications (Steam, Spotify, Discord, etc.)"

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
echo "  Super + Return      : Open terminal (kitty)"
echo "  Super + Space       : Open app launcher (wofi)"
echo "  Super + F           : Open file manager (thunar)"
echo "  Super + E           : Open browser (zen-browser/firefox)"
echo "  Super + V           : Open clipboard manager (clipse)"
echo "  Super + L           : Lock screen"
echo "  Super + Q           : Close window"
echo "  Super + M           : Exit Hyprland"
echo "  Super + Shift + S   : Take screenshot"
echo "  Super + 1-9         : Switch workspaces"
echo "  Super + N           : Run daily.sh script"
echo
log "Check ~/.config/hypr/configs/binds.conf for all keybindings"
log "Scripts are available in ~/scripts and added to PATH"
echo

success "Enjoy your new Hyprland setup on Arch! 🚀"