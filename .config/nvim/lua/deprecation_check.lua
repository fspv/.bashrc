-- Hooks vim.deprecate to record every deprecation triggered while loading the
-- config and installed plugins. Exits non-zero if any were recorded so CI
-- surfaces deprecated API usage before upstream removes it.

local recorded = {}

local original_deprecate = vim.deprecate
vim.deprecate = function(name, alternative, version, plugin, backtrace)
  table.insert(recorded, {
    name = name,
    alternative = alternative,
    version = version,
    plugin = plugin,
    traceback = debug.traceback("", 2),
  })
  if original_deprecate then
    return original_deprecate(name, alternative, version, plugin, backtrace)
  end
end

require("lazy").install({ wait = true })

-- Force-load every plugin so deprecations behind lazy-loaded entry points fire.
require("lazy").load({
  plugins = vim.tbl_keys(require("lazy.core.config").plugins),
})

if #recorded == 0 then
  print("OK: no deprecations recorded")
  vim.cmd("quit")
  return
end

print(string.format("FAIL: %d deprecation(s) recorded", #recorded))
for i, dep in ipairs(recorded) do
  local plugin = dep.plugin or "neovim"
  local version = dep.version or "?"
  local alternative = dep.alternative or "(none)"
  print(
    string.format(
      "\n[%d] %s (%s, removed in %s)\n    use: %s%s",
      i,
      dep.name,
      plugin,
      version,
      alternative,
      dep.traceback or ""
    )
  )
end
vim.cmd("cquit 1")
