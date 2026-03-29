-- This is a workaround to prevent an error when we open file with an existing
-- .swp file.
-- https://github.com/neovim/neovim/issues/26192
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("treesitter", {}),
  callback = function(ev)
    local max_filesize = 500 * 1024 -- 500 KB
    local lang = vim.treesitter.language.get_lang(ev.match) or ev.match

    local has_parser = pcall(vim.treesitter.language.inspect, lang)
    if not has_parser then
      return
    end

    local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(ev.buf))

    if ok and stats and stats.size > max_filesize then
      return
    end

    vim.treesitter.start(ev.buf)
  end,
})

-- Install parsers that we want available
local M = {}

M.ensure_installed = {
  "bash",
  "c",
  "go",
  "lua",
  "markdown",
  "markdown_inline",
  "proto",
  "python",
  "rust",
  "zsh",
}

require("nvim-treesitter").install(M.ensure_installed)

-- Textobjects config (handled by nvim-treesitter-textobjects)
require("nvim-treesitter-textobjects").setup({
  move = {
    enable = true,
    set_jumps = true,
    goto_next_start = {
      ["]m"] = "@function.outer",
      ["]]"] = { query = "@class.outer", desc = "Next class start" },
      ["]o"] = "@loop.*",
      ["]s"] = {
        query = "@scope",
        query_group = "locals",
        desc = "Next scope",
      },
      ["]z"] = {
        query = "@fold",
        query_group = "folds",
        desc = "Next fold",
      },
    },
    goto_next_end = {
      ["]M"] = "@function.outer",
      ["]["] = "@class.outer",
    },
    goto_previous_start = {
      ["[m"] = "@function.outer",
      ["[["] = "@class.outer",
    },
    goto_previous_end = {
      ["[M"] = "@function.outer",
      ["[]"] = "@class.outer",
    },
  },
})

-- Manual incremental selection (replaced the removed nvim-treesitter module)
local node_stack = {}

local function select_node(node)
  local sr, sc, er, ec = node:range()
  vim.fn.setpos("'<", { 0, sr + 1, sc + 1, 0 })
  vim.fn.setpos("'>", { 0, er + 1, ec, 0 })
  vim.cmd("normal! gv")
end

vim.keymap.set("n", "<CR>", function()
  local node = vim.treesitter.get_node()
  if not node then
    return
  end
  node_stack = { node }
  select_node(node)
end, { desc = "Init treesitter selection" })

vim.keymap.set("x", "<CR>", function()
  local node = node_stack[#node_stack]
  if not node then
    return
  end
  local parent = node:parent()
  if parent then
    table.insert(node_stack, parent)
    select_node(parent)
  end
end, { desc = "Increment treesitter selection" })

vim.keymap.set("x", "<BS>", function()
  if #node_stack <= 1 then
    return
  end
  table.remove(node_stack)
  select_node(node_stack[#node_stack])
end, { desc = "Decrement treesitter selection" })

return M
