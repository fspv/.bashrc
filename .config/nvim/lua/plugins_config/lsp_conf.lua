-- lsp-zero automates lspconfig configuration
-- lsp-zero doc: https://github.com/VonHeikemen/lsp-zero.nvim/blob/ea4c9511c94df9596c450036502b7ff43d40f816/doc/md/lsp.md
local lsp = require('lsp-zero').preset({
  name = 'minimal',
  set_lsp_keymaps = false,
  manage_nvim_cmp = true,
  suggest_lsp_servers = false,
  float_border = 'none',
  configure_diagnostics = false,
})

lsp.extend_lspconfig()

-- lsp.nvim_workspace()

local on_attach_func = function(client, bufnr)
  if client.supports_method("textDocument/publishDiagnostics") then
    -- Disable line by line diagnostics, as it takes a lot of time during
    -- statup to process them
    vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(
      vim.lsp.diagnostic.on_publish_diagnostics, {
        underline = true,
        update_in_insert = false,
        signs = false,
        virtual_text = true,
      }
    )
  end

  -- if client.supports_method("textDocument/documentHighlight") then
  --   -- Highlight all occurences of the symbol under cursor
  --   vim.cmd(
  --     [[
  --       :hi LspReferenceRead cterm=bold ctermbg=red guibg=Yellow guifg=Black
  --       :hi LspReferenceText cterm=bold ctermbg=red guibg=Yellow guifg=Black
  --       :hi LspReferenceWrite cterm=bold ctermbg=red guibg=Yellow guifg=Black
  --     ]]
  --   )

  --   vim.api.nvim_create_augroup("lsp_document_highlight", { clear = true })
  --   vim.api.nvim_clear_autocmds { buffer = bufnr, group = "lsp_document_highlight" }
  --   vim.api.nvim_create_autocmd("CursorHold", {
  --     callback = vim.lsp.buf.document_highlight,
  --     buffer = bufnr,
  --     group = "lsp_document_highlight",
  --     desc = "Document Highlight",
  --   })
  --   vim.api.nvim_create_autocmd("CursorMoved", {
  --     callback = vim.lsp.buf.clear_references,
  --     buffer = bufnr,
  --     group = "lsp_document_highlight",
  --     desc = "Clear All the References",
  --   })
  -- end

  local signs = { Error = " ", Warn = " ", Hint = " ", Info = " " }
  for type, icon in pairs(signs) do
    local hl = "DiagnosticSign" .. type
    vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
  end

  -- require "lsp_signature".on_attach({
  --   bind = true, -- This is mandatory, otherwise border config won't get registered.
  --   handler_opts = {
  --     border = "rounded"
  --   }
  -- }, bufnr)

  lsp.default_keymaps({ buffer = bufnr, preserve_mappings = false })

  -- Format the buffer using gq using ls (use gw to wrap to line length)
  vim.keymap.set(
    { 'n', 'x' },
    'gq',
    function()
      vim.lsp.buf.format({ async = true })
    end,
    { buffer = bufnr, noremap = true, desc = "Format Selection" }
  )

  vim.keymap.set(
    'n',
    'gD',
    vim.lsp.buf.declaration,
    { buffer = bufnr, noremap = true, desc = "Go to Declaration" }
  )
  vim.keymap.set(
    'n',
    '<space>wa',
    vim.lsp.buf.add_workspace_folder,
    { buffer = bufnr, noremap = true, desc = "Add Workspace Folder" }
  )
  vim.keymap.set(
    'n',
    '<space>wr',
    vim.lsp.buf.remove_workspace_folder,
    { buffer = bufnr, noremap = true, desc = "Remove Workspace Folder" }
  )
  vim.keymap.set(
    'n',
    '<space>wl',
    function() print(vim.inspect(vim.lsp.buf.list_workspace_folders())) end,
    { buffer = bufnr, noremap = true, desc = "List Workspace Folders" }
  )
  vim.keymap.set(
    'n',
    '<space>rn',
    vim.lsp.buf.rename,
    { buffer = bufnr, noremap = true, desc = "Rename Symbol Under Cursor" }
  )
  vim.keymap.set(
    { 'n', 'x' },
    '<space>f',
    function()
      vim.lsp.buf.format { async = true }
    end,
    { buffer = bufnr, noremap = true, desc = "Format Document" }
  )

  local function _lsp_workplace_symbols_under_cursor()
    return require("telescope.builtin").lsp_workspace_symbols(
      {
        query = vim.call('expand', '<cword>')
      }
    )
  end

  vim.keymap.set(
    "n",
    "gf",
    _lsp_workplace_symbols_under_cursor,
    { buffer = bufnr, noremap = true, desc = "Find Symbol Under Cursor" }
  )
  vim.keymap.set(
    'n',
    'gr',
    require("telescope.builtin").lsp_references,
    { buffer = bufnr, noremap = true, desc = "Find References" }
  )
  vim.keymap.set(
    'n',
    'gi',
    require("telescope.builtin").lsp_implementations,
    { buffer = bufnr, noremap = true, desc = "Find Implementations" }
  )
  vim.keymap.set(
    'n',
    'gd',
    require("telescope.builtin").lsp_definitions,
    { buffer = bufnr, noremap = true, desc = "Find Definitions" }
  )
  vim.keymap.set(
    'n',
    '<space>D',
    require("telescope.builtin").lsp_type_definitions,
    { buffer = bufnr, noremap = true, desc = "Go to Type Definition" }
  )
  vim.keymap.set(
    {
      "n",
      "v"
    },
    "<space>ca", "<cmd>Lspsaga code_action<CR>",
    { buffer = bufnr, noremap = true, desc = "Code Action" }
  )
  vim.keymap.set(
    "n",
    "gp",
    "<cmd>Lspsaga peek_definition<CR>",
    { buffer = bufnr, noremap = true, desc = "Peek Definition" }
  )
  -- FIXME: overwrites gt (next tab)
  vim.keymap.set(
    "n",
    "gtp",
    "<cmd>Lspsaga peek_type_definition<CR>",
    { buffer = bufnr, noremap = true, desc = "Peek Type Definition" }
  )
  vim.keymap.set(
    "n",
    "K",
    "<cmd>Lspsaga hover_doc<CR>",
    { buffer = bufnr, noremap = true, desc = "Hover Doc (press twice to scroll)" }
  )

  vim.keymap.set(
    "n",
    "<leader>o",
    "<cmd>Lspsaga outline<CR>",
    { buffer = bufnr, noremap = true, desc = "Symbols Outline (Lspsaga)" }
  )
  vim.keymap.set(
    "n",
    "<Leader>ci",
    "<cmd>Lspsaga incoming_calls<CR>",
    { buffer = bufnr, noremap = true, desc = "Incoming Calls" }
  )
  vim.keymap.set(
    "n",
    "<Leader>co",
    "<cmd>Lspsaga outgoing_calls<CR>",
    { buffer = bufnr, noremap = true, desc = "Outgouing Calls" }
  )
  -- require('symbols-outline').open_outline()
