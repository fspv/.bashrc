#!/usr/bin/env bash

set -uex

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "${HOME}/.ssh"
mkdir -p "${HOME}/.local/bin"
mkdir -p "${HOME}/.local/share/fonts/fonts"
mkdir -p "${HOME}/.config"
mkdir -p "${HOME}/.config/autostart"
mkdir -p "${HOME}/.cache"
mkdir -p "${HOME}/venv"

chmod 700 "${HOME}/.ssh"
chmod 700 "${HOME}/.cache"
chmod 700 "${HOME}/.local"

if [[ "$(uname)" == "Linux" ]] && ! test -f /.dockerenv; then
    mkdir -p "${HOME}/.config/systemd/user"
    mkdir -p "${HOME}/.config/docker-user"
    chmod 700 "${HOME}/.config/docker-user"

    if command -v loginctl &>/dev/null; then
        loginctl enable-linger "$(id -un)" 2>/dev/null || true
    fi

    if command -v podman &>/dev/null && command -v systemctl &>/dev/null; then
        systemctl --user enable --now podman.socket 2>/dev/null || true
        systemctl --user enable --now podman-restart.service 2>/dev/null || true
    fi

    if command -v nvidia-ctk &>/dev/null; then
        systemctl --user daemon-reload 2>/dev/null || true
        systemctl --user enable --now nvidia-ctk-docker-config.service 2>/dev/null || true
    fi
fi

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

NERDFONTS_PATH=${HOME}/.local/share/fonts/fonts/nerdfonts/
mkdir -p "${NERDFONTS_PATH}"
nix-shell --pure -p nix nerd-fonts.jetbrains-mono --run "cp --no-preserve=mode -R $(nix-instantiate --eval --expr 'with import <nixpkgs> {}; pkgs.nerd-fonts.jetbrains-mono.outPath')/share/fonts/truetype/NerdFonts/* ${NERDFONTS_PATH}"
nix-shell --pure -p fontconfig --run "fc-cache -fv"
nix-shell -p pre-commit --pure --run "pre-commit install"
nix-shell -p direnv --pure --run "direnv allow"
