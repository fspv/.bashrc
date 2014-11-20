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

" Necesary for lots of cool vim things
set nocompatible

" Enable reading config from file header
set modeline
set modelines=2

set backspace=2

set encoding=utf-8
set fileencoding=utf8

" Disable expandtab for Makefiles
:autocmd FileType make set noexpandtab

" <F2> calls NerdTree plugin
map <F2> :NERDTree <CR>

