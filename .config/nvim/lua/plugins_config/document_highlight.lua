-- Native document highlight: highlights other uses of the
-- symbol under cursor. Replaces RRethy/vim-illuminate.
local M = {}

function M.setup()
  local group =
    vim.api.nvim_create_augroup("native_document_highlight", { clear = true })

  local function set_hl()
    vim.api.nvim_set_hl(0, "LspReferenceText", { link = "Visual" })
    vim.api.nvim_set_hl(0, "LspReferenceRead", { link = "Visual" })
    vim.api.nvim_set_hl(0, "LspReferenceWrite", { link = "Visual" })
  end

  set_hl()

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = set_hl,
  })

  vim.api.nvim_create_autocmd("LspAttach", {
    group = group,
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if
        not client
        or not client.supports_method("textDocument/documentHighlight")
      then
        return
      end

      local buf_group = vim.api.nvim_create_augroup(
        "native_document_highlight_" .. args.buf,
        { clear = true }
      )

      vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
        group = buf_group,
        buffer = args.buf,
        callback = vim.lsp.buf.document_highlight,
      })

      vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
        group = buf_group,
        buffer = args.buf,
        callback = vim.lsp.buf.clear_references,
      })
    end,
  })
end

return M
