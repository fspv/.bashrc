require("lualine").setup(
  {
    options = {
      disabled_filetypes = {
        statusline = { "ctrlp", "neo-tree" },
      },
    },
    sections = {
      lualine_a = {
        {
          'filename',
          file_status = true,
          path = 3
        }
      }
    }
  }
)
