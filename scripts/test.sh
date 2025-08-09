#!/bin/bash

set -e

# Create a dummy vimrc to avoid errors
touch ~/.vimrc

# Prepare nvim environment
NVIM_HOME=$(mktemp -d)
export NEOVIM_LAZY_PATH="$NVIM_HOME/lazy/lazy.nvim"
git clone --filter=blob:none --branch=stable https://github.com/folke/lazy.nvim.git "$NEOVIM_LAZY_PATH"

export BWRAPPED=1

# Symlink the nvim config to the correct location
mkdir -p ~/.config
ln -s "$PWD/.config/nvim" ~/.config/nvim

# Download nvim
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim.appimage
chmod u+x nvim.appimage

# Run nvim and install plugins
./nvim.appimage --headless \
  -c 'autocmd User LazySync quitall'
