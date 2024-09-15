#!/usr/bin/env bash

set -uex

declare -A repos=(
  ["plugins/zsh-autosuggestions"]="https://github.com/zsh-users/zsh-autosuggestions"
  ["plugins/zsh-syntax-highlighting"]="https://github.com/zsh-users/zsh-syntax-highlighting.git"
  ["themes/powerlevel10k"]="https://github.com/romkatv/powerlevel10k.git"
  ["plugins/zsh-vi-mode"]="https://github.com/jeffreytse/zsh-vi-mode"
  ["plugins/forgit"]="https://github.com/wfxr/forgit.git"
  ["plugins/you-should-use"]="https://github.com/MichaelAquilina/zsh-you-should-use.git"
  ["plugins/fzf-tab"]="https://github.com/Aloxaf/fzf-tab"
)

# Iterate over the array and clone repositories if not already present
for path in "${!repos[@]}"; do
  target_dir="${ZSH_CUSTOM:-$HOME/.local/share/oh-my-zsh/custom}/$path"
  repo_url="${repos[$path]}"

  if [[ ! -d "$target_dir" ]]; then
    parent_dir=$(dirname "$target_dir")
    mkdir -p "$parent_dir"

    # Use --depth=1 only for powerlevel10k
    if [[ "$path" == "themes/powerlevel10k" ]]; then
      git clone --depth=1 "$repo_url" "$target_dir"
    else
      git clone "$repo_url" "$target_dir"
    fi
  fi
done

# Install sway flatpak
LATEST_RELEASE=$(curl -L -s -H 'Accept: application/json' https://github.com/fspv/flatpaks/releases/latest)
# shellcheck disable=SC2001
LATEST_VERSION=$(echo "$LATEST_RELEASE" | sed -e 's/.*"tag_name":"\([^"]*\)".*/\1/')
ARTIFACT_URL="https://github.com/fspv/flatpaks/releases/download/$LATEST_VERSION/sway.flatpak"
TMP_DIR=$(mktemp -d)
wget "$ARTIFACT_URL" -O "$TMP_DIR/sway.flatpak"
flatpak install -y --noninteractive --user "$TMP_DIR/sway.flatpak" || true
rm -rf "$TMP_DIR"

# Install telegram
flatpak install -y --user flathub org.telegram.desktop || true
flatpak override --user org.telegram.desktop --filesystem="${HOME}/Pictures"
flatpak override --user org.telegram.desktop --filesystem="${HOME}/Downloads"

flatpak install -y --user org.chromium.Chromium
flatpak install -y --user org.gnome.Evince
flatpak install -y --user org.keepassxc.KeePassXC
flatpak install -y --user com.parsecgaming.parsec

nix-channel --add https://nixos.org/channels/nixos-24.05 nixpkgs
nix-channel --update

nix-shell -p krew git cacert --command "krew update && krew install fuzzy get-all grep ktop neat stern tail tree access-matrix" --pure

nix-shell -p arduino-cli --command "arduino-cli core install arduino:avr" --pure

