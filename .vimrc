" Include default system config
if filereadable("/etc/vim/vimrc")
  source /etc/vim/vimrc
endif

if filereadable(".vim/autoload/pathogen.vim")
  execute pathogen#infect()
endif

" Set autoindent and key to disable it during paste
set autoindent
set pastetoggle=<F3>

" Set number of spaces to replace \t
set tabstop=4
set shiftwidth=4
set smarttab
" Autoreplace tab by default
set et
" Show tabs at the begining of line by dots
"set listchars=tab:··
"set listchars=tab:»\ ,trail:·,eol:¶
"set list

" Show us the command we're typing
set showcmd

" Try to show at least three lines and two columns of context when
" scrolling
set scrolloff=3
set sidescrolloff=2

" Use the cool tab complete menu
set wildmenu
set wildignore=*.o,*~

" Enable folds
"set foldenable
"set foldmethod=syntax

" Correct indents on Ctrl-CV
set paste

" Enable ruler
set ruler
set et

" Save position in file
if has("autocmd")
  au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif
endif

" Use X clipboard
set clipboard+=unnamed

" Search settings
set showmatch
set hlsearch
set incsearch
set ignorecase

" Order of encondings application
set ffs=unix,dos,mac
set fencs=utf-8,cp1251,koi8-r,ucs-2,cp866

" Enable syntax highlighting
syntax on
let python_highlight_all=1

" Necesary for lots of cool vim things
set nocompatible

" Enable reading config from file header
set modeline
set modelines=2

set backspace=2

set encoding=utf-8
set fileencoding=utf8

" Enable folding
set foldmethod=indent
set foldlevel=99

"split navigations
nnoremap <C-J> <C-W><C-J>
nnoremap <C-K> <C-W><C-K>
nnoremap <C-L> <C-W><C-L>
nnoremap <C-H> <C-W><C-H>

" Enable folding with the spacebar
nnoremap <space> za

if !empty(glob("~/.vim/bundle/Vundle.vim"))
    " set the runtime path to include Vundle and initialize
    set rtp+=~/.vim/bundle/Vundle.vim
    call vundle#begin()

    " let Vundle manage Vundle, required
    Plugin 'gmarik/Vundle.vim'
    Plugin 'tmhedberg/SimpylFold'
    Bundle 'Valloric/YouCompleteMe'
    Plugin 'scrooloose/syntastic'
    Plugin 'nvie/vim-flake8'

    " All of your Plugins must be added before the following line
    call vundle#end()
    filetype plugin indent on
endif

" Disable expandtab for Makefiles
:autocmd FileType make set noexpandtab

" <F2> calls NerdTree plugin
map <F2> :NERDTree <CR>

" Set some filetypes
au BufNewFile,BufRead *.sls setf yaml

" Set yaml tab indentation to 2
au BufNewFile,BufRead *.sls setl sw=2 sts=2 et
au BufNewFile,BufRead *.yaml setl sw=2 sts=2 et
au BufNewFile,BufRead *.yml setl sw=2 sts=2 et
au BufNewFile,BufRead tnsnames.ora setl sw=2 sts=2 et syn=lisp

" json
augroup json_autocmd
  autocmd!
  autocmd FileType json set formatoptions=tcq2l
  autocmd FileType json set textwidth=78 shiftwidth=2
  autocmd FileType json set softtabstop=2 tabstop=8
  autocmd FileType json set expandtab
  autocmd FileType json set foldmethod=syntax
  autocmd FileType json set conceallevel=0
augroup END

" Highlight style issues
match ErrorMsg /\s\+$/
2match ErrorMsg /\%81v.\+/

