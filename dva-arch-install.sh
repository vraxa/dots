#!/bin/bash

# VXA Dotfiles Installation Script for Arch Linux
# Installs Hyprland and all required packages, then copies configs
#
# Usage:
#   ./arch-install.sh           # Normal installation
#   ./arch-install.sh --dry-run # Preview what would be installed
#   ./arch-install.sh -n        # Same as --dry-run

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Dry run mode flag
DRY_RUN=false

# AUR helper (will be set during detection/installation)
AUR_HELPER=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run|-n)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --dry-run, -n    Preview what would be installed without making changes"
            echo "  --help, -h       Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

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

dry_run_msg() {
    echo -e "${CYAN}[DRY-RUN]${NC} $1"
}

# Wrapper for commands that should be skipped in dry-run mode
run() {
    if [[ "$DRY_RUN" == true ]]; then
        dry_run_msg "Would run: $*"
    else
        "$@"
    fi
}

# Wrapper for sudo commands
run_sudo() {
    if [[ "$DRY_RUN" == true ]]; then
        dry_run_msg "Would run (sudo): $*"
    else
        sudo "$@"
    fi
}

# Pacman install wrapper with dry-run support
pacman_install() {
    if [[ "$DRY_RUN" == true ]]; then
        dry_run_msg "Would install (pacman): $*"
    else
        sudo pacman -S --needed --noconfirm "$@"
    fi
}

# AUR install wrapper with dry-run support
aur_install() {
    if [[ "$DRY_RUN" == true ]]; then
        dry_run_msg "Would install (AUR via $AUR_HELPER): $*"
    else
        $AUR_HELPER -S --needed --noconfirm "$@"
    fi
}

# Flatpak install wrapper with dry-run support
flatpak_install() {
    if [[ "$DRY_RUN" == true ]]; then
        dry_run_msg "Would install (flatpak): $*"
    else
        flatpak install -y "$@"
    fi
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    error "This script should not be run as root"
fi

# Check if running on Arch Linux
if ! grep -q "Arch Linux" /etc/os-release && ! grep -q "EndeavourOS" /etc/os-release && ! grep -q "Manjaro" /etc/os-release; then
    error "This script is designed for Arch Linux (or Arch-based distros)"
fi

if [[ "$DRY_RUN" == true ]]; then
    echo
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}    DRY RUN MODE - No changes will be made${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo
fi

log "Starting VXA dotfiles installation for Arch Linux..."

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -d "$SCRIPT_DIR/config" ]]; then
    error "Config directory not found. Make sure you're running this from the dotfiles repo."
fi

if [[ ! -d "$SCRIPT_DIR/scripts" ]]; then
    error "Scripts directory not found. Make sure you're running this from the dotfiles repo."
fi

# Detect or install AUR helper
detect_aur_helper() {
    if command -v yay &> /dev/null; then
        AUR_HELPER="yay"
        log "Found AUR helper: yay"
    elif command -v paru &> /dev/null; then
        AUR_HELPER="paru"
        log "Found AUR helper: paru"
    else
        return 1
    fi
    return 0
}

install_yay() {
    log "Installing yay AUR helper..."
    if [[ "$DRY_RUN" == true ]]; then
        dry_run_msg "Would install yay from AUR"
        AUR_HELPER="yay"
        return 0
    fi
    
    # Install dependencies
    sudo pacman -S --needed --noconfirm git base-devel
    
    # Clone and build yay
    local tmp_dir=$(mktemp -d)
    git clone https://aur.archlinux.org/yay.git "$tmp_dir/yay"
    cd "$tmp_dir/yay"
    makepkg -si --noconfirm
    cd - > /dev/null
    rm -rf "$tmp_dir"
    
    AUR_HELPER="yay"
    success "yay installed successfully"
}

