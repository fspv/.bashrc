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
set list listchars=tab:»·,trail:·,extends:»,precedes:«,nbsp:×

" Disable automatic visual mode on mouse select
" (breaks identation and other stuff)
" set mouse-=a
set mouse=

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
set clipboard+=unnamed

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
        Plug 'preservim/tagbar' " File navigation
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

        " Read custom plugins configuration
        if filereadable($HOME . '/.vim/manual/plug.vim')
            source <sfile>:h/.vim/manual/plug.vim
        endif

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
        Plug 'ray-x/lsp_signature.nvim'

        Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries' }

        " sudo snap install rustup --classic
        " sudo snap install rust-analyzer --beta
        Plug 'rust-lang/rust.vim'

        Plug 'nvim-lua/plenary.nvim'
        Plug 'mfussenegger/nvim-dap'
        Plug 'marcuscaisey/please.nvim'

        Plug 'wellle/context.vim'

        Plug 'kosayoda/nvim-lightbulb'
        Plug 'weilbith/nvim-code-action-menu'

        Plug 'skywind3000/vim-quickui' " Menubar

        Plug 'nvim-tree/nvim-web-devicons' " Icons for tabs
        Plug 'ryanoasis/vim-devicons'
        Plug 'romgrk/barbar.nvim' " Tabs

        Plug 'onsails/lspkind.nvim' " Completion icons

        Plug 'tpope/vim-commentary' " Comment code with gc

        Plug 'fspv/sourcegraph.nvim'

        Plug 'nvim-lualine/lualine.nvim' " Status line

        Plug 'nvim-telescope/telescope.nvim' " Alternative to fzf
    call plug#end()

    "
    " Plugin configuration
    " ====================

    " FZF
    if has_key(plugs, 'fzf')
        " Fuzzy search
        " map /  <Plug>(incsearch-forward)
        " map ?  <Plug>(incsearch-backward)
        " map g/ <Plug>(incsearch-stay)
        " map z/ <Plug>(incsearch-fuzzy-/)
        " map z? <Plug>(incsearch-fuzzy-?)
        " map zg/ <Plug>(incsearch-fuzzy-stay)

        " FindRootDirectory() comes from vim rooter
        command! -bang -nargs=? -complete=dir FF
            \ call fzf#vim#files(
            \   <q-args>,
            \   fzf#vim#with_preview({'dir': FindRootDirectory()}),
            \   <bang>0
            \ )
        command! -bang -nargs=* FC
            \ call fzf#vim#grep(
            \   'rg --column --line-number --no-heading --color=always --smart-case '.<q-args>.' || true',
            \   1,
            \   fzf#vim#with_preview({'dir': FindRootDirectory(), 'options': '--delimiter : --nth 4..'}),
            \   <bang>0
            \ )

        command! -bang -nargs=* FCC
            \ call fzf#vim#grep(
            \   'rg --column --line-number --no-heading --color=always --smart-case --max-depth 0'.shellescape(expand("<cword>")).' || true',
            \   1,
            \   fzf#vim#with_preview({'dir': FindRootDirectory(), 'options': ''}),
            \   <bang>0
            \ )

        map ff/ :FF<CR>
        map fc/ :FC ''<CR>
        map fcc/ :FCC<CR>
    endif

    function EnableArcanistAutoformat()
        " Add a fixer for arcanist https://github.com/phacility/arcanist
        if executable('arc') && filereadable(FindRootDirectory() . '/.arclint')
            " TODO: check if it overwrites other commands
            au BufWritePost *.py,*.go,BUILD,*.build_def,*.build_defs exec '!arc lint --apply-patches' shellescape(expand('%:p'), 1)
        endif
    endfunction

    autocmd VimEnter * call EnableArcanistAutoformat()

    " NvimTree
    map <leader>nn :NvimTreeFindFile <CR>

    " Tagbar
    if has_key(plugs, 'tagbar')
        " apt-get install ctags
        " go get -u github.com/jstemmer/gotags
        " go install github.com/jstemmer/gotags
        autocmd FileType python,c,cpp,go,rust,proto TagbarOpen
        " apt install universal-ctags
        let g:tagbar_ctags_bin="ctags-universal"
        let g:rust_use_custom_ctags_defs=1
    endif

    " CtrlP
    if has_key(plugs, 'ctrlp.vim')
        let g:ctrlp_cmd = 'CtrlPBuffer'
    endif

    " Vim airline
    if has_key(plugs, 'vim-airline')
        let g:airline_theme='wombat'
        let g:airline#extensions#tabline#enabled = 1
        let g:airline#extensions#ale#enabled = 1
        let g:airline#extensions#branch#enabled = 1
    endif

    " Vim rooter
    " let g:rooter_cd_cmd = 'lcd' " Change dir only for current window
    if has_key(plugs, 'vim-rooter')
        let g:rooter_manual_only = 1
    endif

    set completeopt=menu,menuone,noselect

    " vim-go
    if has_key(plugs, 'vim-go')
        " status bar
        let g:go_auto_type_info = 0
        " matching identifiers
        let g:go_auto_sameids = 0

        let g:go_code_completion_enabled = 0
        let g:go_fmt_autosave = 0
        let g:go_mod_fmt_autosave = 0
        let g:go_template_autocreate = 0
        let g:go_imports_autosave = 0
        let g:go_list_autoclose = 0
        let g:go_asmfmt_autosave = 0

        let g:go_doc_keywordprg_enabled = 0
        let g:go_def_mapping_enabled = 0
        let g:go_debug_mappings = {}
        let g:go_jump_to_error = 0
        let g:go_echo_go_info = 0
    endif

    if has_key(plugs, 'please.nvim') && executable('plz')
        function DetectPlz()
            if filereadable(FindRootDirectory() . '/.plzconfig')
                " TODO: check if it overwrites other commands
                au BufWritePost *.go exec '!plz update-go-targets' shellescape(expand('%:p:h'), 1)
                au BufRead,BufNewFile BUILD,*.build_def set filetype=please
                au BufRead,BufNewFile BUILD,*.build_def,*.build_defs set syntax=python
            endif
        endfunction
        autocmd VimEnter *.go call DetectPlz()
    endif

    if has_key(plugs, 'vim-vsnip')
        " Expand
        imap <expr> <C-j>   vsnip#expandable()  ? '<Plug>(vsnip-expand)'         : '<C-j>'
        smap <expr> <C-j>   vsnip#expandable()  ? '<Plug>(vsnip-expand)'         : '<C-j>'

        " Expand or jump
        imap <expr> <C-l>   vsnip#available(1)  ? '<Plug>(vsnip-expand-or-jump)' : '<C-l>'
        smap <expr> <C-l>   vsnip#available(1)  ? '<Plug>(vsnip-expand-or-jump)' : '<C-l>'

        " Jump forward or backward
        imap <expr> <Tab>   vsnip#jumpable(1)   ? '<Plug>(vsnip-jump-next)'      : '<Tab>'
        smap <expr> <Tab>   vsnip#jumpable(1)   ? '<Plug>(vsnip-jump-next)'      : '<Tab>'
        imap <expr> <S-Tab> vsnip#jumpable(-1)  ? '<Plug>(vsnip-jump-prev)'      : '<S-Tab>'
        smap <expr> <S-Tab> vsnip#jumpable(-1)  ? '<Plug>(vsnip-jump-prev)'      : '<S-Tab>'

        " Select or cut text to use as $TM_SELECTED_TEXT in the next snippet.
        " See https://github.com/hrsh7th/vim-vsnip/pull/50
        nmap        s   <Plug>(vsnip-select-text)
        xmap        s   <Plug>(vsnip-select-text)
        nmap        S   <Plug>(vsnip-cut-text)
        xmap        S   <Plug>(vsnip-cut-text)

        " If you want to use snippet for multiple filetypes, you can `g:vsnip_filetypes` for it.
        let g:vsnip_filetypes = {}
        let g:vsnip_filetypes.javascriptreact = ['javascript']
        let g:vsnip_filetypes.typescriptreact = ['typescript']
    endif

    set background=dark
    " let g:gruvbox_contrast_dark='hard'
    if has_key(plugs, 'gruvbox')
        colorscheme gruvbox
    endif

    if has_key(plugs, 'nvim-lightbulb')
        autocmd CursorHold,CursorHoldI * lua require('nvim-lightbulb').update_lightbulb()
    endif

    if has_key(plugs, 'vim-quickui')
        " clear all the menus
        call quickui#menu#reset()

        call quickui#menu#install(
        \    '&Vim',
        \    [
        \       ["&Reload config", "source $MYVIMRC"],
        \       ["&Health", "checkhealth"],
        \       ["&LSP capabilities", "lua =vim.lsp.get_active_clients()[1].server_capabilities"],
        \       ["&LSP Info", "LspInfo"],
        \       ["&Error log", "messages"],
        \    ]
        \)

        if has_key(plugs, 'please.nvim') && executable('plz')
            call quickui#menu#install(
            \    '&Please',
            \    [
            \       ["&Show window\t<leader>pp", "lua require('please.runners.popup').restore()"],
            \       ["&Build\t<leader>pj", "lua require('please').build()"],
            \       ["&Test\t<leader>pt", "lua require('please').test()"],
            \       ["&Jump to target\t<leader>pj", "lua require('please').jump_to_target()"],
            \       ["&Test under cursor\t<leader>pct", "lua require('please').test({ under_cursor = true })"],
            \       ["&List tests\t<leader>plt", "lua require('please').test({ list = true })"],
            \       ["&List failed tests\t<leader>plt", "lua require('please').test({ failed = true })"],
            \       ["&Run\t<leader>pr", "lua require('please').run())"],
            \       ["&Yank\t<leader>py", "lua require('please').yank())"],
            \       ["&Debug\t<leader>pd", "lua require('please').debug()"],
            \       ["&Action history\t<leader>pa", "lua require('please').action_history())"],
            \    ]
            \)
        endif

        if has_key(plugs, 'fzf')
            call quickui#menu#install(
            \    '&Fuzzy search',
            \    [
            \       ["&Files\tff/", "ProjectFiles"],
            \       ["&File content\tfc/", "ProjectRg"],
            \       ["&Git files\t:GFiles", "GFiles"],
            \       ["&Git staged files\t:GFiles?", "GFiles?"],
            \       ["&Git commits\t:Commits [LOG_OPTS]", "Commits"],
            \       ["&Git commits (current buffer)\t:BCommits [LOG_OPTS]", "BCommits"],
            \       ["&Buffers\tBuffers:", "Buffers"],
            \       ["&Lines (all buffers)\t:Lines", "Lines"],
            \       ["&Lines (current buffer)\t:BLines", "BLines"],
            \       ["&Tags (project)\t:Tags", "Tags"],
            \       ["&Tags (current buffer)\t:BTags", "BTags"],
            \       ["&Colors\t:Colors", "Colors"],
            \       ["&Marks\t:Marks", "Marks"],
            \       ["&Windows\t:Windows", "Windows"],
            \       ["&Snippets\t:Snippets", "Snippets"],
            \       ["&Commands\t:Commands", "Commands"],
            \       ["&Maps\t:Maps", "Maps"],
            \       ["&Help tags\t:Helptags", "Helptags"],
            \       ["&File types\t:Filetypes", "Filetypes"],
            \       ["&Command history\t:History:", "History:"],
            \       ["&Old files and open buffers history\t:History", "History"],
            \       ["&Ripgrep\t:Rg [PATTERN]", "Rg"],
            \       ["&Locate\t:Locate [PATTERN]", "Locate"],
            \    ]
            \)
        endif

        call quickui#menu#install('Help (&?)', [
			\ ["&Index", 'tab help index', ''],
			\ ['Ti&ps', 'tab help tips', ''],
			\ ['--',''],
			\ ["&Tutorial", 'tab help tutor', ''],
			\ ['&Quick Reference', 'tab help quickref', ''],
			\ ['&Summary', 'tab help summary', ''],
			\ ['--',''],
			\ ['&Vim Script', 'tab help eval', ''],
			\ ['&Function List', 'tab help function-list', ''],
			\ ], 10000)

        noremap <leader>c :call quickui#context#open(
        \    [
        \       ["&Display hover\tK", "lua vim.lsp.buf.hover()"],
        \       ["&Jump to definition\tgd", "lua vim.lsp.buf.definition()"],
        \       ["&Jump to declaration\tgD", "lua vim.lsp.buf.declaration()"],
        \       ["&List implementations\tgi", "lua vim.lsp.buf.implementation()"],
        \       ["&Jumps to the definition of the type\tgo", "lua vim.lsp.buf.references()"],
        \       ["&Display signature\tgo", "lua vim.lsp.buf.signature_help()"],
        \       ["&Rename all references\t<F2>", "lua vim.lsp.buf.rename()"],
        \       ["&Format\t<F3>", "lua vim.lsp.buf.format()"],
        \       ["&Code action\t<F4>", "lua vim.lsp.buf.code_action()"],
        \       ["&Show diagnostics\tgl", "lua vim.diagnostic.open_float()"],
        \       ["&Previous diagnostics\t[d", "lua vim.diagnostic.goto_prev()"],
        \       ["&Next diagnostics\t]d", "lua vim.diagnostic.goto_next()"],
        \    ],
        \    {'index':g:quickui#context#cursor}
        \)<CR>

        noremap <leader>m :call quickui#menu#open()<CR>
    endif
endif

" Close preview window when done with completions
autocmd InsertLeave,CompleteDone * if pumvisible() == 0 | silent! pclose | endif

" Read custom after configuration
if filereadable($HOME . '/.vim/manual/after.vim')
    source <sfile>:h/.vim/manual/after.vim
endif
