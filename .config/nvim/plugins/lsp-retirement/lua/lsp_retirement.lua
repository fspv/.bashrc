---@class LspRetirement
local M = {}

local retirement_ms = 15 * 60 * 1000
local check_interval_ms = 60 * 1000

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
  vim.diagnostic.reset(nil, bufnr)
  vim.b[bufnr].lsp_retired = true
end

---@param bufnr integer
local function revive(bufnr)
  if not vim.b[bufnr].lsp_retired then
    return
  end
  vim.b[bufnr].lsp_retired = false
  vim.api.nvim_exec_autocmds("FileType", { buffer = bufnr, modeline = false })
end

local function scan()
  local threshold = vim.uv.now() - retirement_ms
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    local last_used = vim.b[bufnr].lsp_last_used or 0
    if last_used < threshold and is_retirable(bufnr) then
      retire(bufnr)
    end
  end
end

function M.setup()
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

  local timer = vim.uv.new_timer()
  timer:start(check_interval_ms, check_interval_ms, vim.schedule_wrap(scan))
end

return M
