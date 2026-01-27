#!/bin/bash

GAME_ID="3062380"

#find winetricks

install_tools() {
    echo "Checking for required tools..."

    if ! flatpak list | grep -q "protontricks"; then
        echo "Protontricks is not installed. Installing it now..."
        flatpak install -y flathub com.github.Matoking.protontricks
        if [ $? -ne 0 ]; then
            echo "Failed to install Protontricks. Exiting."
            exit 1
        fi
    else
        echo "Protontricks is already installed."
    fi

    if ! command -v winetricks &>/dev/null; then
        echo "Winetricks is not installed. Installing it now..."
        mkdir -p ~/.local/bin
        curl -o ~/.local/bin/winetricks https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks
        chmod +x ~/.local/bin/winetricks

        if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
            echo "Adding ~/.local/bin to PATH."
            export PATH="$HOME/.local/bin:$PATH"
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
        fi

        if ! command -v winetricks &>/dev/null; then
            echo "Failed to install Winetricks. Exiting."
            exit 1
        fi
    else
        echo "Winetricks is already installed."
    fi
}

#find mash/bmx2
find_mashbox_directory() {
    echo "Locating Mashbox installation directory..."
    STEAM_DIR="$HOME/.steam/steam"

    # Look for Mashbox in the default Steam library
    GAME_PATH="$STEAM_DIR/steamapps/common/Mashbox"

    if [ ! -d "$GAME_PATH" ]; then
        echo "Mashbox installation not found in the default Steam library."
        GAME_PATH=$(zenity --file-selection --directory --title="Select Mashbox Installation Directory")
        if [ ! -d "$GAME_PATH" ]; then
            echo "Invalid directory specified or selection canceled. Exiting."
            exit 1
        fi
    else
        echo "Mashbox found at: $GAME_PATH"
    fi

    echo "$GAME_PATH"
}

# Function to find the Proton Wine prefix based on the game folder
find_wine_prefix() {
    GAME_PATH="$1"

    # Step back from the game's location to derive the prefix path
    PREFIX_BASE=$(dirname "$(dirname "$GAME_PATH")")
    WINE_PREFIX="$PREFIX_BASE/compatdata/$GAME_ID/pfx"

    echo "Checking if the Proton Wine prefix exists at: $WINE_PREFIX"

    if [ ! -d "$WINE_PREFIX" ]; then
        echo "Unable to locate Proton Wine prefix. Ensure the game is installed via Steam and Proton is enabled."
        exit 1
    fi

    echo "Proton Wine prefix located at: $WINE_PREFIX"
    echo "$WINE_PREFIX"
}

# Function to install MelonLoader and prerequisites
install_melonloader() {
    WINE_PREFIX="$1"
    echo "Installing .NET 6 and Visual C++ 2019 prerequisites..."
    flatpak run com.github.Matoking.protontricks "$WINE_PREFIX" -q dotnet6 vcrun2019
    if [ $? -ne 0 ]; then
        echo "Failed to install prerequisites. Exiting."
        exit 1
    fi

    echo "Downloading and installing MelonLoader..."
    TEMP_DIR=$(mktemp -d)
    ML_INSTALLER_URL="https://github.com/LavaGang/MelonLoader/releases/latest/download/MelonLoader.Installer.exe"
    wget -O "$TEMP_DIR/MelonLoader.Installer.exe" "$ML_INSTALLER_URL"

    flatpak run com.github.Matoking.protontricks "$WINE_PREFIX" -q run -- "$TEMP_DIR/MelonLoader.Installer.exe"
    if [ $? -ne 0 ]; then
        echo "Failed to install MelonLoader. Exiting."
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    rm -rf "$TEMP_DIR"
    echo "MelonLoader installation complete."
}

# Function to configure Wine library overrides
configure_wine() {
    WINE_PREFIX="$1"
    echo "Configuring Wine library overrides..."

    # Run winecfg
    flatpak run com.github.Matoking.protontricks "$WINE_PREFIX" -q run winecfg
    if [ $? -ne 0 ]; then
        echo "Failed to run winecfg. Exiting."
        exit 1
    fi

    # Add library override using winetricks
    winetricks -q --prefix="$WINE_PREFIX" dlls override-version
    if [ $? -ne 0 ]; then
        echo "Failed to configure library overrides with winetricks. Exiting."
        exit 1
    fi

    echo "Library override 'version' added successfully."
}

# Main script logic
install_tools
GAME_PATH=$(find_mashbox_directory)
WINE_PREFIX=$(find_wine_prefix "$GAME_PATH")
install_melonloader "$WINE_PREFIX"
configure_wine "$WINE_PREFIX"

echo "Setup complete!"