# Check for AUR helper
log "Checking for AUR helper..."
if ! detect_aur_helper; then
    warning "No AUR helper found"
    if [[ "$DRY_RUN" == true ]]; then
        dry_run_msg "Would prompt to install yay AUR helper"
        AUR_HELPER="yay"
    else
        read -p "$(echo -e "${YELLOW}Install yay AUR helper? [Y/n]:${NC} ")" -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            install_yay
        else
            error "An AUR helper is required for this installation"
        fi
    fi
fi

# Update system
log "Updating system packages..."
run_sudo pacman -Syu --noconfirm

# Install core dependencies first
log "Installing core system dependencies..."
pacman_install \
    xdg-desktop-portal-gtk \
    qt6ct \
    qt5ct

# Install polkit agents
log "Installing polkit authentication agents..."
pacman_install polkit polkit-gnome polkit-kde-agent lxqt-policykit || warning "Some polkit agents not available"

# Install Hyprland ecosystem
log "Installing Hyprland ecosystem..."
pacman_install \
    hyprland \
    xdg-desktop-portal-hyprland \
    hyprlock \
    hyprpaper

# Install window manager and desktop essentials
log "Installing window manager essentials..."
pacman_install \
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

# Install audio system
log "Installing audio system..."
pacman_install \
    pipewire \
    pipewire-alsa \
    pipewire-pulse \
    pipewire-jack \
    wireplumber \
    easyeffects

# Install development and system tools
log "Installing development and system tools..."
pacman_install \
    neovim \
    git \
    curl \
    wget \
    fastfetch \
    htop \
    tree \
    unzip \
    zip \
    udiskie \
    powerline \
    powerline-common

# Install media and screenshot tools  
log "Installing media and screenshot tools..."
pacman_install cava

# Install satty (AUR)
log "Installing satty screenshot editor..."
aur_install satty || warning "satty installation failed"

# Install clipboard manager (AUR)
log "Installing clipse clipboard manager..."
aur_install clipse || warning "clipse installation failed"

# Install fonts
log "Installing fonts..."
pacman_install \
    ttf-jetbrains-mono \
    ttf-jetbrains-mono-nerd \
    noto-fonts \
    noto-fonts-cjk \
    noto-fonts-emoji \
    ttf-font-awesome \
    ttf-liberation \
    ttf-roboto \
    powerline-fonts

# Install themes and appearance tools
log "Installing themes and appearance..."
pacman_install \
    gtk3 \
    gtk4 \
    arc-gtk-theme \
    arc-icon-theme \
    papirus-icon-theme \
    numix-icon-theme

# Adwaita is part of gtk3/gtk4 on Arch

# Install flatpak and add Flathub
log "Setting up Flatpak..."
pacman_install flatpak
if [[ "$DRY_RUN" == true ]]; then
    dry_run_msg "Would add Flathub repository"
else
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
fi

# Install applications referenced in startup config
log "Installing applications from startup config..."

# Steam (gaming)
log "Installing Steam..."
pacman_install steam || {
    warning "Steam not available via pacman, installing via Flatpak..."
    flatpak_install flathub com.valvesoftware.Steam || warning "Steam installation failed"
}

# Spotify (AUR or Flatpak)
log "Installing Spotify..."
aur_install spotify || {
    warning "Spotify AUR failed, trying Flatpak..."
    flatpak_install flathub com.spotify.Client || warning "Spotify installation failed"
}

# Discord
log "Installing Discord..."
pacman_install discord || {
    warning "Discord not in repos, trying Flatpak..."
    flatpak_install flathub com.discordapp.Discord || warning "Discord installation failed"
}

# Chromium browser
log "Installing Chromium browser..."
pacman_install chromium

# CoreCtrl for GPU management
pacman_install corectrl || warning "CoreCtrl not available"

# OpenRGB
log "Installing OpenRGB..."
pacman_install openrgb || {
    flatpak_install flathub org.openrgb.OpenRGB || warning "OpenRGB installation failed"
}

# Sunshine game streaming (AUR)
aur_install sunshine || warning "Sunshine not available"

