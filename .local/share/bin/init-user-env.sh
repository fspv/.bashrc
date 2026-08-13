#!/usr/bin/env bash

set -uex

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

chmod 700 "${DOTFILES_DIR}/.ssh"
chmod 700 "${DOTFILES_DIR}/.cache"
chmod 700 "${DOTFILES_DIR}/.local"

if [[ "$(uname)" == "Linux" ]] && ! test -f /.dockerenv; then
    chmod 700 "${DOTFILES_DIR}/.config/docker-user"

    if command -v loginctl &>/dev/null; then
        loginctl enable-linger "$(id -un)" 2>/dev/null || true
    fi
fi

if [[ -z "${GITHUB_ACTIONS:-}" ]] && test -f /.dockerenv; then
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
if [[ -f "${DOTFILES_DIR}/.pre-commit-config.yaml" ]] && command -v pre-commit &>/dev/null; then
  bash -c "cd ${DOTFILES_DIR} && pre-commit install"
fi

NERDFONTS_PATH=${DOTFILES_DIR}/.local/share/fonts/fonts/nerdfonts/
nix-shell --pure -p nix nerd-fonts.jetbrains-mono --run "cp --no-preserve=mode -R $(nix-instantiate --eval --expr 'with import <nixpkgs> {}; pkgs.nerd-fonts.jetbrains-mono.outPath')/share/fonts/truetype/NerdFonts/* ${NERDFONTS_PATH}"
nix-shell --pure -p fontconfig --run "fc-cache -fv"
nix-shell -p pre-commit --pure --run "pre-commit install"
nix-shell -p direnv --pure --run "direnv allow"
