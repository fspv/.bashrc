require("lualine").setup(
  {
    options = {
      disabled_filetypes = {
        statusline = { "ctrlp", "neo-tree" },
      },
    },
    tabline = {},
    winbar = {},
    sections = {
      lualine_a = {
        {
          'filename',
          file_status = true,
          path = 3,
          on_click = function()
            vim.cmd("Neotree toggle")
          end,
        },
        {
          "lsp_progress",
        },
      },
      lualine_b = {
        {
          "branch",
          on_click = function()
            vim.cmd("G")
          end,
        },
        {
          "diff",
          on_click = function()
            vim.cmd("Gdiffsplit")
          end,
        },
        {
          "diagnostics",
          on_click = function()
            vim.cmd("Trouble document_diagnostics")
          end,
        }
      }
    }
  }
)
