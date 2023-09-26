" Read custom after configuration
if filereadable($HOME . '/.vim/manual/before.vim')
    source <sfile>:h/.vim/manual/before.vim
endif

" Python3 for neovim
" virtualenv -p python3 ~/venv/neovim
" . ~/venv/neovim/bin/activate
" pip install -U setuptools
" pip install neovim jedi
" or apt-get install python3-neovim
if empty($VIRTUAL_ENV)
    let g:python3_host_prog = $HOME . '/venv/neovim/bin/python3' " Include default system config
else
    let g:python3_host_prog = $VIRTUAL_ENV . '/bin/python3' " Include default system config
    " FIXME: flake8 version is frozen due to multiple issues like:
    " https://github.com/aleGpereira/flake8-mock/issues/10
    call system($VIRTUAL_ENV . '/bin/pip install -U setuptools')

    call system($VIRTUAL_ENV . '/bin/pip install neovim jedi mypy black flake8==4.0.1 python-lsp-server[all] pylint pynvim python-language-server[all]')
endif

autocmd FileType go call system('GO111MODULE=on go get golang.org/x/tools/gopls')

if filereadable("/etc/vim/vimrc")
  source /etc/vim/vimrc
endif

if filereadable($HOME . "/.vim/autoload/pathogen.vim")
  execute pathogen#infect()
endif

" Set autoindent and key to disable it during paste
set autoindent
set pastetoggle=<F3>

" Set number of spaces to replace \t
set tabstop=4
set shiftwidth=4
set smarttab
if has("autocmd")
  filetype plugin indent on
endif
" Autoreplace tab by default
set et
" Show tabs at the begining of line by dots
set list listchars=tab:¦\ ,trail:·,extends:»,precedes:«,nbsp:×

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

" Show warning/error signs over numbers on the left
if has("nvim-0.5.0") || has("patch-8.1.1564")
  " Recently vim can merge signcolumn and number column into one
  set signcolumn=number
else
  set signcolumn=yes
endif

" Try to show at least three lines and two columns of context when
" scrolling
set scrolloff=3
set sidescrolloff=2

