-- For more information on configuring Luacheck, please visit
-- https://github.com/lunarmodules/luacheck

-- Luacheck configuration for Neovim

globals = {
  "describe",
  "it",
  "before_each",
  "after_each",
  "use",
  "vim",
  "vim.g",
  "vim.o",
  "vim.opt",
  "vim.b",
  "vim.bo",
  "vim.fn",
  "vim.api",
  "vim.lsp",
  "vim.ui",
  "vim.uv",
  "vim.cmd",
  "vim.keymap",
  "vim.diagnostic",
}

-- Allow defining globals in files that match the following patterns
allow_defined_top = true

-- stylua formats with column_width=80 as a soft guide,
-- but won't break single expressions (require(), long
-- function calls, etc.), producing lines up to ~120.
max_line_length = 120
