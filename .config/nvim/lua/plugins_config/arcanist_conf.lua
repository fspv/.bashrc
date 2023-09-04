-- TODO: port to lua
vim.cmd(
  [[
    function EnableArcanistAutoformat()
        " Add a fixer for arcanist https://github.com/phacility/arcanist
        if executable('arc') && filereadable(FindRootDirectory() . '/.arclint')
            " TODO: check if it overwrites other commands
            au BufWritePost *.py,*.go,BUILD,*.build_def,*.build_defs exec '!arc lint --apply-patches' shellescape(expand('%:p'), 1)
        endif
    endfunction

    autocmd VimEnter * call EnableArcanistAutoformat()
]]
)
