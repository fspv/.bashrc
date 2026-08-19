-- Force-load every plugin so config errors surface
require("lazy").load({
  plugins = vim.tbl_keys(require("lazy.core.config").plugins),
})

-- Check for plugin config/load errors
local errors = {}
for name, plugin in pairs(require("lazy.core.config").plugins) do
  if plugin._.has_errors then
    table.insert(errors, name)
  end
end

if #errors > 0 then
  print("FAIL plugins: " .. table.concat(errors, ", "))
  vim.cmd("cquit 1")
end

-- Catch plugins that were never installed
local missing_dirs = {}
for name, plugin in pairs(require("lazy.core.config").plugins) do
  if not vim.uv.fs_stat(plugin.dir) then
    table.insert(missing_dirs, name .. ": " .. plugin.dir)
  end
end

if #missing_dirs > 0 then
  print("FAIL plugin dirs:")
  for _, msg in ipairs(missing_dirs) do
    print("  " .. msg)
  end
  vim.cmd("cquit 1")
end

local s = require("lazy").stats()
print(string.format("OK: %d/%d plugins loaded", s.loaded, s.count))

-- Check treesitter parsers (list comes from treesitter_conf)
local ts = require("plugins_config/treesitter_conf")

local query_types = { "highlights", "injections", "locals", "folds", "indents" }

local failed = {}
local broken_queries = {}
for _, lang in ipairs(ts.ensure_installed) do
  if pcall(vim.treesitter.language.add, lang) then
    -- A missing query returns nil, a broken one throws.
    for _, query in ipairs(query_types) do
      local ok, err = pcall(vim.treesitter.query.get, lang, query)
      if not ok then
        table.insert(
          broken_queries,
          string.format("%s/%s: %s", lang, query, err)
        )
      end
    end
  else
    table.insert(failed, lang)
  end
end

if #failed > 0 then
  print("FAIL parsers: " .. table.concat(failed, ", "))
  vim.cmd("cquit 1")
end

if #broken_queries > 0 then
  print("FAIL queries:")
  for _, msg in ipairs(broken_queries) do
    print("  " .. msg)
  end
  vim.cmd("cquit 1")
end

print(
  string.format("OK: %d treesitter parsers and queries", #ts.ensure_installed)
)
vim.cmd("quit")
