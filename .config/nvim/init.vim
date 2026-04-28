set runtimepath^=~/.config/vim runtimepath+=~/.config/vim/after
let &packpath=&runtimepath
source ~/.config/vim/vimrc

lua require('config')
