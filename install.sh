#!/usr/bin/env bash
set -e

# Check if the script is run as a superuser
if [[ $EUID -ne 0 ]]; then
   echo "⚠️ This script must be run as root (sudo ./install.sh)"
   exit 1
fi

echo "🚀 Fedora Post-Installation Script"

USER_NAME=$(logname)
USER_HOME=/home/$(logname)
SCRIPT_PATH=$(dirname "$(realpath "$0")")

# Clean cache
dnf clean all

# Disable automatic suspension
sudo -u "$USER_NAME" XDG_RUNTIME_DIR="/run/user/$(id -u "$USER_NAME")" gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
sudo -u "$USER_NAME" XDG_RUNTIME_DIR="/run/user/$(id -u "$USER_NAME")" gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing'
sudo -u "$USER_NAME" XDG_RUNTIME_DIR="/run/user/$(id -u "$USER_NAME")" gsettings set org.gnome.desktop.session idle-delay 0

# Enable RPM Fusion Repositories
dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
dnf install -y https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

# Allow 10 parallel downloads in dnf
grep -q '^max_parallel_downloads=' /etc/dnf/dnf.conf || echo 'max_parallel_downloads=10' >> /etc/dnf/dnf.conf

# Decrease boot time
systemctl disable NetworkManager-wait-online.service

# Add Flathub Repository
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Install graphic drivers
echo "🎮 Please select which graphics drivers you want to install:"
echo "1. NVIDIA drivers"
echo "2. AMD drivers (open source)"
echo "3. Intel drivers (open source)"
echo "4. No additional drivers"

read -p "Please type in a number (1-4): " gpu_choice

case $gpu_choice in
  1)
    echo "💻 Installing Nvidia drivers..."
    dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda
    ;;
  2)
    echo "💻 Using built-in AMD drivers."
    ;;
  3)
    echo "💻 Using built-in Intel drivers."
    ;;
  *)
    echo "✅ No additional drivers were installed."
    ;;
esac

# Update Flatpak and dnf packages
dnf upgrade -y
flatpak update -y

# Update firmware
fwupdmgr refresh --force
fwupdmgr update

# Install dnf and flatpak packages
dnf install -y --allowerasing $(cat $SCRIPT_PATH/dnf.txt)
flatpak install -y $(cat $SCRIPT_PATH/flatpak.txt)

# Set zsh as your default shell
grep -q $(which zsh) /etc/shells || echo $(which zsh) | tee -a /etc/shells > /dev/null && usermod --shell $(which zsh) "$USER_NAME"

# Install OhMyZsh
if [ ! -d "$USER_HOME/.oh-my-zsh" ]; then
  sudo -u "$USER_NAME" sh -c "RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""
fi

# Install starship
dnf copr enable -y atim/starship
dnf install -y starship
grep -qxF 'eval "$(starship init zsh)"' $USER_HOME/.zshrc || echo 'eval "$(starship init zsh)"' >> $USER_HOME/.zshrc

if [ ! -f "$USER_HOME/.config/starship.toml" ]; then
  sudo -u "$USER_NAME" mkdir -p "$USER_HOME/.config"
  sudo -u "$USER_NAME" touch "$USER_HOME/.config/starship.toml"
fi

# Install Catppuccin-powerline (for starship)
grep -qxF 'preset = "catppuccin-powerline"' $USER_HOME/.config/starship.toml || sudo -u "$USER_NAME" starship preset catppuccin-powerline -o $USER_HOME/.config/starship.toml

# Apply kitty configuration
sudo -u "$USER_NAME" cp -r $SCRIPT_PATH/kitty/ $USER_HOME/.config/

# Add Kitty to autostart
if [ ! -f $USER_HOME/.config/autostart/kitty.desktop ]; then
    mkdir -p $USER_HOME/.config/autostart
    cat <<EOF > $USER_HOME/.config/autostart/kitty.desktop
[Desktop Entry]
Type=Application
Exec=kitty --start-as maximized
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Kitty
EOF
fi

# Apply Mandelbrot wallpaper
WALLPAPER_URL="https://github.com/zhichaoh/catppuccin-wallpapers/blob/main/mandelbrot/mandelbrot_full_blue.png?raw=true"
WALLPAPER_PATH="$USER_HOME/Pictures/Wallpapers/catppuccin-mandelbrot-blue.png"
mkdir -p "$(dirname "$WALLPAPER_PATH")"
if [ ! -f "$WALLPAPER_PATH" ]; then
  curl -L "$WALLPAPER_URL" -o "$WALLPAPER_PATH"
