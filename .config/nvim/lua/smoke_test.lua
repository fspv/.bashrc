require("lazy").install({ wait = true })

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

-- Check for build task failures
local build_failures = {}
for name, plugin in pairs(require("lazy.core.config").plugins) do
  for _, task in ipairs(plugin._.tasks or {}) do
    if task.name == "build" and task.error then
      table.insert(build_failures, name .. ": " .. task.error)
    end
  end
end

if #build_failures > 0 then
  print("FAIL builds:")
  for _, msg in ipairs(build_failures) do
    print("  " .. msg)
  end
  vim.cmd("cquit 1")
end

local s = require("lazy").stats()
print(string.format("OK: %d/%d plugins loaded", s.loaded, s.count))

-- Check treesitter parsers (list comes from treesitter_conf)
local ts = require("plugins_config.treesitter_conf")

-- Wait for async parser installs (up to 120s)
vim.wait(120000, function()
  for _, lang in ipairs(ts.ensure_installed) do
    if not pcall(vim.treesitter.language.add, lang) then
      return false
    end
  end
  return true
end, 2000)

-- Verify all parsers compiled
local failed = {}
for _, lang in ipairs(ts.ensure_installed) do
  if not pcall(vim.treesitter.language.add, lang) then
    table.insert(failed, lang)
  end
end

if #failed > 0 then
  print("FAIL parsers: " .. table.concat(failed, ", "))
  vim.cmd("cquit 1")
end

print(string.format("OK: %d treesitter parsers", #ts.ensure_installed))
vim.cmd("quit")
