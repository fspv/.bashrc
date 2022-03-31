" Read custom after configuration
if filereadable($HOME . '/.vim/manual/before.vim')
    source <sfile>:h/.vim/manual/before.vim
endif

" Python3 for neovim
" virtualenv -p python3 ~/venv/neovim
" . ~/venv/neovim/bin/activate
" pip install neovim jedi
" or apt-get install python3-neovim
if empty($VIRTUAL_ENV)
    let g:python3_host_prog = $HOME . '/venv/neovim/bin/python3' " Include default system config
else
    let g:python3_host_prog = $VIRTUAL_ENV . '/bin/python3' " Include default system config
    call system($VIRTUAL_ENV . '/bin/pip install neovim jedi mypy black flake8 python-lsp-server[all] pylint')
endif

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
"set listchars=tab:··
"set listchars=tab:»\ ,trail:·,eol:¶
"set list

" Disable automatic visual mode on mouse select
" (breaks identation and other stuff)
set mouse-=a

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
set wildignore=*.o,*~

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

set backspace=indent,eol,start

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
au BufNewFile,BufRead *.php setl sw=2 sts=2 et
au BufNewFile,BufRead *.cpp setl sw=2 sts=2 et
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
        Plug 'dense-analysis/ale' " Linting, formatting
        Plug 'junegunn/fzf', { 'do': { -> fzf#install() } } " fuzzy search
        Plug 'junegunn/fzf.vim' " fuzzy search 2
        Plug 'ntpeters/vim-better-whitespace' " Highlight trailing whitespace
        Plug 'raimondi/delimitMate' " Auto-complete matching quotes, brackets, etc
        Plug 'scrooloose/nerdtree' " Graphical file manager
        Plug 'tpope/vim-sensible' " Universally good defaults
        Plug 'tpope/vim-speeddating' " Use ctrl-a and ctrl-x to increment/decrement times/dates
        Plug 'vim-scripts/PreserveNoEOL' " Omit the final newline of a file if it wasn't present when we opened it
        if filereadable(python3_host_prog)
            Plug 'shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }  " Completion
        endif
        Plug 'deoplete-plugins/deoplete-jedi' " Another way to have completion (pyls default)
        Plug 'morhetz/gruvbox' " Colors!
        Plug 'vim-python/python-syntax' " Updated Python syntax highlighting
        Plug 'junegunn/rainbow_parentheses.vim' " Color-matched parens
        Plug 'easymotion/vim-easymotion' " Faster navigation
        Plug 'haya14busa/incsearch.vim' " Highlight incremental search
        Plug 'haya14busa/incsearch-fuzzy.vim' " Fuzzy incremental search
        Plug 'haya14busa/incsearch-easymotion.vim' " Easymotion integration for for incremental fuzzy search
        Plug 'tpope/vim-dispatch' " Async builds
        Plug 'preservim/tagbar' " File navigation
        Plug 'ctrlpvim/ctrlp.vim' " fuzzy file, buffer, mru, tag, ... finder
        Plug 'octol/vim-cpp-enhanced-highlight' " Better C++ syntax highlight
        " Plug 'vim-airline/vim-airline' " Nice status bar
        " Plug 'vim-airline/vim-airline-themes' " Themes for the status bar
        Plug 'ludovicchabant/vim-lawrencium' " HG plugin
        Plug 'tpope/vim-fugitive' " Git plugin
        Plug 'airblade/vim-rooter' " Automatically detect project root
        if has('nvim') || has('patch-8.0.902')
          Plug 'mhinz/vim-signify'
        else
          Plug 'mhinz/vim-signify', { 'branch': 'legacy' }
        endif

        " Read custom plugins configuration
        if filereadable($HOME . '/.vim/manual/plug.vim')
            source <sfile>:h/.vim/manual/plug.vim
        endif
    call plug#end()

    "
    " Plugin configuration
    " ====================

    " Fuzzy search
    map z/ <Plug>(incsearch-fuzzy-/)
    map z? <Plug>(incsearch-fuzzy-?)
    map zg/ <Plug>(incsearch-fuzzy-stay)

    " ALE keybinds
    nmap <leader>d <Plug>(ale_detail)
    nmap <leader>n <Plug>(ale_next)
    nmap <leader>g <Plug>(ale_go_to_definition)
    nmap <leader>h <Plug>(ale_hover)
    let g:ale_hover_cursor = 1

    " ALE
    let g:ale_echo_msg_format = '[%linter%] %s [%severity%]'
    " apt-get install flake8 bandit mypy pylint3 pycodestyle pyflakes black isort
    " apt-get install clangd cppcheck flawfinder astyle clang-format clang-tidy uncrustify clangd clang
    " snap install pyls
    let g:ale_linters = {'python': ['flake8', 'mypy', 'pyls', 'pylint', 'bandit', 'pylsp']}
    let b:ale_fixers = {'python': ['black', 'isort'], 'cpp': ['astyle', 'clang-format', 'clangtidy', 'remove_trailing_lines', 'trim_whitespace', 'uncrustify']}
    let b:ale_fix_on_save = 1
    let g:ale_float_preview = 1
    let g:ale_floating_preview = 1
    let g:ale_floating_window_border = []
    let g:ale_hover_to_preview = 1
    let g:ale_hover_to_floating_preview = 1
    let g:ale_cursor_detail = 1
    let g:ale_detail_to_floating_preview = 1
    " let g:ale_list_window_size = 10
    " let g:ale_set_balloons = 1

    augroup ale_hover_cursor
      autocmd!
      autocmd CursorHold * ALEHover
    augroup END

    " Deoplete + ALE
    if filereadable(python3_host_prog)
        let g:deoplete#enable_at_startup = 1
        call deoplete#custom#source('ale', 'rank', 999)
        call deoplete#custom#source('_', 'matchers', ['matcher_full_fuzzy'])
    endif

    " NERDTree
    " Start NERDTree. If a file is specified, move the cursor to its window.
    " autocmd StdinReadPre * let s:std_in=1
    " autocmd VimEnter * NERDTree | if argc() > 0 || exists("s:std_in") | wincmd p | endif

    " Exit Vim if NERDTree is the only window left.
    autocmd BufEnter * if tabpagenr('$') == 1 && winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isTabTree() |
        \ quit | endif

    " Tagbar
    " apt-get install ctags
    nmap <F8> :TagbarToggle<CR>

    " CtrlP
    let g:ctrlp_cmd = 'CtrlPBuffer'

    " Vim airline
    let g:airline_theme='wombat'
    let g:airline#extensions#tabline#enabled = 1
    let g:airline#extensions#ale#enabled = 1
    let g:airline#extensions#branch#enabled = 1

    " Vim rooter
    " let g:rooter_cd_cmd = 'lcd' " Change dir only for current window
    let g:rooter_manual_only = 1

    " FZF
    " FindRootDirectory() comes from vim rooter
    command! -bang -nargs=? -complete=dir ProjectFiles
        \ call fzf#vim#files(
        \   <q-args>,
        \   fzf#vim#with_preview({'dir': FindRootDirectory()}),
        \   <bang>0
        \ )
    command! -bang -nargs=* ProjectRg
        \ call fzf#vim#grep(
        \   'rg --column --line-number --no-heading --color=always --smart-case -- '.shellescape(<q-args>),
        \   1,
        \   fzf#vim#with_preview({'dir': FindRootDirectory()}),
        \   <bang>0
        \ )

    map ff/ :ProjectFiles<CR>
    map fc/ :ProjectRg<CR>
endif

" Close preview window when done with completions
autocmd InsertLeave,CompleteDone * if pumvisible() == 0 | silent! pclose | endif

" Read custom after configuration
if filereadable($HOME . '/.vim/manual/after.vim')
    source <sfile>:h/.vim/manual/after.vim
endif
