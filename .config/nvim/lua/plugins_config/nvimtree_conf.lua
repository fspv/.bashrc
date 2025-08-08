-- TODO: port to lua
vim.cmd([[
    " NvimTree
    " Remap gx, because nvim tree hijacks netrw
    function! OpenURLUnderCursor()
      let s:uri = matchstr(shellescape(expand('<cWORD>')),
        \ "[a-z]*:\/\/[^ >,;'" .. '"' .. "]*")
      echo s:uri
      if s:uri != ""
        silent exec "!xdg-open '".s:uri."'"
      else
        echo "No URI found in line."
      endif
    endfunction
    nnoremap <silent> gx :call OpenURLUnderCursor()<cr>
]])

-- nvim-tree doc:
-- https://github.com/nvim-tree/nvim-tree.lua/blob/master/doc/nvim-tree-lua.txt
-- disable netrw at the very start of your init.lua (strongly advised)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- set termguicolors to enable highlight groups
vim.opt.termguicolors = true

-- OR setup with some options
require("nvim-tree").setup({
  sort_by = "case_sensitive",
  hijack_cursor = true,
  reload_on_bufenter = false,
  prefer_startup_root = true,
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
  diagnostics = {
    enable = true,
  },
  filesystem_watchers = {
    enable = false,
    ignore_dirs = {
      "node_modules",
      "plz-out",
    },
  },
})
