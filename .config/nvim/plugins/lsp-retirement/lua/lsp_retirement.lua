-- Detach LSP clients from buffers that have gone idle and hidden, so language
-- servers stop tracking files you are no longer editing. The buffers stay open
-- (cursor, undo and marks intact) and their servers re-attach automatically
-- when you return to them.
--
-- Replaces chrisgrieser/nvim-early-retirement, which deleted the buffers
-- outright. Stepping away no longer costs you your open files, it only frees
-- the language servers.

---@class LspRetirement
local M = {}

---@class LspRetirement.Config
---@field retirement_minutes integer Idle minutes before a buffer detaches.
---@field check_interval_seconds integer Seconds between idle-buffer scans.

---@type LspRetirement.Config
local defaults = {
  retirement_minutes = 15,
  check_interval_seconds = 60,
}

local activity_events = {
  "BufEnter",
  "CursorMoved",
  "CursorMovedI",
  "TextChanged",
  "InsertLeave",
}

---@param bufnr integer
---@return boolean
local function is_hidden(bufnr)
  return next(vim.fn.win_findbuf(bufnr)) == nil
end

---@param bufnr integer
---@return boolean
local function has_clients(bufnr)
  return next(vim.lsp.get_clients({ bufnr = bufnr })) ~= nil
end

---@param bufnr integer
---@return boolean
local function is_retirable(bufnr)
  return vim.api.nvim_buf_is_loaded(bufnr)
    and vim.bo[bufnr].buflisted
    and vim.bo[bufnr].buftype == ""
    and is_hidden(bufnr)
    and has_clients(bufnr)
end

---@param bufnr integer
local function retire(bufnr)
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    vim.lsp.buf_detach_client(bufnr, client.id)
  end
  -- Clear diagnostics so a detached server does not leave stale ones behind
  -- (neovim/neovim#33864).
  vim.diagnostic.reset(nil, bufnr)
  vim.b[bufnr].lsp_retired = true
end

---@param bufnr integer
local function revive(bufnr)
  if not vim.b[bufnr].lsp_retired then
    return
  end
  vim.b[bufnr].lsp_retired = false
  -- Re-run FileType autocmds so native vim.lsp.enable re-attaches the server.
  vim.api.nvim_exec_autocmds("FileType", { buffer = bufnr, modeline = false })
end

---@param retirement_ms integer
local function scan(retirement_ms)
  local threshold = vim.uv.now() - retirement_ms
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    local last_used = vim.b[bufnr].lsp_last_used or 0
    if last_used < threshold and is_retirable(bufnr) then
      retire(bufnr)
    end
  end
end

---@param opts LspRetirement.Config|nil
function M.setup(opts)
  local config = vim.tbl_extend("force", defaults, opts or {})
  local group = vim.api.nvim_create_augroup("lsp_retirement", { clear = true })

  vim.api.nvim_create_autocmd(activity_events, {
    group = group,
    callback = function(args)
      vim.b[args.buf].lsp_last_used = vim.uv.now()
    end,
  })

  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    callback = function(args)
      revive(args.buf)
    end,
  })

  local interval_ms = config.check_interval_seconds * 1000
  local retirement_ms = config.retirement_minutes * 60 * 1000
  local timer = vim.uv.new_timer()
  timer:start(
    interval_ms,
    interval_ms,
    vim.schedule_wrap(function()
      scan(retirement_ms)
    end)
  )
end

return M
