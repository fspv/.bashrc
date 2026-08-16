-- Neovim calls root_dir as fun(bufnr, on_dir). The lspconfig-era
-- fun(startpath) that returns the root still loads without error and is not
-- rejected by the type checker, it just silently never attaches the server.
-- Compare the declared parameter count so CI catches the stale signature.

require("lazy").install({ wait = true })

-- The lsp configs live in a lazy-loaded plugin config, so nothing is
-- registered until every plugin is loaded.
require("lazy").load({
  plugins = vim.tbl_keys(require("lazy.core.config").plugins),
})

---@diagnostic disable-next-line: invisible
local configs = vim.lsp.config._configs --[[@as table<string, vim.lsp.Config>]]

if vim.tbl_count(configs) == 0 then
  print("FAIL: no lsp configs registered, this check would pass vacuously")
  vim.cmd("cquit 1")
  return
end

local invalid = {}

for name, config in pairs(configs) do
  local root_dir = config.root_dir
  if type(root_dir) == "function" then
    local info = debug.getinfo(root_dir, "u")
    if not info.isvararg and info.nparams ~= 2 then
      table.insert(invalid, { name = name, nparams = info.nparams })
    end
  end
end

if #invalid == 0 then
  print(
    string.format(
      "OK: %d lsp config(s) checked, root_dir signatures valid",
      vim.tbl_count(configs)
    )
  )
  vim.cmd("quit")
  return
end

print(
  string.format(
    "FAIL: %d root_dir function(s) with a stale signature",
    #invalid
  )
)
for _, config in ipairs(invalid) do
  print(
    string.format(
      "\n  %s: root_dir takes %d parameter(s), expected 2 (bufnr, on_dir)",
      config.name,
      config.nparams
    )
  )
end
vim.cmd("cquit 1")
