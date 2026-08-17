-- ============================================================================
-- Parsers and queries are provided pre-built in NEOVIM_TREESITTER_PATH, a
-- runtimepath directory with `parser/<lang>.so` and `queries/<lang>/*.scm`.
-- ============================================================================

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

    -- Starting treesitter without highlights would only clear 'syntax'.
    if not vim.treesitter.query.get(lang, "highlights") then
      return
    end

    local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(ev.buf))

    if ok and stats and stats.size > max_filesize then
      return
    end

    vim.treesitter.start(ev.buf)
  end,
})

local M = {}

local treesitter_path = assert(os.getenv("NEOVIM_TREESITTER_PATH"))

-- Globbing with nosuf, because 'wildignore' from vimrc excludes *.so.
---@type string[]
M.ensure_installed = vim.tbl_map(function(parser)
  return vim.fn.fnamemodify(parser, ":t:r")
end, vim.fn.glob(treesitter_path .. "/parser/*.so", true, true))

-- Filetype-to-language registrations, e.g. `cs` -> `c_sharp`.
dofile(treesitter_path .. "/filetypes.lua")

-- zsh files use the bash treesitter parser. Avoids a duplicate parser binary.
pcall(vim.treesitter.language.register, "bash", "zsh")

-- Appended, so neovim's own bundled parsers and queries keep priority.
vim.opt.runtimepath:append(treesitter_path)

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