# Vorta backup
flatpak_install flathub com.borgbase.Vorta || warning "Vorta flatpak install failed"

# ============================================
# DaVinci Resolve Installation (Optional)
# ============================================
INSTALL_DAVINCI=false

if [[ "$DRY_RUN" == true ]]; then
    dry_run_msg "Would prompt to install DaVinci Resolve dependencies"
    dry_run_msg "If accepted, would install:"
    dry_run_msg "  - libxcrypt-compat, mesa, opencl-headers"
    dry_run_msg "  - AMD: rocm-opencl-runtime (if AMD GPU detected)"
    dry_run_msg "  - Intel: intel-compute-runtime (if Intel GPU detected)"
    dry_run_msg "  - Helper script for DaVinci Resolve installation"
else
    echo
    read -p "$(echo -e "${YELLOW}Do you want to install DaVinci Resolve dependencies? [y/N]:${NC} ")" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        INSTALL_DAVINCI=true
    fi
fi

if [[ "$INSTALL_DAVINCI" == true ]]; then
    log "Setting up DaVinci Resolve dependencies..."
    # Install core DaVinci Resolve dependencies
    log "Installing DaVinci Resolve system dependencies..."
    sudo pacman -S --needed --noconfirm \
        libxcrypt-compat \
        curl \
        mesa \
        glu \
        apr \
        apr-util \
        ocl-icd \
        opencl-headers \
        alsa-lib \
        alsa-plugins \
        libxcomposite \
        libxcursor \
        libxi \
        libxinerama \
        libxrandr \
        libxrender \
        libxtst \
        libxscrnsaver \
        libxkbcommon \
        libxkbcommon-x11 \
        nspr \
        nss \
        fuse2 \
        || warning "Some DaVinci Resolve dependencies failed to install"
    
    # Detect GPU type and install appropriate drivers/OpenCL
    log "Detecting GPU for DaVinci Resolve..."
    
    if lspci | grep -i "amd\|radeon" &>/dev/null; then
        log "AMD GPU detected - installing ROCm OpenCL support..."
        
        # AMD ROCm for OpenCL support (from AUR)
        aur_install rocm-opencl-runtime rocm-hip-runtime \
            || warning "ROCm OpenCL installation failed - DaVinci Resolve may not work optimally with AMD"
        
    elif lspci | grep -i "intel.*graphics" &>/dev/null; then
        log "Intel GPU detected - installing Intel OpenCL support..."
        sudo pacman -S --needed --noconfirm \
            intel-compute-runtime \
            || warning "Intel OpenCL installation failed"
        
        warning "Intel GPU support in DaVinci Resolve is very limited"
    fi
    
    # Multimedia codecs (useful for video editing)
    log "Installing multimedia codecs for video editing..."
    sudo pacman -S --needed --noconfirm ffmpeg || warning "FFmpeg installation failed"
    
    # Ask user if they want to download and install DaVinci Resolve
    echo
    log "DaVinci Resolve dependencies are installed."
    echo -e "${YELLOW}NOTE:${NC} DaVinci Resolve must be downloaded manually from Blackmagic's website"
    echo -e "      due to licensing requirements."
    echo
    read -p "$(echo -e "${YELLOW}Would you like instructions on installing DaVinci Resolve? [Y/n]:${NC} ")" -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        echo
        log "=== DaVinci Resolve Installation Instructions ==="
        echo
        echo "Option 1: Install via AUR (recommended)"
        echo -e "   ${GREEN}$AUR_HELPER -S davinci-resolve${NC}"
        echo "   (This will guide you through downloading from Blackmagic)"
        echo
        echo "Option 2: Manual installation"
        echo "1. Download DaVinci Resolve from:"
        echo -e "   ${BLUE}https://www.blackmagicdesign.com/products/davinciresolve${NC}"
        echo
        echo "2. Extract the downloaded .zip file"
        echo
        echo "3. Run the installer with:"
        echo -e "   ${GREEN}cd ~/Downloads/DaVinci_Resolve_*_Linux${NC}"
        echo -e "   ${GREEN}sudo SKIP_PACKAGE_CHECK=1 ./DaVinci_Resolve_*_Linux.run${NC}"
        echo
        echo "4. After installation, fix library conflicts:"
        echo -e "   ${GREEN}cd /opt/resolve/libs${NC}"
        echo -e "   ${GREEN}sudo mkdir -p disabled-libraries${NC}"
        echo -e "   ${GREEN}sudo mv libglib* disabled-libraries/${NC}"
        echo -e "   ${GREEN}sudo mv libgio* disabled-libraries/${NC}"
        echo -e "   ${GREEN}sudo mv libgmodule* disabled-libraries/${NC}"
        echo
        echo "5. Launch DaVinci Resolve from your application menu"
        echo
        
        # Create a helper script for DaVinci Resolve installation
        log "Creating DaVinci Resolve installer helper script..."
        cat > "$HOME/install-davinci-resolve.sh" << 'DAVINCI_SCRIPT'
