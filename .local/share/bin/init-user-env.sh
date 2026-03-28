#!/usr/bin/env bash

set -uex

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- User directory setup (cross-platform) ---
mkdir -p \
    "${HOME}/.ssh" \
    "${HOME}/.local/bin" \
    "${HOME}/.local/share/fonts/fonts" \
    "${HOME}/.config" \
    "${HOME}/.config/autostart" \
    "${HOME}/.cache" \
    "${HOME}/venv"

chmod 700 "${HOME}/.ssh"
chmod 700 "${HOME}/.cache"
chmod 700 "${HOME}/.local"

# Linux-specific, non-container setup
if [[ "$(uname)" == "Linux" ]] && ! test -f /.dockerenv; then
    mkdir -p \
        "${HOME}/.config/systemd/user" \
        "${HOME}/.config/docker-user"
    chmod 700 "${HOME}/.config/docker-user"

    # Enable user lingering for systemd user services to persist after logout
    if command -v loginctl &>/dev/null; then
        loginctl enable-linger "$(id -un)" 2>/dev/null || true
    fi

    # Enable podman user socket if available
    if command -v podman &>/dev/null && command -v systemctl &>/dev/null; then
        systemctl --user enable --now podman.socket 2>/dev/null || true
    fi

    # Install nvidia-ctk user service if nvidia-ctk is available
    if command -v nvidia-ctk &>/dev/null; then
        cp "${SCRIPT_DIR}/../../../.config/systemd/user/nvidia-ctk-docker-config.service" \
            "${HOME}/.config/systemd/user/nvidia-ctk-docker-config.service" 2>/dev/null || true
        systemctl --user daemon-reload 2>/dev/null || true
        systemctl --user enable --now nvidia-ctk-docker-config.service 2>/dev/null || true
    fi
fi

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

if [[ ! -v GITHUB_ACTIONS ]] && test -f /.dockerenv; then
  exit 0
fi

which flatpak && flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

if which flatpak && which dpkg && dpkg -l | grep ubuntu-desktop
then
    flatpak install -y --user flathub org.telegram.desktop || true
    flatpak override --user org.telegram.desktop --filesystem="${HOME}/Pictures"
    flatpak override --user org.telegram.desktop --filesystem="${HOME}/Downloads"

    flatpak install -y --user org.chromium.Chromium
    flatpak install -y --user org.gnome.Evince
    flatpak install -y --user org.keepassxc.KeePassXC
    flatpak install -y --user com.parsecgaming.parsec
    flatpak install -y --user flathub org.libreoffice.LibreOffice
    flatpak install -y --user flathub org.wezfurlong.wezterm
    flatpak install --user flathub com.logseq.Logseq
fi

"${SCRIPT_DIR}/init-nix.sh"

# Install pre-commit hooks if in the dotfiles repo
DOTFILES_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
if [[ -f "${DOTFILES_DIR}/.pre-commit-config.yaml" ]] && command -v pre-commit &>/dev/null; then
  bash -c "cd ${DOTFILES_DIR} && pre-commit install"
fi

if [ "$(uname -m)" = "x86_64" ]; then
    # Not all plugins are available on aarch64 and kubectl is not really needed there now
    # shellcheck disable=SC2016
    nix-shell -p krew git cacert --command 'export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH" && krew update && krew install fuzzy get-all grep ktop neat stern tail tree access-matrix oidc-login' --pure
fi

if [[ ! -v GITHUB_ACTIONS ]]; then
    # Requires bubblewrap which doesn't work in GitHub Actions
    nix-shell -p arduino-cli bubblewrap --command "arduino-cli core install arduino:avr" --pure
fi

NERDFONTS_PATH=${HOME}/.local/share/fonts/fonts/nerdfonts/
mkdir -p "${NERDFONTS_PATH}"
nix-shell --pure -p nix nerd-fonts.jetbrains-mono --run "cp --no-preserve=mode -R $(nix-instantiate --eval --expr 'with import <nixpkgs> {}; pkgs.nerd-fonts.jetbrains-mono.outPath')/share/fonts/truetype/NerdFonts/* ${NERDFONTS_PATH}"
nix-shell --pure -p fontconfig --run "fc-cache -fv"