end

require('lspconfig').yamlls.setup(
  {
    on_attach = on_attach_func,
    settings = {
      yaml = {
      }
    },
  }
)

require('lspconfig').jsonls.setup(
  {
    on_attach = on_attach_func,
  }
)

require('lspconfig').bashls.setup(
  {
    on_attach = on_attach_func,
  }
)

require("lspconfig").pyright.setup(
  {
    on_attach = on_attach_func,
    settings = {
      python = {
        analysis = {
          extraPaths = {
            "plz-out/gen", -- For please build system
          },
          typeCheckingMode = "off",
          autoSearchPaths = false,
          useLibraryCodeForTypes = false,
          diagnosticMode = "openFilesOnly",
        },
      },
    },
  }
)
-- require 'lspconfig'.jedi_language_server.setup {
-- }
-- require 'lspconfig'.pylsp.setup {
--   settings = {
--     pylsp = {
--       plugins = {
--       }
--     }
--   }
-- }
-- require 'lspconfig'.pyre.setup {
--   cmd = { "pyre", "persistent" },
-- }

-- if not vim.b.large_buf then
--   require 'lspconfig'.pylyzer.setup {
--     cmd = { "pylyzer", "--server", "--verbose", "2" },
--     root_dir = require("lspconfig/util").root_pattern(".git"),
--     settings = {
--       python = {
--         diagnostics = false,
--         inlayHints = true,
--         smartCompletion = true
--       }
--     }
--   }
-- end

