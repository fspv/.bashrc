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

-- Set the maximum line length
max_line_length = 80
max_comment_line_length = false
max_string_line_length = false
max_code_line_length = false
max_cyclomatic_complexity = false

-- Set the minimum name length
min_name_length = 2

-- Set the maximum number of arguments in a function
max_args = 10

-- Set the maximum number of locals in a function
max_locals = 200

-- Set the maximum number of upvalues in a function
max_upvalues = 60

unused = false
unused_args = false
