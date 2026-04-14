-- ============================================================================
-- Native treesitter parser installer.
--
-- Replaces the archived nvim-treesitter plugin with a minimal in-place
-- installer:
--   1. Clone parser sources from upstream tree-sitter repos
--   2. Compile parser.c (+ scanner.{c,cc} if present) into <lang>.so
--   3. Copy upstream queries into runtimepath
--   4. Prepend the install dir to runtimepath so vim.treesitter finds them
--
-- Installs run asynchronously via vim.system(); the smoke test waits up to
-- 120s for parsers to become loadable.
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

    local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(ev.buf))

    if ok and stats and stats.size > max_filesize then
      return
    end

    vim.treesitter.start(ev.buf)
  end,
})

local M = {}

---@class ParserSpec
---@field url string Git URL to clone from
---@field location string|nil Subdirectory inside the repo (for monorepos)

---@type table<string, ParserSpec>
M.parsers = {
  bash = { url = "https://github.com/tree-sitter/tree-sitter-bash" },
  c = { url = "https://github.com/tree-sitter/tree-sitter-c" },
  go = { url = "https://github.com/tree-sitter/tree-sitter-go" },
  lua = { url = "https://github.com/tree-sitter-grammars/tree-sitter-lua" },
  markdown = {
    url = "https://github.com/tree-sitter-grammars/tree-sitter-markdown",
    location = "tree-sitter-markdown",
  },
  markdown_inline = {
    url = "https://github.com/tree-sitter-grammars/tree-sitter-markdown",
    location = "tree-sitter-markdown-inline",
  },
  proto = { url = "https://github.com/mitchellh/tree-sitter-proto" },
  python = { url = "https://github.com/tree-sitter/tree-sitter-python" },
  rust = { url = "https://github.com/tree-sitter/tree-sitter-rust" },
}

-- ensure_installed lists the language ids the smoke test verifies.
M.ensure_installed = vim.tbl_keys(M.parsers)
table.sort(M.ensure_installed)

-- zsh files use the bash treesitter parser. Avoids a duplicate parser binary.
pcall(vim.treesitter.language.register, "bash", "zsh")

local install_dir = vim.fn.stdpath("data") .. "/treesitter"
local parser_dir = install_dir .. "/parser"
local queries_dir = install_dir .. "/queries"
local repos_dir = install_dir .. "/repos"

vim.fn.mkdir(parser_dir, "p")
vim.fn.mkdir(queries_dir, "p")
vim.fn.mkdir(repos_dir, "p")

vim.opt.runtimepath:prepend(install_dir)

---@param msg string
---@param level integer|nil
local function log(msg, level)
  vim.schedule(function()
    vim.notify("[treesitter] " .. msg, level or vim.log.levels.DEBUG)
  end)
end

-- Deduplicate clones when multiple parsers share a repo (e.g. markdown +
-- markdown_inline both live in tree-sitter-markdown).
---@type table<string, fun(repo_dir: string|nil)[]>
local clone_callbacks = {}

---@param url string
---@param on_done fun(repo_dir: string|nil)
local function ensure_repo(url, on_done)
  local repo_dir = repos_dir .. "/" .. vim.fn.sha256(url):sub(1, 16)

  if vim.uv.fs_stat(repo_dir) then
    on_done(repo_dir)
    return
  end

  if clone_callbacks[url] then
    table.insert(clone_callbacks[url], on_done)
    return
  end
  clone_callbacks[url] = { on_done }

  log("cloning " .. url)
  vim.system({
    "git",
    "clone",
    "--depth",
    "1",
    "--quiet",
    url,
    repo_dir,
  }, { text = true }, function(result)
    vim.schedule(function()
      local cbs = clone_callbacks[url] or {}
      clone_callbacks[url] = nil
      if result.code ~= 0 then
        log(
          "clone failed for " .. url .. ": " .. (result.stderr or ""),
          vim.log.levels.ERROR
        )
        for _, cb in ipairs(cbs) do
          cb(nil)
        end
        return
      end
      for _, cb in ipairs(cbs) do
        cb(repo_dir)
      end
    end)
  end)
end

---@param src string
---@param dst string
---@return boolean
local function copy_file(src, dst)
  local infile = io.open(src, "rb")
  if not infile then
    return false
  end
  local content = infile:read("*a")
  infile:close()
  local outfile = io.open(dst, "wb")
  if not outfile then
    return false
  end
  outfile:write(content)
  outfile:close()
  return true
end

---@param source_dir string
---@param lang string
local function install_queries(source_dir, lang)
  local queries_src = source_dir .. "/queries"
  if not vim.uv.fs_stat(queries_src) then
    return
  end
  local queries_dest = queries_dir .. "/" .. lang
  vim.fn.mkdir(queries_dest, "p")
  for _, file in ipairs(vim.fn.glob(queries_src .. "/*.scm", false, true)) do
    local basename = vim.fn.fnamemodify(file, ":t")
    copy_file(file, queries_dest .. "/" .. basename)
  end
end

---@param lang string
---@param spec ParserSpec
---@param repo_dir string
local function build_parser(lang, spec, repo_dir)
  local source_dir = repo_dir
  if spec.location then
    source_dir = repo_dir .. "/" .. spec.location
  end
  local src = source_dir .. "/src"
  local parser_c = src .. "/parser.c"
  if not vim.uv.fs_stat(parser_c) then
    log("no parser.c found for " .. lang, vim.log.levels.ERROR)
    return
  end

  local has_c = vim.uv.fs_stat(src .. "/scanner.c") ~= nil
  local has_cc = vim.uv.fs_stat(src .. "/scanner.cc") ~= nil
  local compiler = has_cc and "c++" or "cc"
  local parser_so = parser_dir .. "/" .. lang .. ".so"

  ---@type string[]
  local args = {
    compiler,
    "-o",
    parser_so,
    "-shared",
    "-Os",
    "-fPIC",
    "-I",
    src,
    parser_c,
  }
  if has_c then
    table.insert(args, src .. "/scanner.c")
  end
  if has_cc then
    table.insert(args, src .. "/scanner.cc")
  end

  log("building " .. lang)
  vim.system(args, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        log(
          "build failed for " .. lang .. ": " .. (result.stderr or ""),
          vim.log.levels.ERROR
        )
        return
      end
      install_queries(source_dir, lang)
      log("installed " .. lang)
    end)
  end)
end

---@param lang string
---@param spec ParserSpec
local function install_parser(lang, spec)
  local parser_so = parser_dir .. "/" .. lang .. ".so"
  if vim.uv.fs_stat(parser_so) then
    return
  end
  ensure_repo(spec.url, function(repo_dir)
    if not repo_dir then
      return
    end
    build_parser(lang, spec, repo_dir)
  end)
end

vim.schedule(function()
  for lang, spec in pairs(M.parsers) do
    install_parser(lang, spec)
  end
end)

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