#!/bin/bash
# DaVinci Resolve Installation Helper Script for Arch Linux
# Run this after downloading DaVinci Resolve from Blackmagic's website

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== DaVinci Resolve Installation Helper ===${NC}"
echo

# Check for AUR helper
if command -v yay &> /dev/null; then
    AUR_HELPER="yay"
elif command -v paru &> /dev/null; then
    AUR_HELPER="paru"
else
    AUR_HELPER=""
fi

if [[ -n "$AUR_HELPER" ]]; then
    echo -e "${YELLOW}AUR helper detected: $AUR_HELPER${NC}"
    read -p "Install DaVinci Resolve via AUR? (recommended) [Y/n]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        echo -e "${BLUE}Installing via AUR...${NC}"
        $AUR_HELPER -S davinci-resolve
        echo -e "${GREEN}=== Installation Complete ===${NC}"
        exit 0
    fi
fi

# Manual installation
echo -e "${BLUE}Proceeding with manual installation...${NC}"

# Find the DaVinci Resolve installer
RESOLVE_ZIP=$(find ~/Downloads -maxdepth 1 -name "DaVinci_Resolve_*.zip" -type f 2>/dev/null | head -1)

if [[ -z "$RESOLVE_ZIP" ]]; then
    echo -e "${RED}Error: No DaVinci Resolve .zip file found in ~/Downloads${NC}"
    echo "Please download DaVinci Resolve from:"
    echo "https://www.blackmagicdesign.com/products/davinciresolve"
    exit 1
fi

echo -e "${GREEN}Found: $RESOLVE_ZIP${NC}"
echo

# Extract
echo -e "${BLUE}Extracting...${NC}"
cd ~/Downloads
unzip -o "$RESOLVE_ZIP"

# Find the .run file
RESOLVE_RUN=$(find ~/Downloads -maxdepth 2 -name "DaVinci_Resolve_*.run" -type f 2>/dev/null | head -1)

if [[ -z "$RESOLVE_RUN" ]]; then
    echo -e "${RED}Error: Could not find .run installer${NC}"
    exit 1
fi

echo -e "${GREEN}Found installer: $RESOLVE_RUN${NC}"
echo

# Make executable and run
chmod +x "$RESOLVE_RUN"
echo -e "${BLUE}Running installer (requires sudo)...${NC}"
sudo SKIP_PACKAGE_CHECK=1 "$RESOLVE_RUN"

# Post-installation fix
echo
echo -e "${BLUE}Applying post-installation fixes...${NC}"
if [[ -d /opt/resolve/libs ]]; then
    cd /opt/resolve/libs
    sudo mkdir -p disabled-libraries
    sudo mv libglib* disabled-libraries/ 2>/dev/null || true
    sudo mv libgio* disabled-libraries/ 2>/dev/null || true
    sudo mv libgmodule* disabled-libraries/ 2>/dev/null || true
    echo -e "${GREEN}Library fixes applied${NC}"
