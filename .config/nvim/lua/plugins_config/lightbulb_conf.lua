-- TODO: port to lua
vim.cmd(
  [[
    autocmd CursorHold,CursorHoldI * lua require('nvim-lightbulb').update_lightbulb()
]]
)
