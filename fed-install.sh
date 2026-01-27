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

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -d "$SCRIPT_DIR/config" ]]; then
    error "Config directory not found. Make sure you're running this from the dotfiles repo."
fi

if [[ ! -d "$SCRIPT_DIR/scripts" ]]; then
    error "Scripts directory not found. Make sure you're running this from the dotfiles repo."
fi

# Update system and install copr plugin
log "Updating system packages..."
sudo dnf update -y
sudo dnf install -y dnf-plugins-core

# Enable RPM Fusion repositories (needed for some packages)
log "Enabling RPM Fusion repositories..."
sudo dnf install -y \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm \
    || warning "RPM Fusion may already be installed"

# Check if Hyprland is available, suggest Copr if not
log "Checking Hyprland availability..."
if ! dnf list available hyprland &>/dev/null; then
    warning "Hyprland not found in enabled repositories"
    read -p "$(echo -e "${YELLOW}Enable Copr repository for Hyprland? [Y/n]:${NC} ")" -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        log "Enabling Hyprland Copr repository..."
        sudo dnf copr enable -y solopasha/hyprland || warning "Failed to enable Copr repo"
    fi
fi

# Install core dependencies first
log "Installing core system dependencies..."
sudo dnf install -y \
    xdg-desktop-portal-gtk \
    qt6ct \
    qt5ct

# Try to install polkit agents (package names vary)
log "Installing polkit authentication agents..."
sudo dnf install -y polkit || warning "polkit not available"
for pkg in polkit-gnome polkit-kde lxqt-policykit; do
    sudo dnf install -y "$pkg" || warning "$pkg not available"
done

# Try to install Hyprland ecosystem (may not be fully available in all repos)
log "Attempting to install Hyprland ecosystem..."
sudo dnf install -y hyprland || {
    warning "Hyprland not available in official repos. You may need to:"
    warning "1. Enable Copr repo: sudo dnf copr enable solopasha/hyprland"
    warning "2. Or compile from source"
    error "Cannot continue without Hyprland"
}

# Try to install additional hypr tools
log "Installing additional Hyprland tools..."
for pkg in hyprlock hyprpaper xdg-desktop-portal-hyprland; do
    sudo dnf install -y "$pkg" || warning "$pkg not available in repositories"
done

# Install window manager and desktop essentials
log "Installing window manager essentials..."
sudo dnf install -y \
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
    wl-clipboard \
    nwg-look

# Install audio system
log "Installing audio system..."
sudo dnf install -y \
    pipewire \
    pipewire-alsa \
    pipewire-pulse \
    pipewire-jack-audio-connection-kit \
    wireplumber \
    easyeffects

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
    zip \
    udiskie

# Install media and screenshot tools  
log "Installing media and screenshot tools..."
sudo dnf install -y \
    satty \
    cava

# Install clipboard manager
log "Installing clipse clipboard manager..."
if ! command -v clipse &> /dev/null; then
    # Install clipse from GitHub releases if not in repos
    log "Installing clipse from GitHub..."
    CLIPSE_VERSION=$(curl -s https://api.github.com/repos/savedra1/clipse/releases/latest | grep "tag_name" | cut -d '"' -f 4)
    wget -O /tmp/clipse.tar.gz "https://github.com/savedra1/clipse/releases/download/${CLIPSE_VERSION}/clipse-${CLIPSE_VERSION}-linux-amd64.tar.gz"
    tar -xzf /tmp/clipse.tar.gz -C /tmp
    sudo mv /tmp/clipse /usr/local/bin/
    sudo chmod +x /usr/local/bin/clipse
    rm /tmp/clipse.tar.gz
fi

# Install fonts
log "Installing fonts..."
sudo dnf install -y \
    'jetbrains-mono-fonts*' \
    'google-noto-fonts*' \
    fontawesome-fonts \
    liberation-fonts \
    google-roboto-fonts

# Install themes and appearance tools
log "Installing themes and appearance..."
sudo dnf install -y \
    gtk3 \
    gtk4 \
    adwaita-gtk2-theme \
    papirus-icon-theme \
    numix-icon-theme

# Install flatpak and add Flathub
log "Setting up Flatpak..."
sudo dnf install -y flatpak
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Install applications referenced in startup config
log "Installing applications from startup config..."

# Steam (gaming)
sudo dnf install -y steam

# Spotify (music)
flatpak install -y flathub com.spotify.Client || warning "Spotify flatpak install failed"

# Discord
flatpak install -y flathub com.discordapp.Discord || warning "Discord flatpak install failed"

# Zen Browser (if available) - fallback to firefox
log "Attempting to install Zen Browser..."
if ! sudo dnf install -y zen-browser 2>/dev/null; then
    log "Zen Browser not available in repos, installing Firefox as fallback..."
    sudo dnf install -y firefox
fi

# CoreCtrl for GPU management
sudo dnf install -y corectrl || warning "CoreCtrl not available in repos"

# OpenRGB for RGB control
flatpak install -y flathub org.openrgb.OpenRGB || {
    # Try from repos if flatpak fails
    sudo dnf install -y openrgb || warning "OpenRGB installation failed"
}

# Sunshine game streaming
sudo dnf install -y sunshine || warning "Sunshine not available in repos"

# Vorta backup
flatpak install -y flathub com.borgbase.Vorta || warning "Vorta flatpak install failed"

# Optional: Install additional useful packages
read -p "$(echo -e "${YELLOW}Do you want to install additional development packages? (code, gimp, vlc, etc.) [y/N]:${NC} ")" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log "Installing additional packages..."
    
    # Install via DNF
    sudo dnf install -y \
        code \
        gimp \
        vlc \
        libreoffice \
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

success "Enjoy your new Hyprland setup! 🚀"