else
    echo -e "${YELLOW}Warning: /opt/resolve/libs not found - installation may have failed${NC}"
fi

echo
echo -e "${GREEN}=== Installation Complete ===${NC}"
echo "You can now launch DaVinci Resolve from your application menu."
DAVINCI_SCRIPT
        chmod +x "$HOME/install-davinci-resolve.sh"
        success "Helper script created: ~/install-davinci-resolve.sh"
        echo "       Run it after downloading DaVinci Resolve!"
    fi
fi

# Optional: Install additional useful packages
if [[ "$DRY_RUN" == true ]]; then
    dry_run_msg "Would prompt for additional development packages (code, gimp, vlc, etc.)"
else
    read -p "$(echo -e "${YELLOW}Do you want to install additional development packages? (code, gimp, vlc, etc.) [y/N]:${NC} ")" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Installing additional packages..."
        
        # Install via pacman
        sudo pacman -S --needed --noconfirm \
            gimp \
            vlc \
            libreoffice-fresh \
            thunderbird \
            transmission-gtk \
            obs-studio \
            blender
        
        # Install VS Code (AUR)
        log "Installing Visual Studio Code..."
        aur_install visual-studio-code-bin || warning "VS Code installation failed"
    fi
fi

# ============================================
# Config and dotfiles installation
# ============================================

# Create config directories if they don't exist
log "Creating config directories..."
run mkdir -p ~/.config
run mkdir -p ~/.local/share

# Backup existing configs (if any)
BACKUP_DIR="$HOME/.config_backup_$(date +%Y%m%d_%H%M%S)"

# Get list of config directories to copy
CONFIG_DIRS=($(ls -1 "$SCRIPT_DIR/config" | grep -v "ok.txt"))

if [[ "$DRY_RUN" == true ]]; then
    dry_run_msg "Would backup and replace the following configs:"
    for dir in "${CONFIG_DIRS[@]}"; do
        if [[ -d "$SCRIPT_DIR/config/$dir" ]]; then
            echo -e "    ${CYAN}-${NC} $dir"
        fi
    done
else
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
fi

# Copy scripts folder to home directory
log "Installing scripts to home directory..."
if [[ "$DRY_RUN" == true ]]; then
    dry_run_msg "Would copy scripts folder to ~/scripts"
else
    if [[ -d "$HOME/scripts" ]]; then
        log "Backing up existing scripts folder..."
        mv "$HOME/scripts" "$HOME/scripts_backup_$(date +%Y%m%d_%H%M%S)"
    fi
    cp -r "$SCRIPT_DIR/scripts" "$HOME/"
    success "Scripts installed to ~/scripts"
fi

# Set proper permissions
log "Setting proper permissions..."
if [[ "$DRY_RUN" == true ]]; then
    dry_run_msg "Would set executable permissions on shell scripts"
else
    chmod +x "$HOME/.config/waybar/mediaplayer.sh" 2>/dev/null || true
    find "$HOME/.config" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
    find "$HOME/scripts" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
fi

# Enable and start required services
log "Enabling required services..."
if [[ "$DRY_RUN" == true ]]; then
    dry_run_msg "Would enable pipewire, pipewire-pulse, wireplumber services"
else
    systemctl --user enable --now pipewire pipewire-pulse wireplumber 2>/dev/null || true
fi

# Set up environment variables
log "Setting up environment variables..."
ENV_FILE="$HOME/.profile"
if [[ "$DRY_RUN" == true ]]; then
    dry_run_msg "Would add Hyprland environment variables to ~/.profile"
else
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
fi

# Set up gtk themes (referenced in startup config)
log "Setting up GTK themes..."
if [[ "$DRY_RUN" == true ]]; then
    dry_run_msg "Would set GTK theme to Arc-Dark"