require 'lspconfig'.lua_ls.setup {
  on_attach = on_attach_func,
  settings = {
    Lua = {
      runtime = {
        -- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
        version = 'LuaJIT',
      },
      diagnostics = {
        -- Get the language server to recognize the `vim` global
        globals = { 'vim' },
      },
      workspace = {
        -- Make the server aware of Neovim runtime files
        library = vim.api.nvim_get_runtime_file("", true),
      },
      -- Do not send telemetry data containing a randomized but unique identifier
      telemetry = {
        enable = false,
      },
    },
  },
}

-- Settings values: https://github.com/golang/tools/blob/master/gopls/doc/settings.md
require 'lspconfig'.gopls.setup {
  on_attach = on_attach_func,
  -- For debug run `gopls -listen="unix;/tmp/gopls-daemon-socket" -logfile=auto -rpc.trace` and uncomment below
  -- cmd = { "gopls", "-debug=:0", "-remote=unix;/tmp/gopls-daemon-socket", "-logfile=auto", "-rpc.trace", },
  cmd = { "gopls" },
  --- To check if the dir is selected correctly, find a pid and run `ls -lah /proc/<pid>/fd`
  ---@param startpath string
  root_dir = function(startpath)
    if string.find(startpath, 'plz%-out') then
      -- Separate branch, because otherwise it defaults to the repo root and becomes too slow
      return require("lspconfig/util").root_pattern(
        "go.mod",
        "go.work"
      )(startpath)
    else
      return require("lspconfig/util").root_pattern(
      -- Order here matters
        "BUILD",
        "go.work",
        "go.mod",
        ".git"
      )(startpath)
    end
  end,
  settings = {
    gopls = {
      staticcheck = true,
      gofumpt = true,
      diagnosticsDelay = "2s",
      diagnosticsTrigger = "Edit", -- Save or Edit
      directoryFilters = { "-plz-out" },
      hints = {
        assignVariableTypes = true,
        compositeLiteralFields = true,
        compositeLiteralTypes = true,
        constantValues = true,
        functionTypeParameters = true,
        parameterNames = true,
        rangeVariableTypes = true,
      },
      analyses = {
        unusedparams = true,
        unusedwrite = true,
        unusedvariable = true,
        shadow = true,
        nilness = true,
        useany = true,
      }
    },
  },
  capabilities = require('cmp_nvim_lsp').default_capabilities(),
}

require("lspconfig").rust_analyzer.setup(
  {
    on_attach = on_attach_func,
    settings = {
      ["rust-analyzer"] = {
      }
    }
  }
)

require("lspconfig").clangd.setup({
  filetypes = { 'c', 'cpp', 'objc', 'objcpp', 'cuda' },
  on_attach = on_attach_func,
})

-- JavaScript/TypeScript
require("lspconfig").tsserver.setup({

  on_attach = on_attach_func,
})

-- `npm init @eslint/config` to make this work
require("lspconfig").eslint.setup({
  on_attach = on_attach_func,
})
require("lspconfig").biome.setup({

  on_attach = on_attach_func,
})
-- `npm install --save-dev flow-bin && npm run flow init`
-- require("lspconfig").flow.setup({})
require("lspconfig").quick_lint_js.setup({
  on_attach = on_attach_func,
})

-- Proto files
require("lspconfig").bufls.setup({
  on_attach = on_attach_func,
})

-- Spellcheck in tex, md and comments
-- require("lspconfig").ltex.setup({
--   filetypes = {
--     'md',
--     'go',
--     'python',
--     'rust',
--     'sh',
--     'lua',
--     'javascript',
--     'typescript'
--   },
--   on_attach = on_attach_func,
-- })

-- lsp.ensure_installed({
--   'rust_analyzer'
-- })

-- TODO: pylsp installation doesn't work from within existing virtualenv
lsp.format_on_save({
  servers = {
    ['lua_ls'] = { 'lua' },
    ['rust_analyzer'] = { 'rust' },
  }
})

-- lsp.skip_server_setup({ 'pyre', 'pylsp' })
lsp.setup()
