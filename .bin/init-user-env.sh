#!/usr/bin/env sh

set -uex

test -d "${HOME}/.local/share/oh-my-zsh" || KEEP_ZSHRC=yes CHSH=no RUNZSH=no ZSH="${HOME}/.local/share/oh-my-zsh" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

ZSH_CUSTOM="${HOME}/.local/share/oh-my-zsh/custom"

test -d ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions || git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

test -d ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting || git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

test -d ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k || git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

test -d ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-vi-mode || git clone https://github.com/jeffreytse/zsh-vi-mode ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-vi-mode

test -d ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/forgit || git clone https://github.com/wfxr/forgit.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/forgit

test -d ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/you-should-use || git clone https://github.com/MichaelAquilina/zsh-you-should-use.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/you-should-use

test -d ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/fzf-tab || git clone https://github.com/Aloxaf/fzf-tab ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/fzf-tab

if test -f "${HOME}/.local/bin/nvim"
then
    mv "${HOME}/.local/bin/nvim" "${HOME}/.local/bin/nvim.$(date +%s)"
fi

wget https://github.com/neovim/neovim/releases/download/v0.10.0/nvim.appimage -O "${HOME}/.local/bin/nvim"
chmod u+x "${HOME}/.local/bin/nvim"

# Install sway flatpak
LATEST_RELEASE=$(curl -L -s -H 'Accept: application/json' https://github.com/fspv/flatpaks/releases/latest)
LATEST_VERSION=$(echo $LATEST_RELEASE | sed -e 's/.*"tag_name":"\([^"]*\)".*/\1/')
ARTIFACT_URL="https://github.com/fspv/flatpaks/releases/download/$LATEST_VERSION/sway.flatpak"
TMP_DIR=$(mktemp -d)
wget $ARTIFACT_URL -O $TMP_DIR/sway.flatpak
flatpak install -y --noninteractive --user $TMP_DIR/sway.flatpak || true

# Install telegram
flatpak install -y --user flathub org.telegram.desktop
flatpak override --user org.telegram.desktop --filesystem=${HOME}/Pictures
flatpak override --user org.telegram.desktop --filesystem=${HOME}/Downloads

go install github.com/jstemmer/gotags@latest

curl -L https://sourcegraph.com/.api/src-cli/src_linux_amd64 -o ~/.bin/src
chmod +x ~/.bin/src

GO_VERSION=1.22.3
go install golang.org/dl/go${GO_VERSION}@latest
~/go/bin/go${GO_VERSION} download
ln -sf ~/go/bin/go${GO_VERSION} ~/go/bin/go

cargo install kubie --locked