else
    gsettings set org.gnome.desktop.interface color-scheme "prefer-dark" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface gtk-theme "Arc-Dark" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface icon-theme "Arc" 2>/dev/null || true
fi

# ============================================
# Thunar Configuration
# ============================================
log "Configuring Thunar file manager..."
if [[ "$DRY_RUN" == true ]]; then
    dry_run_msg "Would set Thunar to Arc-Dark theme"
    dry_run_msg "Would set Thunar as default file manager"
else
    # Create Thunar config directory
    mkdir -p "$HOME/.config/Thunar"
    mkdir -p "$HOME/.config/xfce4/xfconf/xfce-perchannel-xml"
    
    # Set GTK3 theme to Arc-Dark
    mkdir -p "$HOME/.config/gtk-3.0"
    cat > "$HOME/.config/gtk-3.0/settings.ini" << 'EOF'
[Settings]
gtk-application-prefer-dark-theme=1
gtk-theme-name=Arc-Dark
gtk-icon-theme-name=Arc
gtk-font-name=Sans 10
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=24
gtk-toolbar-style=GTK_TOOLBAR_BOTH_HORIZ
gtk-toolbar-icon-size=GTK_ICON_SIZE_SMALL_TOOLBAR
gtk-button-images=0
gtk-menu-images=0
gtk-enable-event-sounds=0
gtk-enable-input-feedback-sounds=0
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=rgb
EOF
    
    # Set GTK4 theme to Arc-Dark
    mkdir -p "$HOME/.config/gtk-4.0"
    cat > "$HOME/.config/gtk-4.0/settings.ini" << 'EOF'
[Settings]
gtk-application-prefer-dark-theme=1
gtk-theme-name=Arc-Dark
gtk-icon-theme-name=Arc
gtk-font-name=Sans 10
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=24
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=rgb
EOF

    # Set GTK2 theme for older applications
    cat > "$HOME/.gtkrc-2.0" << 'EOF'
gtk-theme-name="Arc-Dark"
gtk-icon-theme-name="Arc"
gtk-font-name="Sans 10"
gtk-cursor-theme-name="Adwaita"
gtk-cursor-theme-size=24
gtk-toolbar-style=GTK_TOOLBAR_BOTH_HORIZ
gtk-toolbar-icon-size=GTK_ICON_SIZE_SMALL_TOOLBAR
gtk-button-images=0
gtk-menu-images=0
gtk-enable-event-sounds=0
gtk-enable-input-feedback-sounds=0
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle="hintslight"
gtk-xft-rgba="rgb"
EOF

    # Configure Xfce/Thunar settings via xfconf XML
    cat > "$HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="Arc-Dark"/>
    <property name="IconThemeName" type="string" value="Arc"/>
    <property name="EnableEventSounds" type="bool" value="false"/>
    <property name="EnableInputFeedbackSounds" type="bool" value="false"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="CursorThemeName" type="string" value="Adwaita"/>
    <property name="CursorThemeSize" type="int" value="24"/>
    <property name="FontName" type="string" value="Sans 10"/>
  </property>
  <property name="Xft" type="empty">
    <property name="Antialias" type="int" value="1"/>
    <property name="Hinting" type="int" value="1"/>
    <property name="HintStyle" type="string" value="hintslight"/>
    <property name="RGBA" type="string" value="rgb"/>
  </property>
</channel>
EOF

    # Set gsettings for GNOME/GTK applications (including Thunar)
    gsettings set org.gnome.desktop.interface gtk-theme "Arc-Dark" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface icon-theme "Arc" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface color-scheme "prefer-dark" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface cursor-theme "Adwaita" 2>/dev/null || true
    
    # Set Thunar as default file manager using xdg-mime
    xdg-mime default thunar.desktop inode/directory 2>/dev/null || true
    xdg-mime default thunar.desktop application/x-directory 2>/dev/null || true
    
    # Also set via environment for some DEs
    if [[ ! -f "$HOME/.config/mimeapps.list" ]]; then
        cat > "$HOME/.config/mimeapps.list" << 'EOF'
