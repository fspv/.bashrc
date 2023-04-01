-- nvim-tree doc: https://github.com/nvim-tree/nvim-tree.lua/blob/master/doc/nvim-tree-lua.txt
-- disable netrw at the very start of your init.lua (strongly advised)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- set termguicolors to enable highlight groups
vim.opt.termguicolors = true

-- empty setup using defaults
require("nvim-tree").setup()

-- OR setup with some options
require("nvim-tree").setup({
    sort_by = "case_sensitive",
    hijack_cursor = true,
    reload_on_bufenter = true,
    view = {
        adaptive_size = true,
        width = {
            max = 100,
        },
    },
    renderer = {
        full_name = true,
        group_empty = false,
        special_files = {},
        highlight_git = true,
        indent_markers = {
            enable = true,
        },
        icons = {
            git_placement = "signcolumn",
            show = {
                file = true,
                folder = true,
                folder_arrow = true,
                git = true,
            },
        },
    },
    update_focused_file = {
        enable = true,
        update_root = true,
        ignore_list = {},
    },
    tab = {
        sync = {
            open = true,
        },
    },
    filesystem_watchers = {
        enable = false,
    },
    diagnostics = {
        enable = true,
    },
})
