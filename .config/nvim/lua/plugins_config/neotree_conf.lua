require("neo-tree").setup(
  {
    source_selector = {
      winbar = true,
      statusline = false,
      tabs_layout = "equal",
      sources = {
        {
          source = "filesystem",
          display_name = " 󰉓 Files "
        },
        {
          source = "buffers",
          display_name = " 󰈚 Buffers "
        },
        {
          source = "git_status",
          display_name = " 󰊢 Git "
        },
        {
          source = "document_symbols",
          display_name = " 󰡱 Symbols "
        },
      }
    },
    sources = { "filesystem", "buffers", "git_status", "document_symbols" },
    filesystem = {
      follow_current_file = {
        enabled = true,
        leave_dirs_open = false,
      },
    },
    buffers = {
      follow_current_file = {
        enabled = true,
        leave_dirs_open = false,
      },
    },
  }
)

vim.keymap.set("n", "<Leader>nn", "<cmd>Neotree<CR>", { noremap = true, desc = "Neo Tree" })

-- TODO: decide what to do with netrw (which is also configured in nvimtree)
-- https://github.com/nvim-neo-tree/neo-tree.nvim/blob/main/doc/neo-tree.txt#L934
