vim.keymap.set('n', '<leader>pj', require('please').jump_to_target, { desc = "Please Jump to Target" })
vim.keymap.set('n', '<leader>pb', require('please').build, { desc = "Please Build" })
vim.keymap.set('n', '<leader>pt', require('please').test, { desc = "Please Test" })
vim.keymap.set('n', '<leader>pct', function()
  require('please').test({ under_cursor = true }, { desc = "Please Test Under Cursor" })
end, { desc = "" })
vim.keymap.set('n', '<leader>plt', function()
  require('please').test({ list = true }, { desc = "Please List Tests" })
end, { desc = "" })
vim.keymap.set('n', '<leader>pft', function()
  require('please').test({ failed = true }, { desc = "Please List Failed Tests" })
end, { desc = "" })
vim.keymap.set('n', '<leader>pr', require('please').run, { desc = "Please Run" })
vim.keymap.set('n', '<leader>py', require('please').yank, { desc = "Please Yank" })
vim.keymap.set('n', '<leader>pd', require('please').debug, { desc = "Please Debug" })
vim.keymap.set('n', '<leader>pa', require('please').action_history, { desc = "Please Action History" })
vim.keymap.set('n', '<leader>pp', require('please.runners.popup').restore, { desc = "Please Restore Window" })

-- TODO: port to lua
vim.cmd(
  [[
    if executable('plz')
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
]]
)