[Default Applications]
inode/directory=thunar.desktop
application/x-directory=thunar.desktop
EOF
    else
        # Add to existing mimeapps.list if not present
        if ! grep -q "inode/directory=thunar.desktop" "$HOME/.config/mimeapps.list"; then
            if grep -q "\[Default Applications\]" "$HOME/.config/mimeapps.list"; then
                sed -i '/\[Default Applications\]/a inode/directory=thunar.desktop' "$HOME/.config/mimeapps.list"
            else
                echo -e "\n[Default Applications]\ninode/directory=thunar.desktop" >> "$HOME/.config/mimeapps.list"
            fi
        fi
    fi
    
    success "Thunar configured with Arc-Dark theme and set as default file manager"
fi

# Install Neovim plugins (if lazy.nvim is used)
if [[ -f "$HOME/.config/nvim/init.lua" ]]; then
    log "Setting up Neovim..."
    if [[ "$DRY_RUN" == true ]]; then
        dry_run_msg "Would run nvim headlessly to install plugins"
    else
        nvim --headless +qall 2>/dev/null || true
    fi
fi

# Add scripts to PATH if not already there
log "Setting up scripts PATH..."
if [[ "$DRY_RUN" == true ]]; then
    dry_run_msg "Would add ~/scripts to PATH in .bashrc and .zshrc"
else
    if ! grep -q "$HOME/scripts" "$HOME/.bashrc" 2>/dev/null; then
        echo 'export PATH="$HOME/scripts:$PATH"' >> "$HOME/.bashrc"
    fi

    if [[ -f "$HOME/.zshrc" ]] && ! grep -q "$HOME/scripts" "$HOME/.zshrc" 2>/dev/null; then
        echo 'export PATH="$HOME/scripts:$PATH"' >> "$HOME/.zshrc"
    fi
fi

# ============================================
# Bash Terminal Configuration (Fastfetch + Powerline)
# ============================================
log "Configuring bash terminal (fastfetch + powerline)..."
if [[ "$DRY_RUN" == true ]]; then
    dry_run_msg "Would configure fastfetch to run on terminal startup"
    dry_run_msg "Would configure powerline for bash prompt"
else
    # Create powerline config directory
    mkdir -p "$HOME/.config/powerline"
    
    # Create powerline config for bash
    cat > "$HOME/.config/powerline/config.json" << 'EOF'
{
    "ext": {
        "shell": {
            "theme": "default_leftonly",
            "colorscheme": "default"
        }
    }
}
EOF

    # Add fastfetch and powerline to .bashrc if not already present
    if ! grep -q "# Powerline configuration" "$HOME/.bashrc" 2>/dev/null; then
        cat >> "$HOME/.bashrc" << 'EOF'

# ============================================
# Powerline configuration
# ============================================
if command -v powerline-daemon &> /dev/null; then
    powerline-daemon -q
    POWERLINE_BASH_CONTINUATION=1
    POWERLINE_BASH_SELECT=1
    if [[ -f /usr/share/powerline/bindings/bash/powerline.sh ]]; then
        source /usr/share/powerline/bindings/bash/powerline.sh
    fi
fi

# ============================================
# Fastfetch on terminal startup
# ============================================
if command -v fastfetch &> /dev/null; then
    # Only run in interactive shells and not in subshells/scripts
    if [[ $- == *i* ]] && [[ -z "$FASTFETCH_RAN" ]]; then
        export FASTFETCH_RAN=1
        fastfetch
    fi
fi
EOF
        success "Bash configured with powerline and fastfetch"
    else
        warning "Powerline configuration already exists in .bashrc"
    fi
fi

# Create Pictures/Screenshots directory (referenced in keybind)
run mkdir -p "$HOME/Pictures/Screenshots"

