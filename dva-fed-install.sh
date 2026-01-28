#!/bin/bash

# VXA Dotfiles Installation Script for Fedora
# Installs Hyprland and all required packages, then copies configs
#
# Usage:
#   ./fed-install.sh           # Normal installation
#   ./fed-install.sh --dry-run # Preview what would be installed
#   ./fed-install.sh -n        # Same as --dry-run

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

# DNF install wrapper with dry-run support
dnf_install() {
    if [[ "$DRY_RUN" == true ]]; then
        dry_run_msg "Would install (dnf): $*"
    else
        sudo dnf install -y "$@"
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

# Check if running on Fedora
if ! grep -q "Fedora" /etc/os-release; then
    error "This script is designed for Fedora"
fi

if [[ "$DRY_RUN" == true ]]; then
    echo
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}    DRY RUN MODE - No changes will be made${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo
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
run_sudo dnf update -y
run_sudo dnf install -y dnf-plugins-core

# Enable RPM Fusion repositories (needed for some packages)
log "Enabling RPM Fusion repositories..."
if [[ "$DRY_RUN" == true ]]; then
    dry_run_msg "Would enable RPM Fusion free and nonfree repositories"
else
    sudo dnf install -y \
        https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
        https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm \
        || warning "RPM Fusion may already be installed"
fi

# Check if Hyprland is available, suggest Copr if not
log "Checking Hyprland availability..."
if ! dnf list available hyprland &>/dev/null; then
    warning "Hyprland not found in enabled repositories"
    if [[ "$DRY_RUN" == true ]]; then
        dry_run_msg "Would prompt to enable Copr repository for Hyprland"
    else
        read -p "$(echo -e "${YELLOW}Enable Copr repository for Hyprland? [Y/n]:${NC} ")" -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            log "Enabling Hyprland Copr repository..."
            sudo dnf copr enable -y solopasha/hyprland || warning "Failed to enable Copr repo"
        fi
    fi
fi

# Enable Copr repo for clipse
log "Enabling Copr repository for clipse..."
run_sudo dnf copr enable -y azandure/clipse || warning "Failed to enable clipse Copr repo"

# Install core dependencies first
log "Installing core system dependencies..."
dnf_install \
    xdg-desktop-portal-gtk \
    qt6ct \
    qt5ct

# Try to install polkit agents (package names vary)
log "Installing polkit authentication agents..."
dnf_install polkit || warning "polkit not available"
for pkg in polkit-gnome polkit-kde lxqt-policykit; do
    dnf_install "$pkg" || warning "$pkg not available"
done

# Try to install Hyprland ecosystem (may not be fully available in all repos)
log "Attempting to install Hyprland ecosystem..."
if [[ "$DRY_RUN" == true ]]; then
    dry_run_msg "Would install: hyprland"
else
    sudo dnf install -y hyprland || {
        warning "Hyprland not available in official repos. You may need to:"
        warning "1. Enable Copr repo: sudo dnf copr enable solopasha/hyprland"
        warning "2. Or compile from source"
        error "Cannot continue without Hyprland"
    }
fi

# Try to install additional hypr tools
log "Installing additional Hyprland tools..."
dnf_install xdg-desktop-portal-hyprland || warning "xdg-desktop-portal-hyprland not available"

# These might not be packaged for Fedora yet
log "Attempting to install additional Hyprland components..."
for pkg in hyprlock hyprpaper; do
    dnf_install "$pkg" || warning "$pkg not available (may need manual installation)"
done

# Install window manager and desktop essentials
log "Installing window manager essentials..."
dnf_install \
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
dnf_install \
    pipewire \
    pipewire-alsa \
    pipewire-pulse \
    pipewire-jack-audio-connection-kit \
    wireplumber \
    easyeffects

# Install development and system tools
log "Installing development and system tools..."
dnf_install \
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
dnf_install cava

# Try to install satty, fallback to manual installation if needed
log "Installing satty screenshot editor..."
if [[ "$DRY_RUN" == true ]]; then
    dry_run_msg "Would install satty (dnf or cargo fallback)"
else
    if ! sudo dnf install -y satty; then
        warning "satty not available in repositories, trying manual installation..."
        if command -v cargo &> /dev/null; then
            log "Installing satty via cargo..."
            cargo install satty
        else
            warning "satty installation failed - install cargo or compile manually"
        fi
    fi
fi

# Install clipboard manager
log "Installing clipse clipboard manager..."
dnf_install clipse || warning "clipse installation failed - check if azandure/clipse copr is enabled"

# Install fonts
log "Installing fonts..."
dnf_install \
    'jetbrains-mono-fonts*' \
    'google-noto-fonts*' \
    fontawesome-fonts \
    liberation-fonts \
    google-roboto-fonts

# Install themes and appearance tools
log "Installing themes and appearance..."
dnf_install \
    gtk3 \
    gtk4 \
    adwaita-gtk2-theme \
    papirus-icon-theme \
    numix-icon-theme

# Install flatpak and add Flathub
log "Setting up Flatpak..."
dnf_install flatpak
if [[ "$DRY_RUN" == true ]]; then
    dry_run_msg "Would add Flathub repository"
else
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
fi

# Install applications referenced in startup config
log "Installing applications from startup config..."

# Steam (gaming) - try RPM Fusion first, fallback to Flatpak
log "Installing Steam..."
if [[ "$DRY_RUN" == true ]]; then
    dry_run_msg "Would install Steam (dnf or flatpak fallback)"
else
    if ! sudo dnf install -y steam; then
        log "Steam not available via DNF, installing via Flatpak..."
        flatpak install -y flathub com.valvesoftware.Steam || warning "Steam installation failed"
    fi
fi

# Spotify (music)
flatpak_install flathub com.spotify.Client || warning "Spotify flatpak install failed"

# Discord
flatpak_install flathub com.discordapp.Discord || warning "Discord flatpak install failed"

# Zen Browser (if available) - fallback to firefox
log "Attempting to install Zen Browser..."
if [[ "$DRY_RUN" == true ]]; then
    dry_run_msg "Would install Zen Browser or Firefox fallback"
else
    if ! sudo dnf install -y zen-browser 2>/dev/null; then
        log "Zen Browser not available in repos, installing Firefox as fallback..."
        sudo dnf install -y firefox
    fi
fi

# CoreCtrl for GPU management
dnf_install corectrl || warning "CoreCtrl not available in repos"

# OpenRGB for RGB control
if [[ "$DRY_RUN" == true ]]; then
    dry_run_msg "Would install OpenRGB (flatpak or dnf fallback)"
else
    flatpak install -y flathub org.openrgb.OpenRGB || {
        # Try from repos if flatpak fails
        sudo dnf install -y openrgb || warning "OpenRGB installation failed"
    }
fi

# Sunshine game streaming
dnf_install sunshine || warning "Sunshine not available in repos"

# Vorta backup
flatpak_install flathub com.borgbase.Vorta || warning "Vorta flatpak install failed"

# ============================================
# DaVinci Resolve Installation (Optional)
# ============================================
INSTALL_DAVINCI=false

if [[ "$DRY_RUN" == true ]]; then
    dry_run_msg "Would prompt to install DaVinci Resolve dependencies"
    dry_run_msg "If accepted, would install:"
    dry_run_msg "  - libxcrypt-compat, libcurl, libcurl-devel, mesa-libGLU"
    dry_run_msg "  - apr, apr-util, mesa-libOpenCL"
    dry_run_msg "  - NVIDIA: akmod-nvidia, xorg-x11-drv-nvidia-cuda (if NVIDIA GPU detected)"
    dry_run_msg "  - AMD: rocm-opencl (if AMD GPU detected)"
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
    sudo dnf install -y \
        libxcrypt-compat \
        libcurl \
        libcurl-devel \
        mesa-libGLU \
        apr \
        apr-util \
        mesa-libOpenCL \
        alsa-lib \
        alsa-plugins-pulseaudio \
        libXcomposite \
        libXcursor \
        libXi \
        libXinerama \
        libXrandr \
        libXrender \
        libXtst \
        libXScrnSaver \
        libxkbcommon \
        libxkbcommon-x11 \
        nspr \
        nss \
        nss-util \
        fuse-libs \
        || warning "Some DaVinci Resolve dependencies failed to install"
    
    # Detect GPU type and install appropriate drivers/OpenCL
    log "Detecting GPU for DaVinci Resolve..."
    
    if lspci | grep -i nvidia &>/dev/null; then
        log "NVIDIA GPU detected - installing NVIDIA drivers and CUDA support..."
        
        # Enable third-party repos if not already (needed for akmod-nvidia)
        sudo dnf install -y fedora-workstation-repositories 2>/dev/null || true
        
        # Install NVIDIA drivers
        sudo dnf install -y akmod-nvidia || warning "akmod-nvidia installation failed"
        
        # Install CUDA/OpenCL support for NVIDIA
        sudo dnf install -y \
            xorg-x11-drv-nvidia-cuda \
            xorg-x11-drv-nvidia-cuda-libs \
            nvidia-vaapi-driver \
            || warning "NVIDIA CUDA packages installation failed"
        
        success "NVIDIA drivers installed - REBOOT REQUIRED before using DaVinci Resolve"
        
    elif lspci | grep -i "amd\|radeon" &>/dev/null; then
        log "AMD GPU detected - installing ROCm OpenCL support..."
        
        # AMD ROCm for OpenCL support
        sudo dnf install -y \
            rocm-opencl \
            rocm-clinfo \
            || warning "ROCm OpenCL installation failed - DaVinci Resolve may not work optimally with AMD"
        
        warning "AMD GPU support in DaVinci Resolve is limited - NVIDIA recommended"
        
    elif lspci | grep -i "intel.*graphics" &>/dev/null; then
        log "Intel GPU detected - installing Intel OpenCL support..."
        sudo dnf install -y \
            intel-compute-runtime \
            intel-opencl \
            || warning "Intel OpenCL installation failed"
        
        warning "Intel GPU support in DaVinci Resolve is very limited - NVIDIA recommended"
    fi
    
    # Multimedia codecs (useful for video editing)
    log "Installing multimedia codecs for video editing..."
    sudo dnf groupupdate -y multimedia --setop="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin 2>/dev/null || true
    sudo dnf install -y ffmpeg ffmpeg-libs || warning "FFmpeg installation failed"
    
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
# DaVinci Resolve Installation Helper Script
# Run this after downloading DaVinci Resolve from Blackmagic's website

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== DaVinci Resolve Installation Helper ===${NC}"
echo

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
echo
echo -e "${YELLOW}Note: If you have an NVIDIA GPU, make sure to reboot first!${NC}"
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
        
        # Install via DNF
        sudo dnf install -y \
            gimp \
            vlc \
            libreoffice \
            thunderbird \
            transmission-gtk \
            obs-studio \
            blender
        
        # Install VS Code - add Microsoft repo and install
        log "Installing Visual Studio Code..."
        sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
        sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
        sudo dnf install -y code || warning "VS Code installation failed"
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
    dry_run_msg "Would set GTK theme to Adwaita-dark"
else
    gsettings set org.gnome.desktop.interface color-scheme "prefer-dark" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark" 2>/dev/null || true
fi

# ============================================
# Thunar Configuration
# ============================================
log "Configuring Thunar file manager..."
if [[ "$DRY_RUN" == true ]]; then
    dry_run_msg "Would set Thunar to dark theme"
    dry_run_msg "Would set Thunar as default file manager"
else
    # Create Thunar config directory
    mkdir -p "$HOME/.config/Thunar"
    mkdir -p "$HOME/.config/xfce4/xfconf/xfce-perchannel-xml"
    
    # Set Thunar to use dark theme via GTK settings
    mkdir -p "$HOME/.config/gtk-3.0"
    if [[ ! -f "$HOME/.config/gtk-3.0/settings.ini" ]]; then
        cat > "$HOME/.config/gtk-3.0/settings.ini" << 'EOF'
[Settings]
gtk-application-prefer-dark-theme=1
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Papirus-Dark
EOF
    else
        # Update existing settings.ini to prefer dark theme
        if ! grep -q "gtk-application-prefer-dark-theme" "$HOME/.config/gtk-3.0/settings.ini"; then
            echo "gtk-application-prefer-dark-theme=1" >> "$HOME/.config/gtk-3.0/settings.ini"
        fi
    fi
    
    # GTK4 dark theme
    mkdir -p "$HOME/.config/gtk-4.0"
    if [[ ! -f "$HOME/.config/gtk-4.0/settings.ini" ]]; then
        cat > "$HOME/.config/gtk-4.0/settings.ini" << 'EOF'
[Settings]
gtk-application-prefer-dark-theme=1
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Papirus-Dark
EOF
    fi
    
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
    
    success "Thunar configured with dark theme and set as default file manager"
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
    echo -e "  ${CYAN}•${NC} Thunar configured with dark theme + set as default"
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
    echo -e "  ${GREEN}✓${NC} Thunar file manager (dark theme, set as default)"
    if [[ "$INSTALL_DAVINCI" == true ]]; then
        echo -e "  ${GREEN}✓${NC} DaVinci Resolve dependencies installed"
    fi
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
    if [[ "$INSTALL_DAVINCI" == true ]]; then
        if lspci | grep -i nvidia &>/dev/null; then
            warning "NVIDIA GPU detected - REBOOT REQUIRED before using DaVinci Resolve!"
        fi
        log "To install DaVinci Resolve, run: ~/install-davinci-resolve.sh"
        log "  (after downloading from blackmagicdesign.com)"
        echo
    fi

    success "Enjoy your new Hyprland setup! 🚀"
fi