" Use the cool tab complete menu
set wildmenu
set wildignore=*.o,*~,tmp/*,*.so,*.swp,*.zip,*.json,*.html,*.pb.go,*.pb.[a-z]*.go,*_pb2.py,*_pb2_grpc.py,plz-out/*

" Enable folds
"set foldenable
"set foldmethod=syntax

" Autocompletion requires nopaste
set nopaste

" Enable ruler
set ruler
set et

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
set foldmethod=indent
set foldlevel=99

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
:autocmd FileType make set noexpandtab

" Set some filetypes
au BufNewFile,BufRead *.sls setf yaml

" Set yaml tab indentation to 2
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
  autocmd FileType json set foldmethod=syntax
  autocmd FileType json set conceallevel=0
augroup END

" Extend copy buffer
set viminfo='20,<1000

" Increase the number of open tabs limit
set tabpagemax=999

" Load plug plugins
if filereadable($HOME . "/.vim/autoload/plug.vim")
    " Install vim-plug https://github.com/junegunn/vim-plug
    " (use vim installation instruction, not nvim
    " run nvim
    " :PlugInstall
    " :UpdateRemotePlugins
    call plug#begin()
        Plug 'williamboman/mason.nvim', {'do': 'MasonUpdate'} " Yet another package manager
        Plug 'airblade/vim-rooter' " Automatically detect project root
        Plug 'junegunn/fzf', { 'do': { -> fzf#install() } } " fuzzy search
        Plug 'junegunn/fzf.vim' " fuzzy search 2
        Plug 'ntpeters/vim-better-whitespace' " Highlight trailing whitespace
        Plug 'raimondi/delimitMate' " Auto-complete matching quotes, brackets, etc
        Plug 'nvim-tree/nvim-tree.lua' " Graphical file manager
        Plug 'tpope/vim-sensible' " Universally good defaults
        Plug 'tpope/vim-speeddating' " Use ctrl-a and ctrl-x to increment/decrement times/dates
        Plug 'vim-scripts/PreserveNoEOL' " Omit the final newline of a file if it wasn't present when we opened it
        Plug 'morhetz/gruvbox' " Colors!
        Plug 'vim-python/python-syntax' " Updated Python syntax highlighting
        Plug 'easymotion/vim-easymotion' " Faster navigation
        Plug 'haya14busa/incsearch.vim' " Highlight incremental search
        Plug 'haya14busa/incsearch-fuzzy.vim' " Fuzzy incremental search
        Plug 'haya14busa/incsearch-easymotion.vim' " Easymotion integration for for incremental fuzzy search
        Plug 'tpope/vim-dispatch' " Async builds
        Plug 'ctrlpvim/ctrlp.vim' " fuzzy file, buffer, mru, tag, ... finder
        Plug 'octol/vim-cpp-enhanced-highlight' " Better C++ syntax highlight
        Plug 'ludovicchabant/vim-lawrencium' " HG plugin
        Plug 'tpope/vim-fugitive' " Git plugin
        if has('nvim') || has('patch-8.0.902')
          Plug 'mhinz/vim-signify'
        else
          Plug 'mhinz/vim-signify', { 'branch': 'legacy' }
        endif
        Plug 'tomlion/vim-solidity'
        Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
        Plug 'ellisonleao/gruvbox.nvim'

        Plug 'neovim/nvim-lspconfig'
        Plug 'hrsh7th/cmp-nvim-lsp'
        Plug 'hrsh7th/cmp-buffer'
        Plug 'hrsh7th/cmp-path'
        Plug 'hrsh7th/cmp-cmdline'
        Plug 'hrsh7th/nvim-cmp'

        Plug 'williamboman/mason-lspconfig.nvim' " Automatically install LS
        Plug 'VonHeikemen/lsp-zero.nvim' " Boilerplate configuration for lspconfig

        Plug 'hrsh7th/cmp-vsnip'
        Plug 'hrsh7th/vim-vsnip'
        Plug 'hrsh7th/vim-vsnip-integ'

        Plug 'rafamadriz/friendly-snippets'
        Plug 'nvim-neo-tree/neo-tree.nvim'
        Plug 'MunifTanjim/nui.nvim'
        Plug 'ray-x/lsp_signature.nvim'

        Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries' }

        " sudo snap install rustup --classic
        " sudo snap install rust-analyzer --beta
        Plug 'rust-lang/rust.vim'
        Plug 'simrat39/rust-tools.nvim'

        Plug 'nvim-lua/plenary.nvim'
        Plug 'mfussenegger/nvim-dap'
        Plug 'marcuscaisey/please.nvim'

        Plug 'kosayoda/nvim-lightbulb'
        Plug 'weilbith/nvim-code-action-menu'

        Plug 'skywind3000/vim-quickui' " Menubar

        Plug 'nvim-tree/nvim-web-devicons' " Icons for tabs
        Plug 'ryanoasis/vim-devicons'
        Plug 'romgrk/barbar.nvim' " Tabs

        Plug 'onsails/lspkind.nvim' " Completion icons

        Plug 'tpope/vim-commentary' " Comment code with gc

        Plug 'fspv/sourcegraph.nvim'

        " Plug 'itchyny/lightline.vim' " Status Line
        Plug 'nvim-lualine/lualine.nvim' " Status Line


        Plug 'nvim-telescope/telescope.nvim' " Alternative to fzf

        Plug 'nvim-telescope/telescope-live-grep-args.nvim' " Live grep with args

        Plug 'Yggdroot/indentLine' " Identation indication for spaces

        Plug 'andymass/vim-matchup' " Matching parentheses improvement

        Plug 'stevearc/profile.nvim'
        Plug 'folke/trouble.nvim' " Show diagnostics window

        Plug 'RRethy/vim-illuminate' " Highlight other uses of symbol under cursor

        Plug 'glepnir/lspsaga.nvim' " More convenient lsp

        Plug 'simrat39/symbols-outline.nvim' " Tag bar

        Plug 'folke/which-key.nvim'  " Show command help as you enter it

        Plug 'voldikss/vim-floaterm'  " Floating terminal

        " Read custom plugins configuration
        if filereadable($HOME . '/.vim/manual/plug.vim')
            source <sfile>:h/.vim/manual/plug.vim
        endif
    call plug#end()
endif

" Close preview window when done with completions
autocmd InsertLeave,CompleteDone * if pumvisible() == 0 | silent! pclose | endif

" Read custom after configuration
if filereadable($HOME . '/.vim/manual/after.vim')
    source <sfile>:h/.vim/manual/after.vim
endif