# Create a desktop entry for Hyprland if it doesn't exist
HYPR_DESKTOP="/usr/share/wayland-sessions/hyprland.desktop"
if [[ ! -f "$HYPR_DESKTOP" ]]; then
    log "Creating Hyprland desktop entry..."
    if [[ "$DRY_RUN" == true ]]; then
        dry_run_msg "Would create $HYPR_DESKTOP"
    else
        sudo tee "$HYPR_DESKTOP" > /dev/null << EOF
[Desktop Entry]
Name=Hyprland
Comment=An intelligent dynamic tiling Wayland compositor
Exec=Hyprland
Type=Application
EOF
    fi
fi

# Final setup instructions
echo
if [[ "$DRY_RUN" == true ]]; then
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}    DRY RUN COMPLETE${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo
    log "No changes were made. Run without --dry-run to install."
    echo
    log "Summary of what would be installed:"
    echo -e "  ${CYAN}•${NC} Hyprland window manager with all dependencies"
    echo -e "  ${CYAN}•${NC} Waybar, Wofi, Kitty, Thunar, Mako"
    echo -e "  ${CYAN}•${NC} Audio system (PipeWire + EasyEffects)"
    echo -e "  ${CYAN}•${NC} Screenshot tools (Grim + Slurp + Satty)"
    echo -e "  ${CYAN}•${NC} Clipboard manager (Clipse)"
    echo -e "  ${CYAN}•${NC} Audio visualizer (Cava)"
    echo -e "  ${CYAN}•${NC} Thunar configured with Arc-Dark theme + set as default"
    echo -e "  ${CYAN}•${NC} Bash terminal with Powerline prompt + Fastfetch on startup"
    echo -e "  ${CYAN}•${NC} DaVinci Resolve dependencies + GPU drivers ${YELLOW}(optional)${NC}"
    echo -e "  ${CYAN}•${NC} Fonts and themes"
    echo -e "  ${CYAN}•${NC} Applications (Steam, Spotify, Discord, etc.)"
    echo -e "  ${CYAN}•${NC} All configuration files from ./config"
    echo -e "  ${CYAN}•${NC} Scripts folder to ~/scripts"
else
    success "Installation completed successfully!"
    echo
    log "Setup complete! Here's what was installed:"
    echo -e "  ${GREEN}✓${NC} Hyprland window manager with all dependencies"
    echo -e "  ${GREEN}✓${NC} Waybar status bar with custom configuration"
    echo -e "  ${GREEN}✓${NC} Kitty terminal with custom theme"
    echo -e "  ${GREEN}✓${NC} Wofi application launcher"
    echo -e "  ${GREEN}✓${NC} Mako notification daemon"
    echo -e "  ${GREEN}✓${NC} Thunar file manager (Arc-Dark theme, set as default)"
    if [[ "$INSTALL_DAVINCI" == true ]]; then
        echo -e "  ${GREEN}✓${NC} DaVinci Resolve dependencies installed"
    fi
    echo -e "  ${GREEN}✓${NC} All configuration files"
    echo -e "  ${GREEN}✓${NC} Audio system (PipeWire + EasyEffects)"
    echo -e "  ${GREEN}✓${NC} Screenshot tools (Grim + Slurp + Satty)"
    echo -e "  ${GREEN}✓${NC} Clipboard manager (Clipse)"
    echo -e "  ${GREEN}✓${NC} Audio visualizer (Cava)"
    echo -e "  ${GREEN}✓${NC} Bash terminal (Powerline prompt + Fastfetch on startup)"
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
    echo "  Super + E           : Open browser (chromium)"
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
    if [[ "$INSTALL_DAVINCI" == true ]]; then
        log "To install DaVinci Resolve, run: ~/install-davinci-resolve.sh"
        log "  (or use: $AUR_HELPER -S davinci-resolve)"
        echo
    fi

    success "Enjoy your new Hyprland setup! 🚀"
fi
