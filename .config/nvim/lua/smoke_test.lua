require("lazy").install({ wait = true })

local errors = {}
for name, plugin in pairs(require("lazy.core.config").plugins) do
  if plugin._.has_errors then
    table.insert(errors, name)
  end
end

if #errors > 0 then
  print("FAIL: " .. table.concat(errors, ", "))
  vim.cmd("cquit 1")
end

local s = require("lazy").stats()
print(string.format("OK: %d/%d plugins loaded", s.loaded, s.count))
vim.cmd("quit")
