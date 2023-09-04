-- TODO: port to lua
vim.cmd(
  [[
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
]]
)
