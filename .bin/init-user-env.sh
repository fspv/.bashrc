#!/usr/bin/env sh

set -uex

mkdir -p ~/venv
virtualenv -p python3 ~/venv/neovim

set +x
. ~/venv/neovim/bin/activate
set -x

pip install neovim jedi

curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

sudo snap install rustup --classic
sudo snap install rust-analyzer --beta

sudo apt-get install -y flake8 bandit mypy pycodestyle python3-pyflakes black isort
sudo apt-get install -y clangd cppcheck flawfinder astyle clang-format clang-tidy uncrustify clangd clang
sudo apt install python3.10-venv

sudo apt-get install -y exuberant-ctags universal-ctags

go install github.com/jstemmer/gotags@latest

mkdir -p ~/.local/share/fonts/fonts/nerdfonts
wget https://github.com/ryanoasis/nerd-fonts/releases/download/v2.3.3/JetBrainsMono.zip -O ~/.local/share/fonts/fonts/tmp.zip
unzip ~/.local/share/fonts/fonts/tmp.zip -d ~/.local/share/fonts/fonts/nerdfonts
rm -rf ~/.local/share/fonts/fonts/tmp.zip
fc-cache -fv