fi
sudo -u "$USER_NAME" XDG_RUNTIME_DIR="/run/user/$(id -u "$USER_NAME")" gsettings set org.gnome.desktop.background picture-uri "file://$WALLPAPER_PATH"
sudo -u "$USER_NAME" XDG_RUNTIME_DIR="/run/user/$(id -u	"$USER_NAME")" gsettings set org.gnome.desktop.background picture-uri-dark "file://$WALLPAPER_PATH"

# Apply Appearance settings
sudo -u "$USER_NAME" XDG_RUNTIME_DIR="/run/user/$(id -u	"$USER_NAME")" gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
sudo -u "$USER_NAME" XDG_RUNTIME_DIR="/run/user/$(id -u	"$USER_NAME")" gsettings set org.gnome.desktop.interface accent-color 'blue'

# Apply Multitasking settings
sudo -u "$USER_NAME" XDG_RUNTIME_DIR="/run/user/$(id -u	"$USER_NAME")" gsettings set org.gnome.desktop.interface enable-hot-corners false
sudo -u "$USER_NAME" XDG_RUNTIME_DIR="/run/user/$(id -u	"$USER_NAME")" gsettings set org.gnome.mutter dynamic-workspaces false
sudo -u "$USER_NAME" XDG_RUNTIME_DIR="/run/user/$(id -u	"$USER_NAME")" gsettings set org.gnome.desktop.wm.preferences num-workspaces 4

# Apply Power settings
sudo -u "$USER_NAME" XDG_RUNTIME_DIR="/run/user/$(id -u	"$USER_NAME")" gsettings set org.gnome.desktop.interface show-battery-percentage true

# Apply Keybindings
SCHEMA="org.gnome.settings-daemon.plugins.media-keys"
BASE="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings"
CUSTOM0="$BASE/custom0/"
CUSTOM1="$BASE/custom1/"

sudo -u "$USER_NAME" XDG_RUNTIME_DIR="/run/user/$(id -u	"$USER_NAME")" gsettings set $SCHEMA custom-keybindings "['$CUSTOM0', '$CUSTOM1']"

sudo -u "$USER_NAME" XDG_RUNTIME_DIR="/run/user/$(id -u	"$USER_NAME")" gsettings set $SCHEMA.custom-keybinding:$CUSTOM0 name 'Terminal'
sudo -u "$USER_NAME" XDG_RUNTIME_DIR="/run/user/$(id -u	"$USER_NAME")" gsettings set $SCHEMA.custom-keybinding:$CUSTOM0 command 'kitty --start-as maximized'
sudo -u "$USER_NAME" XDG_RUNTIME_DIR="/run/user/$(id -u	"$USER_NAME")" gsettings set $SCHEMA.custom-keybinding:$CUSTOM0 binding '<Primary><Alt>t'

sudo -u "$USER_NAME" XDG_RUNTIME_DIR="/run/user/$(id -u	"$USER_NAME")" gsettings set $SCHEMA.custom-keybinding:$CUSTOM1 name 'Browser'
sudo -u "$USER_NAME" XDG_RUNTIME_DIR="/run/user/$(id -u	"$USER_NAME")" gsettings set $SCHEMA.custom-keybinding:$CUSTOM1 command 'chromium-browser'
sudo -u "$USER_NAME" XDG_RUNTIME_DIR="/run/user/$(id -u	"$USER_NAME")" gsettings set $SCHEMA.custom-keybinding:$CUSTOM1 binding '<Primary><Alt>b'

WM_SCHEMA="org.gnome.desktop.wm.keybindings"
for i in {1..4}; do
  sudo -u "$USER_NAME" XDG_RUNTIME_DIR="/run/user/$(id -u	"$USER_NAME")" gsettings set $WM_SCHEMA switch-to-workspace-$i "['<Super>$i']"
  sudo -u "$USER_NAME" XDG_RUNTIME_DIR="/run/user/$(id -u	"$USER_NAME")" gsettings set $WM_SCHEMA move-to-workspace-$i "['<Super><Shift>$i']"
done

for i in {1..9}; do
  sudo -u "$USER_NAME" XDG_RUNTIME_DIR="/run/user/$(id -u	"$USER_NAME")" gsettings set org.gnome.shell.keybindings switch-to-application-$i "[]"
done

echo -e "\n\n\n"
echo "✅ Script finished! Reboot recommended."
echo "⚠️ Note: if you installed additional graphics drivers, please wait for ~5 minutes for the kernel modules to be built.\n"
echo "✨ Optionally:"
echo "Install my clean, modular Neovim Config: https://github.com/MalteHansenOfficial/.config"
echo "Install Space Bar: https://extensions.gnome.org/extension/5090/space-bar/"
echo "Install Clipboard Indicator: https://extensions.gnome.org/extension/779/clipboard-indicator/"
echo "Install Color Picker: https://extensions.gnome.org/extension/3396/color-picker/"
echo "Install Vitals: https://extensions.gnome.org/extension/1460/vitals/"
