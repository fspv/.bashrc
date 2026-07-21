local M = {}

---@param bufnr number
---@param command string
local function run_command(bufnr, command)
  local client = vim.lsp.get_clients({ bufnr = bufnr, name = "comment_lsp" })[1]
  if client then
    client:exec_cmd({
      title = command,
      command = command,
      arguments = { vim.uri_from_bufnr(bufnr) },
    }, { bufnr = bufnr })
  end
end

---@param bufnr number
---@return boolean
local function is_shown_in_real_window(bufnr)
  for _, window in ipairs(vim.fn.win_findbuf(bufnr)) do
    if vim.api.nvim_win_get_config(window).relative == "" then
      return true
    end
  end
  return false
end

---@param bufnr number
local function generate_if_visible(bufnr)
  -- Deferred: during bufload, autocmds run inside nvim's temporary
  -- autocmd window, which would make background buffers look visible.
  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(bufnr) and is_shown_in_real_window(bufnr) then
      run_command(bufnr, "commentLsp.generate")
    end
  end)
end

local generate_group =
  vim.api.nvim_create_augroup("CommentLspGenerate", { clear = true })

---@param bufnr number
local function on_attach(bufnr)
  vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
  vim.api.nvim_buf_create_user_command(bufnr, "CommentLspRegenerate", function()
    run_command(bufnr, "commentLsp.regenerate")
  end, { desc = "Drop cached comments for this file and ask the agent again" })
  if vim.b[bufnr].comment_lsp_watched then
    return
  end
  vim.b[bufnr].comment_lsp_watched = true
  vim.api.nvim_create_autocmd({ "BufWinEnter", "BufWritePost" }, {
    group = generate_group,
    buffer = bufnr,
    callback = function()
      generate_if_visible(bufnr)
    end,
  })
  generate_if_visible(bufnr)
end

---@param config vim.lsp.Config
function M.setup(config)
  vim.lsp.config("comment_lsp", config)
  vim.lsp.enable("comment_lsp")

  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("CommentLspAttach", { clear = true }),
    callback = function(event)
      local client = vim.lsp.get_client_by_id(event.data.client_id)
      if client and client.name == "comment_lsp" then
        on_attach(event.buf)
      end
    end,
  })
end

return M
