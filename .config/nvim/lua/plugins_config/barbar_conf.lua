-- Move to previous/next
local opts = { noremap = true, silent = true }
vim.api.nvim_set_keymap('n', 'gT', '<Cmd>BufferPrevious<CR>', opts)
vim.api.nvim_set_keymap('n', 'gt', '<Cmd>BufferNext<CR>', opts)

vim.api.nvim_create_autocmd('FileType', {
    callback = function(tbl)
        local set_offset = require('barbar.api').set_offset

        local bufwinid
        local last_width
        local autocmd = vim.api.nvim_create_autocmd('WinScrolled', {
            callback = function()
                bufwinid = bufwinid or vim.fn.bufwinid(tbl.buf)

                local width = vim.api.nvim_win_get_width(bufwinid)
                if width ~= last_width then
                    set_offset(width, 'FileTree')
                    last_width = width
                end
            end,
        })

        vim.api.nvim_create_autocmd('BufWipeout', {
            buffer = tbl.buf,
            callback = function()
                vim.api.nvim_del_autocmd(autocmd)
                set_offset(0)
            end,
            once = true,
        })
    end,
    pattern = 'NvimTree', -- or any other filetree's `ft`
})
