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
"set listchars=tab:··
"set listchars=tab:»\ ,trail:·,eol:¶
"set list

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
        Plug 'airblade/vim-rooter' " Automatically detect project root
        " Plug 'neoclide/coc.nvim', {'branch': 'release'}
        Plug 'dense-analysis/ale' " Linting, formatting
        Plug 'junegunn/fzf', { 'do': { -> fzf#install() } } " fuzzy search
        Plug 'junegunn/fzf.vim' " fuzzy search 2
        Plug 'ntpeters/vim-better-whitespace' " Highlight trailing whitespace
        Plug 'raimondi/delimitMate' " Auto-complete matching quotes, brackets, etc
        Plug 'scrooloose/nerdtree' " Graphical file manager
        Plug 'tpope/vim-sensible' " Universally good defaults
        Plug 'tpope/vim-speeddating' " Use ctrl-a and ctrl-x to increment/decrement times/dates
        Plug 'vim-scripts/PreserveNoEOL' " Omit the final newline of a file if it wasn't present when we opened it
        " if filereadable(python3_host_prog)
        "     Plug 'shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }  " Completion
        " endif
        " Plug 'deoplete-plugins/deoplete-jedi' " Another way to have completion (pyls default)
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

        Plug 'hrsh7th/cmp-vsnip'
        Plug 'hrsh7th/vim-vsnip'
        Plug 'hrsh7th/vim-vsnip-integ'

        Plug 'golang/vscode-go'
        Plug 'microsoft/vscode-python'

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
        Plug 'antoinemadec/FixCursorHold.nvim'
        Plug 'weilbith/nvim-code-action-menu'

        Plug 'skywind3000/vim-quickui'
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
            \   fzf#vim#with_preview({'dir': FindRootDirectory(), 'options': '--delimiter : --nth 4..'}),
            \   <bang>0
            \ )

        map ff/ :ProjectFiles<CR>
        map fc/ :ProjectRg<CR>
    endif

    if has_key(plugs, 'coc.nvim')
        " COC
        " Use tab for trigger completion with characters ahead and navigate.
        " NOTE: There's always complete item selected by default, you may want to enable
        " no select by `"suggest.noselect": true` in your configuration file.
        " NOTE: Use command ':verbose imap <tab>' to make sure tab is not mapped by
        " other plugin before putting this into your config.
        inoremap <silent><expr> <TAB>
              \ coc#pum#visible() ? coc#pum#next(1) :
              \ CheckBackspace() ? "\<Tab>" :
              \ coc#refresh()
        inoremap <expr><S-TAB> coc#pum#visible() ? coc#pum#prev(1) : "\<C-h>"

        " Make <CR> to accept selected completion item or notify coc.nvim to format
        " <C-g>u breaks current undo, please make your own choice.
        inoremap <silent><expr> <CR> coc#pum#visible() ? coc#pum#confirm()
                                      \: "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"

        function! CheckBackspace() abort
          let col = col('.') - 1
          return !col || getline('.')[col - 1]  =~# '\s'
        endfunction

        " Use <c-space> to trigger completion.
        if has('nvim')
          inoremap <silent><expr> <c-space> coc#refresh()
        else
          inoremap <silent><expr> <c-@> coc#refresh()
        endif

        " Use `[g` and `]g` to navigate diagnostics
        " Use `:CocDiagnostics` to get all diagnostics of current buffer in location list.
        nmap <silent> [g <Plug>(coc-diagnostic-prev)
        nmap <silent> ]g <Plug>(coc-diagnostic-next)

        " GoTo code navigation.
        nmap <silent> gd <Plug>(coc-definition)
        nmap <silent> gy <Plug>(coc-type-definition)
        nmap <silent> gi <Plug>(coc-implementation)
        nmap <silent> gr <Plug>(coc-references)

        " Use K to show documentation in preview window.
        nnoremap <silent> K :call ShowDocumentation()<CR>

        function! ShowDocumentation()
          if CocAction('hasProvider', 'hover')
            call CocActionAsync('doHover')
          else
            call feedkeys('K', 'in')
          endif
        endfunction

        " Highlight the symbol and its references when holding the cursor.
        autocmd CursorHold * silent call CocActionAsync('highlight')

        " Symbol renaming.
        nmap <leader>rn <Plug>(coc-rename)

        " Formatting selected code.
        xmap <leader>f  <Plug>(coc-format-selected)
        nmap <leader>f  <Plug>(coc-format-selected)

        " Applying codeAction to the selected region.
        " Example: `<leader>aap` for current paragraph
        xmap <leader>a  <Plug>(coc-codeaction-selected)
        nmap <leader>a  <Plug>(coc-codeaction-selected)

        " Remap keys for applying codeAction to the current buffer.
        nmap <leader>ac  <Plug>(coc-codeaction)
        " Apply AutoFix to problem on the current line.
        nmap <leader>qf  <Plug>(coc-fix-current)

        " Run the Code Lens action on the current line.
        nmap <leader>cl  <Plug>(coc-codelens-action)

        " Map function and class text objects
        " NOTE: Requires 'textDocument.documentSymbol' support from the language server.
        xmap if <Plug>(coc-funcobj-i)
        omap if <Plug>(coc-funcobj-i)
        xmap af <Plug>(coc-funcobj-a)
        omap af <Plug>(coc-funcobj-a)
        xmap ic <Plug>(coc-classobj-i)
        omap ic <Plug>(coc-classobj-i)
        xmap ac <Plug>(coc-classobj-a)
        omap ac <Plug>(coc-classobj-a)

        " Remap <C-f> and <C-b> for scroll float windows/popups.
        if has('nvim-0.4.0') || has('patch-8.2.0750')
          nnoremap <silent><nowait><expr> <C-f> coc#float#has_scroll() ? coc#float#scroll(1) : "\<C-f>"
          nnoremap <silent><nowait><expr> <C-b> coc#float#has_scroll() ? coc#float#scroll(0) : "\<C-b>"
          inoremap <silent><nowait><expr> <C-f> coc#float#has_scroll() ? "\<c-r>=coc#float#scroll(1)\<cr>" : "\<Right>"
          inoremap <silent><nowait><expr> <C-b> coc#float#has_scroll() ? "\<c-r>=coc#float#scroll(0)\<cr>" : "\<Left>"
          vnoremap <silent><nowait><expr> <C-f> coc#float#has_scroll() ? coc#float#scroll(1) : "\<C-f>"
          vnoremap <silent><nowait><expr> <C-b> coc#float#has_scroll() ? coc#float#scroll(0) : "\<C-b>"
        endif

        " Use CTRL-S for selections ranges.
        " Requires 'textDocument/selectionRange' support of language server.
        nmap <silent> <C-s> <Plug>(coc-range-select)
        xmap <silent> <C-s> <Plug>(coc-range-select)

        " Add `:Format` command to format current buffer.
        command! -nargs=0 Format :call CocActionAsync('format')

        " Add `:Fold` command to fold current buffer.
        command! -nargs=? Fold :call     CocAction('fold', <f-args>)

        " Add `:OR` command for organize imports of the current buffer.
        command! -nargs=0 OR   :call     CocActionAsync('runCommand', 'editor.action.organizeImport')

        " Add (Neo)Vim's native statusline support.
        " NOTE: Please see `:h coc-status` for integrations with external plugins that
        " provide custom statusline: lightline.vim, vim-airline.
        set statusline^=%{coc#status()}%{get(b:,'coc_current_function','')}

        " Mappings for CoCList
        " Show all diagnostics.
        nnoremap <silent><nowait> <space>a  :<C-u>CocList diagnostics<cr>
        " Manage extensions.
        nnoremap <silent><nowait> <space>e  :<C-u>CocList extensions<cr>
        " Show commands.
        nnoremap <silent><nowait> <space>c  :<C-u>CocList commands<cr>
        " Find symbol of current document.
        nnoremap <silent><nowait> <space>o  :<C-u>CocList outline<cr>
        " Search workspace symbols.
        nnoremap <silent><nowait> <space>s  :<C-u>CocList -I symbols<cr>
        " Do default action for next item.
        nnoremap <silent><nowait> <space>j  :<C-u>CocNext<CR>
        " Do default action for previous item.
        nnoremap <silent><nowait> <space>k  :<C-u>CocPrev<CR>
        " Resume latest coc list.
        nnoremap <silent><nowait> <space>p  :<C-u>CocListResume<CR>

        " Sort python imports on save
        autocmd BufWrite *.py :CocCommand python.sortImports
    endif

    if has_key(plugs, 'ale')
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
        let g:ale_linters = {
        \   'python': ['flake8', 'mypy', 'pylint', 'bandit', 'pyls', 'pylsp', 'pyre', 'jedils'],
        \   'rust': ['analyzer', 'cargo', 'rls'],
        \   'sql': ['sqlfluff']
        \}

        function ALEDetectArcanist()
            " Add a fixer for arcanist https://github.com/phacility/arcanist
            if executable('arc') && filereadable(FindRootDirectory() . '/.arclint')
                let g:ale_fixers = {
                \   'python': [],
                \   'go': []
                \}
                au BufWritePost *.py,*.go,BUILD,*.build_def,*.build_defs exec '!arc lint --apply-patches' shellescape(expand('%:p'), 1)
            else
                let g:ale_fixers = {
                \   'python': ['black', 'isort'],
                \   'cpp': ['astyle', 'clang-format', 'clangtidy', 'remove_trailing_lines', 'trim_whitespace', 'uncrustify'],
                \   'sql': ['pgformatter'],
                \   'rust': ['rustfmt'],
                \   'go': ['gofmt', 'goimports', 'golines', 'remove_trailing_lines', 'trim_whitespace']
                \}
            endif
        endfunction

        autocmd VimEnter * call ALEDetectArcanist()

        function ALEDetectFlake8Config()
            let flake8_config = FindRootDirectory() . '/.flake8'
            if filereadable(flake8_config)
                let g:ale_python_flake8_options = '--config=' . flake8_config
            else
                let g:ale_python_flake8_options = '--config=$HOME/.config/flake8'
            endif
        endfunction

        autocmd VimEnter * call ALEDetectFlake8Config()

        let g:ale_python_pylsp_executable = "pylsp"

        let g:ale_python_pylsp_config = {
        \   'pylsp': {
        \     'configurationSources': ['flake8'],
        \     'plugins': {
        \       'flake8': {
        \         'enabled': v:true,
        \       },
        \       'pycodestyle': {
        \         'enabled': v:false,
        \       },
        \       'mccabe': {
        \         'enabled': v:false,
        \       },
        \       'pyflakes': {
        \         'enabled': v:false,
        \       },
        \       'pydocstyle': {
        \         'enabled': v:false,
        \       },
        \     },
        \   },
        \}

        let g:ale_fix_on_save = 1
        " let g:ale_float_preview = 1
        let g:ale_floating_preview = 1
        let g:ale_floating_window_border = []
        let g:ale_close_preview_on_insert = 1
        let g:ale_completion_enabled = 0
        " let g:ale_hover_to_preview = 1
        " let g:ale_hover_to_floating_preview = 1
        let g:ale_cursor_detail = 1
        " let g:ale_detail_to_floating_preview = 1
        " let g:ale_list_window_size = 10
        " let g:ale_set_balloons = 1
        "
        let g:ale_completion_autoimport = 1
        let g:ale_keep_list_window_open = 0
        let g:ale_set_loclist = 0
        let g:ale_open_list = 0
        let g:ale_virtualtext_cursor = 2

        augroup ale_hover_cursor
          autocmd!
          autocmd CursorHold * ALEHover
        augroup END

        if has_key(plugs, 'deoplete.nvim')
            " Deoplete + ALE
            if filereadable(python3_host_prog)
                let g:deoplete#enable_at_startup = 0
                call deoplete#custom#source('ale', 'rank', 999)
                call deoplete#custom#source('_', 'matchers', ['matcher_full_fuzzy'])
            endif
        endif
    endif

    " NERDTree
    " Start NERDTree. If a file is specified, move the cursor to its window.
    " autocmd StdinReadPre * let s:std_in=1
    " autocmd VimEnter * NERDTree | if argc() > 0 || exists("s:std_in") | wincmd p | endif

    " Exit Vim if NERDTree is the only window left.
    autocmd BufEnter * if tabpagenr('$') == 1 && winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isTabTree() |
        \ quit | endif

    let NERDTreeRespectWildIgnore = 1

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
        " automatic import management
        let g:go_fmt_command = "goimports"
        " syntax highlighting
        let g:go_highlight_fields = 1
        let g:go_highlight_functions = 1
        let g:go_highlight_function_calls = 1
        let g:go_highlight_extra_types = 1
        " status bar
        let g:go_auto_type_info = 1
        " matching identifiers
        let g:go_auto_sameids = 1
    endif

    if has_key(plugs, 'please.nvim') && executable('plz')
        function DetectPlz()
            if filereadable(FindRootDirectory() . '/.plzconfig')
                au BufWritePost *.go exec '!plz update-go-targets' shellescape(expand('%:p:h'), 1)
                au BufRead,BufNewFile BUILD,*.build_def set filetype=please
                au BufRead,BufNewFile BUILD,*.build_def,*.build_defs set syntax=python
            endif
        endfunction
        autocmd VimEnter *.go call DetectPlz()

        lua <<EOF
            vim.keymap.set('n', '<leader>pj', require('please').jump_to_target)
            vim.keymap.set('n', '<leader>pb', require('please').build)
            vim.keymap.set('n', '<leader>pt', require('please').test)
            vim.keymap.set('n', '<leader>pct', function()
            require('please').test({ under_cursor = true })
            end)
            vim.keymap.set('n', '<leader>plt', function()
            require('please').test({ list = true })
            end)
            vim.keymap.set('n', '<leader>pft', function()
            require('please').test({ failed = true })
            end)
            vim.keymap.set('n', '<leader>pr', require('please').run)
            vim.keymap.set('n', '<leader>py', require('please').yank)
            vim.keymap.set('n', '<leader>pd', require('please').debug)
            vim.keymap.set('n', '<leader>pa', require('please').action_history)
            vim.keymap.set('n', '<leader>pp', require('please.runners.popup').restore)
EOF
    endif

    if has_key(plugs, 'nvim-lspconfig') && has_key(plugs, 'nvim-cmp') && has_key(plugs, 'cmp-vsnip')
        lua <<EOF
          require("lspconfig").pylsp.setup{
            settings = {
              pylsp = {
                configurationSources = {"flake8"},
                plugins = {
                  flake8 = {
                    enabled = true
                  },
                  pycodestyle = {
                    enabled = false
                  },
                  mccabe = {
                    enabled = false
                  },
                  pyflakes = {
                    enabled = false
                  },
                  pydocstyle = {
                    enabled = false
                  }
                }
              }
            }
          }
          require("lspconfig").gopls.setup{}
          require("lspconfig").clangd.setup{}
          require("lspconfig").rust_analyzer.setup{}

          vim.lsp.handlers['textDocument/hover'] = function(_, method, result)
          vim.lsp.util.focusable_float(method, function()
              if not (result and result.contents) then
                -- return { 'No information available' }
                return
              end
              local markdown_lines = vim.lsp.util.convert_input_to_markdown_lines(result.contents)
              markdown_lines = vim.lsp.util.trim_empty_lines(markdown_lines)
              if vim.tbl_isempty(markdown_lines) then
                -- return { 'No information available' }
                return
              end
              local bufnr, winnr = vim.lsp.util.fancy_floating_markdown(markdown_lines, {
                pad_left = 1; pad_right = 1;
              })
              vim.lsp.util.close_preview_autocmd({"CursorMoved", "BufHidden"}, winnr)
              return bufnr, winnr
            end)
          end

          -- Set up nvim-cmp.
          local cmp = require'cmp'

          cmp.setup({
            snippet = {
              -- REQUIRED - you must specify a snippet engine
              expand = function(args)
                vim.fn["vsnip#anonymous"](args.body) -- For `vsnip` users.
                -- require('luasnip').lsp_expand(args.body) -- For `luasnip` users.
                -- require('snippy').expand_snippet(args.body) -- For `snippy` users.
                -- vim.fn["UltiSnips#Anon"](args.body) -- For `ultisnips` users.
              end,
            },
            window = {
              -- completion = cmp.config.window.bordered(),
              -- documentation = cmp.config.window.bordered(),
            },
            mapping = cmp.mapping.preset.insert({
              ['<C-b>'] = cmp.mapping.scroll_docs(-4),
              ['<C-f>'] = cmp.mapping.scroll_docs(4),
              ['<C-Space>'] = cmp.mapping.complete(),
              ['<C-e>'] = cmp.mapping.abort(),
              ['<CR>'] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
            }),
            sources = cmp.config.sources({
              { name = 'nvim_lsp' },
              { name = 'vsnip' }, -- For vsnip users.
              -- { name = 'luasnip' }, -- For luasnip users.
              -- { name = 'ultisnips' }, -- For ultisnips users.
              -- { name = 'snippy' }, -- For snippy users.
            }, {
              { name = 'buffer' },
            })
          })

          -- Set configuration for specific filetype.
          cmp.setup.filetype('gitcommit', {
            sources = cmp.config.sources({
              { name = 'cmp_git' }, -- You can specify the `cmp_git` source if you were installed it.
            }, {
              { name = 'buffer' },
            })
          })

          -- Use buffer source for `/` and `?` (if you enabled `native_menu`, this won't work anymore).
          cmp.setup.cmdline({ '/', '?' }, {
            mapping = cmp.mapping.preset.cmdline(),
            sources = {
              { name = 'buffer' }
            }
          })

          -- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
          cmp.setup.cmdline(':', {
            mapping = cmp.mapping.preset.cmdline(),
            sources = cmp.config.sources({
              { name = 'path' }
            }, {
              { name = 'cmdline' }
            })
          })

          -- Set up lspconfig.
          local capabilities = require('cmp_nvim_lsp').default_capabilities()


          -- lsp_signature plugin
          require "lsp_signature".setup({})
EOF

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
            \       ["&Debug\t<leader>pd", "lua require('please').debug())"],
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

        noremap <leader>m :call quickui#menu#open()<cr>
    endif
endif

" Close preview window when done with completions
autocmd InsertLeave,CompleteDone * if pumvisible() == 0 | silent! pclose | endif

" Read custom after configuration
if filereadable($HOME . '/.vim/manual/after.vim')
    source <sfile>:h/.vim/manual/after.vim
endif
