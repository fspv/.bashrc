" Read custom after configuration
if filereadable($HOME . '/.vim/manual/before.vim')
    source <sfile>:h/.vim/manual/before.vim
endif

if filereadable("/etc/vim/vimrc")
  source /etc/vim/vimrc
endif

set termguicolors

" Ctrl-C doesn't trigger InsertLeave event, so doesn't work well with LSP
inoremap <C-c> <Esc>

" Go to the previous open file with backspace
nnoremap <BS> <C-^>

" Disable go to tag on Ctrl+Click. Used to open links
nnoremap <C-LeftMouse> <Esc>
nnoremap <C-LeftMouse> <Esc>

" Set autoindent and key to disable it during paste
set autoindent

" Set number of spaces to replace \t
set tabstop=4
set shiftwidth=4
set smarttab
if has("autocmd")
  filetype plugin indent on
endif
" Autoreplace tab by default
set et

" Disable automatic visual mode on mouse select
" (breaks identation and other stuff)
" set mouse-=a
" set mouse=
set mouse=nv

" Show us the command we're typing
set showcmd

" More space for errors
set cmdheight=2

" Make autocomplete and other things more responsive
set updatetime=100

" Show line numbers
set number

" Preserve undo history https://neovim.io/doc/user/options.html#'undofile'
set undodir=~/.vim/undo
set undofile

if !isdirectory(&undodir)
    call mkdir(&undodir, "p", 0700)
endif

" Try to show at least three lines and two columns of context when
" scrolling
set scrolloff=3
set sidescrolloff=2

" Use the cool tab complete menu
set wildmenu
set wildignore=*.o,*~,tmp/*,*.so,*.swp,*.zip,*.json,*.html,*.pb.go,*.pb.[a-z]*.go,*_pb2.py,*_pb2_grpc.py,plz-out/*

" Enable folds
" set foldenable
set foldcolumn=1
set foldlevel=99
set foldmethod=expr
set foldexpr=nvim_treesitter#foldexpr()

" Autocompletion requires nopaste
set nopaste

" Enable ruler
set ruler
set et

set laststatus=2
set display+=truncate
set listchars=tab:>\ ,trail:-,extends:>,precedes:<,nbsp:+
set formatoptions+=j
set autoread

set history=1000

" Saving options in session and view files causes more problems than it
" solves, so disable it.
set sessionoptions-=options
set viewoptions-=options

" Disable a legacy behavior that can break plugin maps.
set nolangremap

" Allow color schemes to do bright colors without forcing bold.
if &t_Co == 8 && $TERM !~# '^Eterm'
  set t_Co=16
endif

" Save position in file
if has("autocmd")
  au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif
endif

" Use X clipboard
" set clipboard+=unnamed

" Search settings
set showmatch
set hlsearch
set incsearch
set ignorecase
" Don't jump to the next search item on *
nnoremap * *``

" Order of encondings application
set ffs=unix,dos,mac
set fencs=utf-8,cp1251,koi8-r,ucs-2,cp866
set encoding=UTF-8

" Enable syntax highlighting
syntax on
let python_highlight_all=1

" Necesary for lots of cool vim things
set nocompatible

" Enable reading config from file header
set modeline
set modelines=2

set backspace=indent,eol,start

set encoding=utf-8
set fileencoding=utf8

" Enable folding
" set foldmethod=indent
" set foldlevel=99
set conceallevel=2

" Disable annoying recording which I don't use anyway
map q <Nop>

" Remap leader
let mapleader = ","

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
    call vundle#end()
    filetype plugin indent on
endif

" Disable expandtab for Makefiles
autocmd FileType make set noexpandtab

" Set some filetypes
au BufNewFile,BufRead *.sls setf yaml
au BufNewFile,BufRead *.build_defs setf python

" Set yaml tab indentation to 2
au BufNewFile,BufRead *.js setl sw=2 sts=2 et
au BufNewFile,BufRead *.ts setl sw=2 sts=2 et
autocmd BufWritePost *.ts EslintFixAll
au BufNewFile,BufRead *.sls setl sw=2 sts=2 et
au BufNewFile,BufRead *.yaml setl sw=2 sts=2 et
au BufNewFile,BufRead *.yml setl sw=2 sts=2 et
au BufNewFile,BufRead *.php setl sw=2 sts=2 et
au BufNewFile,BufRead *.cpp setl sw=2 sts=2 et
au BufNewFile,BufRead *.lua setl sw=2 sts=2 et
au BufNewFile,BufRead *.go setl noet
au BufNewFile,BufRead tnsnames.ora setl sw=2 sts=2 et syn=lisp

" json
augroup json_autocmd
  autocmd!
  autocmd FileType json set formatoptions=tcq2l
  autocmd FileType json set textwidth=78 shiftwidth=2
  autocmd FileType json set softtabstop=2 tabstop=8
  autocmd FileType json set expandtab
  " autocmd FileType json set foldmethod=syntax
augroup END

" Extend copy buffer
set viminfo='20,<1000

" Increase the number of open tabs limit
set tabpagemax=999

" Close preview window when done with completions
autocmd InsertLeave,CompleteDone * if pumvisible() == 0 | silent! pclose | endif

" Read custom after configuration
if filereadable($HOME . '/.vim/manual/after.vim')
    source <sfile>:h/.vim/manual/after.vim
endif
